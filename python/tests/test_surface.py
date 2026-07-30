"""The public surface is declared, and the declaration is enforced.

``config/surface.yml`` declares what exists: every parameter of every public
command, in all three languages, plus the `datalib` subcommand list and the
``source_stage`` vocabulary. This module enforces it.

**What is actually being enforced, and what is not.** The rule people want is
"a parameter may not be added until it is documented". That ordering cannot be
tested -- a test sees a snapshot of the tree, not its history. What is tested is
the equivalent invariant: *at every commit, the implemented surface equals the
declared surface*. Declaring first would become the only way to land
code *if* CI gated the branch -- it does not: Actions is billing-blocked and
neither branch is protected, so this is a local gate that a reviewer has to run.

**Why Stata is enforced from Python.** The Stata leg has no CI licence, but
`.ado` and `.sthlp` are plain text (see :mod:`_stata_parse`), so Stata's surface
can be checked on every push -- it was previously the only completely unguarded
surface in the repo. ``run_conformance.do`` Part 9 adds a *live* check that the
declared options are genuinely accepted by ``syntax``, which matters because
``surface.yml`` was first generated from this parser and would otherwise bake in
any parser bug.

**Comparison semantics differ by language, on purpose.** Stata option order does
not constrain callers, so Stata is compared as a **set**. R and Python match
positionally and their existing doc tests pin documentation to the signature *in
order*, so those are compared as **ordered lists**.
"""

from __future__ import annotations

import inspect
import re
from pathlib import Path

import pytest
import yaml

import datalib as dl

from _stata_parse import (
    ado_options,
    dispatcher_subcommands,
    sthlp_tokens,
    syntax_by_program,
)
from conftest import find_repo_tests_dir

REPO = find_repo_tests_dir().parent
SURFACE = yaml.safe_load((REPO / "config" / "surface.yml").read_text(encoding="utf-8"))
COMMANDS: dict = SURFACE["commands"]
STATA_ONLY: dict = SURFACE["stata_only"]

ALL_STATA = {**{k: v["stata"] for k, v in COMMANDS.items()}, **STATA_ONLY}


def _ado_path(command: str) -> Path:
    """Locate <command>.ado under stata/src/*/ ."""
    hits = list((REPO / "stata" / "src").glob(f"*/{command}.ado"))
    assert len(hits) == 1, f"expected exactly one {command}.ado, found {hits}"
    return hits[0]


# ------------------------------------------------------- Stata: code == declared


@pytest.mark.parametrize("command", sorted(ALL_STATA))
def test_stata_options_match_the_declaration(command: str) -> None:
    """Every option in the .ado's syntax is declared, and vice versa.

    Set comparison: a Stata `syntax` declaration does not order its options.
    """
    parsed = ado_options(_ado_path(command))
    assert parsed is not None, f"{command}.ado has no syntax line to check"
    declared = set(ALL_STATA[command])
    undeclared = sorted(set(parsed) - declared)
    phantom = sorted(declared - set(parsed))
    assert not undeclared, (
        f"{command}: option(s) {undeclared} exist in the .ado but are NOT declared "
        f"in config/surface.yml. Declare them there first -- that is the point of "
        f"the file."
    )
    assert not phantom, (
        f"{command}: option(s) {phantom} are declared in config/surface.yml but do "
        f"not exist in the .ado. Remove the declaration or implement them."
    )


def test_dispatcher_subcommands_match_the_declaration() -> None:
    subcmds = dispatcher_subcommands(_ado_path("datalib"))
    assert subcmds == SURFACE["stata_subcommands"], (
        "datalib.ado `local subcmds` and config/surface.yml stata_subcommands "
        "disagree"
    )


def test_subcommands_are_exactly_the_canonical_commands() -> None:
    """`datalib <sub>` must dispatch to the 13 canonical commands and nothing else."""
    assert sorted(SURFACE["stata_subcommands"]) == sorted(
        c[len("datalib_"):] for c in COMMANDS
    )


