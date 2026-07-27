"""A file's ``*!`` stamp may not be older than the release that last changed it.

This repo bumps only the files whose contents changed, which keeps release diffs
honest -- but nothing enforced it, and it drifted. ``datalib.sthlp`` sat at
``0.9.11`` through five releases in which its content changed, and the drift was
found by accident while editing it for something unrelated. Meanwhile
``datalib.ado`` legitimately still stamps ``0.9.10`` in a 0.9.18 package, because
it genuinely has not changed since. From the outside those two look identical:
a stamp lower than the package version, with no way to tell the stale one from the
truthful one short of reading the git history by hand. That happened four times in
one session.

So the invariant is not "every stamp equals VERSION" -- that would delete the
convention -- but:

    a file's stamp must be >= the VERSION in effect at the commit that last
    changed that file.

``>=`` rather than ``==`` because a commit may touch a file without bumping
VERSION (a fixup landing between releases); stamping ahead is harmless, stamping
behind is the defect. Under this rule ``datalib.ado`` at 0.9.10 passes and
``datalib.sthlp`` at 0.9.11 would have failed on the commit that introduced it.

**Why Python and not run_conformance.do.** The check needs git history, which the
Stata harness has no way to read. It also has to cover ``.sthlp`` files, which are
documentation rather than behaviour, so no Stata test would naturally reach them.
See :mod:`test_surface` for the same reasoning applied to the option surface.
"""

from __future__ import annotations

import re
import subprocess
from pathlib import Path

import pytest

# datalib.ado is the exception, and deliberately so: -which datalib- is how
# everyone actually checks what they have, and it reports THIS file's stamp. A
# front door that reports a version eight releases behind the package sends people
# to the wrong conclusion, so this one file tracks VERSION exactly. The stamp bump
# is itself a content change, so it does not violate the only-bump-what-changed
# convention -- it just means this file changes every release.
FRONT_DOOR = "stata/src/d/datalib.ado"

_STAMP = re.compile(r"^\s*\*!\s*(?:Version:\s*)?v?\s*([0-9]+(?:\.[0-9]+)*)", re.MULTILINE)
_HELP_STAMP = re.compile(r"\{right:Version\s+([0-9]+(?:\.[0-9]+)*)\}")


def _git(repo_root: Path, *args: str) -> str | None:
    """Run git, returning None when it cannot answer rather than failing."""
    try:
        out = subprocess.run(
            ["git", *args],
            cwd=repo_root,
            capture_output=True,
            text=True,
            timeout=60,
        )
    except (OSError, subprocess.TimeoutExpired):
        return None
    return out.stdout.strip() if out.returncode == 0 else None


def _as_tuple(version: str) -> tuple[int, ...]:
    return tuple(int(p) for p in version.split(".") if p.isdigit())


def _stamp_of(path: Path) -> str | None:
    """The version a source or help file claims for itself."""
    text = path.read_text(encoding="utf-8", errors="replace")
    if path.suffix == ".sthlp":
        m = _HELP_STAMP.search(text)
        if m:
            return m.group(1)
    m = _STAMP.search(text)
    return m.group(1) if m else None


def _stamped_files(repo_root: Path) -> list[tuple[str, Path, str]]:
    """Every packaged Stata file that carries a stamp, as (relpath, path, stamp)."""
    pkg = repo_root / "stata" / "datalib.pkg"
    if not pkg.is_file():
        pytest.skip("stata/datalib.pkg not found (running outside the repo)")
    out = []
    for line in pkg.read_text(encoding="utf-8").splitlines():
        if not line.startswith("f "):
            continue
        rel = "stata/" + line[2:].strip()
        path = repo_root / rel
        if not path.is_file():
            continue
        stamp = _stamp_of(path)
        if stamp is not None:
            out.append((rel.replace("\\", "/"), path, stamp))
    return out


@pytest.fixture(scope="module")
def git_available(repo_root) -> bool:
    return _git(repo_root, "rev-parse", "--git-dir") is not None


def test_the_front_door_stamp_tracks_the_package_version(repo_root) -> None:
    """-which datalib- must not report a version the package has outgrown."""
    version = (repo_root / "VERSION").read_text(encoding="utf-8").strip()
    path = repo_root / FRONT_DOOR
    if not path.is_file():
        pytest.skip(f"{FRONT_DOOR} not found")
    stamp = _stamp_of(path)
    assert stamp == version, (
        f"{FRONT_DOOR} stamps {stamp} but the package is {version}. This file is "
        f"the front door: -which datalib- reports its stamp, so it tracks VERSION "
        f"exactly. Bump the *! line."
    )


def test_no_stamp_is_older_than_the_release_that_changed_it(
    repo_root, git_available
) -> None:
    """The guard that datalib.sthlp's five-release drift would have tripped."""
    if not git_available:
        pytest.skip("not a git checkout, or git unavailable")

    stale: list[str] = []
    unknown: list[str] = []
    for rel, path, stamp in _stamped_files(repo_root):
        commit = _git(repo_root, "log", "-1", "--format=%H", "--", rel)
        if not commit:
            unknown.append(f"{rel}: no commit touches it")
            continue
        version_then = _git(repo_root, "show", f"{commit}:VERSION")
        if not version_then:
            # Predates the VERSION file (added in 0.9.4); nothing to compare to.
            continue
        if _as_tuple(stamp) < _as_tuple(version_then.strip()):
            stale.append(
                f"{rel}: stamps {stamp} but was last changed in "
                f"{version_then.strip()} ({commit[:8]})"
            )

    assert not stale, (
        "these files changed in a release later than the version they claim, so "
        "their stamp misreports what the file is:\n  " + "\n  ".join(stale)
    )
    # Reported, not asserted: a file with no history is a packaging question, not
    # a stamp question, and test_surface already pins the manifest.
    if unknown:
        print("\nnote, not a failure: " + "; ".join(unknown))
