"""Every package internal must be callable from where it is called.

Stata resolves a command name to a **file** of that name on the adopath. So a program
defined as a *secondary* program inside someone else's ``.ado`` is only callable once that
file has been loaded for its own reasons -- and a caller in a different file cannot rely
on that having happened.

``datalib_explorer`` shipped in 0.9.21 calling ``_uc_dirs``, which is defined inside
``_uc_init.ado`` rather than as ``_uc_dirs.ado``. On the author's machine everything
passed. On a clean install the first call died:

    . datalib, library(Z:\\<staging-tree>) explorer
    command _uc_dirs is unrecognized
    r(199);

**Why no existing test caught it, and why this one is in Python.**
``run_conformance.do`` loads every source file up front (``run "stata/src/_/*.ado"``),
which is the one condition a real user does not have: it *manufactures* the loaded state
whose absence is the bug. A dynamic Stata test therefore cannot see this class at all
without deliberately un-loading the package, and any test that did would be fighting the
harness it lives in. The check is static -- does a name resolve to a file? -- so it
belongs in the leg that can run without a Stata licence, next to
:mod:`test_surface` and :mod:`test_stamps`.

**The rule.** For every ``_``-prefixed program the package defines, each call site must be
either
  * in the same file that defines it (a private subroutine, always fine), or
  * a name with its own packaged ``<name>.ado`` (autoloadable, always fine).

Only names the package itself defines are considered, which is what keeps this free of
false positives: Stata built-ins (``_rc``, ``_n``, ``_N``, ``_all``, ``_dta``) are never in
the defined set, so they are never examined.
"""

from __future__ import annotations

import re
from collections import defaultdict
from pathlib import Path

import pytest

from conftest import find_repo_tests_dir

REPO = find_repo_tests_dir().parent

# A command invocation at the head of a statement, allowing the usual prefixes. Stata
# lets several stack up ("capture quietly noisily foo"), hence the repetition.
_PREFIX = r"(?:capture\s+|cap\s+|quietly\s+|qui\s+|noisily\s+|noi\s+)*"
_CALL = re.compile(r"^\s*" + _PREFIX + r"(_[a-z][a-z0-9_]*)\b", re.IGNORECASE)
_DEFINE = re.compile(r"^\s*program\s+(?:define\s+)?(_[a-z][a-z0-9_]*)\b", re.IGNORECASE)


def _packaged_files() -> list[Path]:
    """The .ado files datalib.pkg actually installs."""
    pkg = REPO / "stata" / "datalib.pkg"
    if not pkg.is_file():
        pytest.skip("stata/datalib.pkg not found (running outside the repo)")
    out = []
    for line in pkg.read_text(encoding="utf-8").splitlines():
        if not line.lower().startswith("f "):
            continue
        rel = line[2:].strip()
        if not rel.endswith(".ado"):
            continue
        path = REPO / "stata" / rel
        if path.is_file():
            out.append(path)
    return out


def _strip_comments(text: str) -> list[str]:
    """Drop ``*`` comment lines and ``//`` tails so a mention is not read as a call."""
    lines = []
    for raw in text.splitlines():
        if raw.lstrip().startswith("*"):
            lines.append("")
            continue
        lines.append(raw.split("//")[0])
    return lines


def _is_unresolvable(
    name: str,
    caller: str,
    defined_in: dict[str, set[str]],
    autoloadable: set[str],
) -> bool:
    """Would Stata fail to resolve this call on a clean install?

    The whole rule, in one place, so the self-test below runs it instead of restating
    it. Three ways a call is fine: the package never defines the name (a built-in, so
    not ours to check), the name has its own packaged .ado (autoloadable), or the call
    is in the file that defines it (a private subroutine).
    """
    if name not in defined_in:
        return False
    if name in autoloadable:
        return False
    return caller not in defined_in[name]


def test_every_internal_called_is_callable_where_it_is_called() -> None:
    """The guard that 0.9.21's r(199) would have tripped."""
    files = _packaged_files()
    if not files:
        pytest.skip("no packaged .ado files found")

    # Where each internal is DEFINED, and which internals are autoloadable by name.
    defined_in: dict[str, set[str]] = defaultdict(set)
    for path in files:
        for line in _strip_comments(path.read_text(encoding="utf-8", errors="replace")):
            m = _DEFINE.match(line)
            if m:
                defined_in[m.group(1).lower()].add(path.name)
    autoloadable = {p.stem.lower() for p in files if p.stem.startswith("_")}

    problems: list[str] = []
    for path in files:
        for n, line in enumerate(
            _strip_comments(path.read_text(encoding="utf-8", errors="replace")), 1
        ):
            m = _CALL.match(line)
            if not m:
                continue
            name = m.group(1).lower()
            if not _is_unresolvable(name, path.name, defined_in, autoloadable):
                continue
            home = ", ".join(sorted(defined_in[name]))
            problems.append(
                f"{path.name}:{n} calls {name}, which is defined only inside {home} "
                f"and has no {name}.ado of its own -- Stata cannot autoload it, so this "
                f"raises r(199) on a clean install"
            )

    assert not problems, (
        "a packaged command calls an internal that Stata cannot resolve to a file:\n  "
        + "\n  ".join(problems)
        + "\n\nEither give the internal its own packaged .ado, or do the work inline. "
        "Tests that -run- every source file up front cannot catch this."
    )


def test_the_guard_would_have_caught_the_0_9_21_regression() -> None:
    """A guard nobody has seen fail is a guard nobody should trust.

    Feeds ``_is_unresolvable`` the exact shape of the shipped bug, plus the three
    shapes that must stay allowed.
    """
    defined_in = {"_uc_dirs": {"_uc_init.ado"}, "_dl_islib": {"_dl_islib.ado"}}
    autoloadable = {"_dl_islib"}  # has its own .ado; _uc_dirs does not

    # The bug: caller in one file, definition in another, no .ado of its own.
    assert _is_unresolvable("_uc_dirs", "datalib_explorer.ado", defined_in, autoloadable)

    # A private subroutine called inside the file that defines it.
    assert not _is_unresolvable("_uc_dirs", "_uc_init.ado", defined_in, autoloadable)

    # An internal with its own packaged .ado, called from anywhere.
    assert not _is_unresolvable("_dl_islib", "datalib_root.ado", defined_in, autoloadable)

    # A name the package does not define at all -- a Stata built-in.
    assert not _is_unresolvable("_rc", "datalib.ado", defined_in, autoloadable)