@pytest.mark.parametrize("command", sorted(ALL_STATA))
def test_declared_stata_options_are_mentioned_in_the_help(command: str) -> None:
    """Each declared option must appear in the command's help text.

    A *mention* check, deliberately weaker than the equality checks above. The
    help files use several conventions (a formal ``{synopthdr:Options}`` table in
    some, only the Syntax line in others) and their prose legitimately names
    other commands' options, so demanding set equality against the markup
    produced false positives. The strict guarantee lives on ``surface.yml``,
    where it is reliable; this catches the case that actually harms a user -- an
    option that exists and is documented nowhere.

    The 13 canonical wrappers have no help page of their own: they are documented
    collectively in ``datalib_api.sthlp``, whose per-command entries are prose, so
    for those the check is a plain text search.
    """
    pages = []
    own_help = _ado_path(command).with_suffix(".sthlp")
    if own_help.is_file():
        pages.append(own_help)
    else:
        pages.append(REPO / "stata" / "src" / "d" / "datalib_api.sthlp")
    # An alias keeps its own help page, and that is where its options are
    # explained: datalib_config's configdir/edit/replace live in
    # getuserconfig.sthlp, and datalib_map_drive's letter/persistent/discover/
    # dryrun in mapzdrive.sthlp. surface.yml declares the alias so this is a
    # stated relationship rather than the test quietly widening its search until
    # it passes.
    alias = SURFACE.get("aliases", {}).get(command)
    if alias:
        pages.extend((REPO / "stata" / "src").glob(f"*/{alias}.sthlp"))

    haystack: set[str] = set()
    for page in pages:
        haystack |= set(
            re.findall(r"[A-Za-z_][A-Za-z0-9_]*", page.read_text(encoding="utf-8").lower())
        )
    missing = sorted(o for o in ALL_STATA[command] if o.lower() not in haystack)
    assert not missing, (
        f"{command}: declared option(s) {missing} are not mentioned anywhere in "
        f"the help text. Document them before shipping them."
    )


def test_every_public_ado_is_declared() -> None:
    """A new public command cannot appear without a surface.yml entry.

    Public = a `datalib*` / `getuserconfig` / `mapzdrive` command. The internal
    `_*` helpers are deliberately out of scope: the contract documents the public
    surface, and forcing private plumbing into it would make this guard noisy,
    and a noisy guard gets disabled.
    """
    found = {
        p.stem
        for p in (REPO / "stata" / "src").glob("*/*.ado")
        if not p.stem.startswith("_")
    }
    assert found == set(ALL_STATA), (
        f"public .ado files and config/surface.yml disagree: "
        f"undeclared={sorted(found - set(ALL_STATA))} "
        f"declared-but-absent={sorted(set(ALL_STATA) - found)}"
    )


# ------------------------------------------------------ Python: code == declared


@pytest.mark.parametrize("command", sorted(COMMANDS))
def test_python_signature_matches_the_declaration(command: str) -> None:
    """Ordered: Python matches positionally and test_docs pins order."""
    actual = [p for p in inspect.signature(getattr(dl, command)).parameters]
    assert actual == COMMANDS[command]["python"], (
        f"{command}: signature {actual} != declared {COMMANDS[command]['python']}"
    )


def test_declared_non_contract_functions_match_their_declaration() -> None:
    """Blocks outside ``commands:`` are declarations too, not prose.

    ``maintenance``, ``explorer`` and ``index`` are deliberately not in ``commands:``:
    that block is asserted to be exactly the 13 canonical contract commands, and both
    :func:`test_subcommands_are_exactly_the_canonical_commands` and the R export test
    take their meaning from its membership. Adding entries there would push the
    canonical count to 15 and quietly destroy both guards.

    Collected generically, so a function added to ``surface.yml`` later is enforced
    without editing this test.
    """
    checked = 0
    for name, block in SURFACE.items():
        if not isinstance(block, dict):
            continue
        decl = block.get("python")
        if not isinstance(decl, dict) or "name" not in decl or "args" not in decl:
            continue
        fn = getattr(dl, decl["name"], None)
        assert fn is not None, f"{name}: {decl['name']} is declared but not exported"
        actual = list(inspect.signature(fn).parameters)
        assert actual == list(decl["args"]), (
            f"{name}: {decl['name']} signature {actual} != declared {decl['args']}"
        )
        checked += 1
    # A loop that silently checked nothing would pass forever.
    assert checked >= 2, f"expected at least explorer and index, checked {checked}"


def test_python_exports_the_declared_commands() -> None:
    for command in COMMANDS:
        assert hasattr(dl, command), f"{command} is declared but not exported"


# ------------------------------------------------- grammar.md == the declaration


def test_grammar_public_surface_lists_the_declared_commands() -> None:
    """The contract's prose surface list must name exactly the declared commands."""
    text = (REPO / "config" / "grammar.md").read_text(encoding="utf-8")
    m = re.search(r"## Shared public surface(.*?)(?=\n## )", text, re.S)
    assert m, "config/grammar.md has no 'Shared public surface' section"
    named = set(re.findall(r"`(datalib_[a-z_]+)`", m.group(1)))
    assert named == set(COMMANDS), (
        f"grammar.md 'Shared public surface' and config/surface.yml disagree: "
        f"only-in-grammar={sorted(named - set(COMMANDS))} "
        f"only-in-surface={sorted(set(COMMANDS) - named)}"
    )


def test_source_stage_vocabulary_is_the_union_of_the_languages() -> None:
    """No language may report a stage that is not in the declared vocabulary."""
    stage = SURFACE["source_stage"]
    union: set[str] = set()
    for lang in ("stata", "r", "python"):
        union |= set(stage[lang])
    assert union == set(stage["vocabulary"]), (
        f"source_stage vocabulary != union of the per-language lists: "
        f"unused={sorted(set(stage['vocabulary']) - union)} "
        f"undeclared={sorted(union - set(stage['vocabulary']))}"
    )


def test_grammar_documents_every_source_stage() -> None:
    """Every declared stage must appear in grammar.md's section 7 stage table."""
    text = (REPO / "config" / "grammar.md").read_text(encoding="utf-8")
    for st in SURFACE["source_stage"]["vocabulary"]:
        assert f"`{st}`" in text, (
            f"source_stage '{st}' is declared in config/surface.yml but never "
            f"documented in config/grammar.md"
        )


# ------------------------------------------------------- packaging and versions


def test_every_src_file_is_in_the_pkg_manifest() -> None:
    """net install ships only what datalib.pkg lists as an `f` entry."""
    pkg = (REPO / "stata" / "datalib.pkg").read_text(encoding="utf-8")
    listed = {
        Path(m.group(1).strip()).name
        for m in re.finditer(r"^[fF]\s+(.+)$", pkg, re.M)
    }
    on_disk = {
        p.name
        for p in (REPO / "stata" / "src").glob("*/*")
        if p.suffix in {".ado", ".sthlp"}
    }
    missing = sorted(on_disk - listed)
    assert not missing, (
        f"file(s) under stata/src are not listed in datalib.pkg and would not be "
        f"installed: {missing}"
    )


def test_package_manifest_version_matches_the_repo_version() -> None:
    """The installed package version must equal VERSION.

    Deliberately NOT asserted: that every ``*! Version:`` stamp inside an .ado
    equals VERSION. This repo bumps only the files whose contents changed, so
    most stamps legitimately lag (nine wrappers still read 0.9.3), and
    ``_svycheck``/``_vcheck`` carry pre-datalib lineages of their own (1.7.1,
    1.2.0). There is no repo-wide invariant relating a per-file stamp to VERSION,
    and a test asserting one would be inventing a convention the project
    deliberately rejects -- it would force churn on every release, which is
    exactly what "only what changed" avoids. What *must* agree is the package
    version a user installs, which is these two files.
    """
    want = (REPO / "VERSION").read_text(encoding="utf-8").strip()
    for rel in ("stata/datalib.pkg", "stata/stata.toc"):
        text = (REPO / rel).read_text(encoding="utf-8")
        m = re.search(r"^d Version\s+([0-9]+\.[0-9]+\.[0-9]+)", text, re.M)
        assert m, f"{rel} has no 'd Version' line"
        assert m.group(1) == want, f"{rel} says {m.group(1)}, VERSION says {want}"
