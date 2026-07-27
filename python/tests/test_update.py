"""The maintenance surface: `datalib_update` (contract-adjacent, not contract).

`datalib_update` is deliberately **not** one of the 13 canonical commands. Which
version you are running, and where a newer one would come from, is a question
about deployment rather than about the folder grammar -- and folding it into
`surface.yml` `commands:` would make the canonical count 14 and quietly destroy
the meaning of the Stata-side guard
`test_subcommands_are_exactly_the_canonical_commands`.
"""

from __future__ import annotations

import ast
import inspect
from pathlib import Path

import pytest
import yaml

import datalib
from datalib.update import UpdateStatus, version_status

from conftest import find_repo_tests_dir

REPO = find_repo_tests_dir().parent
SURFACE = yaml.safe_load((REPO / "config" / "surface.yml").read_text(encoding="utf-8"))
DECL = SURFACE["maintenance"]["python"]


def test_declared_and_exported() -> None:
    name = DECL["name"]
    assert hasattr(datalib, name), f"{name} is declared but not exported"
    assert name in datalib.__all__


def test_signature_matches_the_declaration() -> None:
    fn = getattr(datalib, DECL["name"])
    actual = list(inspect.signature(fn).parameters)
    assert actual == list(DECL["args"])


def test_update_is_not_a_canonical_command() -> None:
    """It must stay out of `commands:`, or the canonical count silently becomes 14."""
    assert DECL["name"] not in SURFACE["commands"]
    assert len(SURFACE["commands"]) == 13


# --------------------------------------------------------------- the comparison

@pytest.mark.parametrize(
    "running,source,expected",
    [
        # The trap: as TEXT "0.9.10" sorts BELOW "0.9.9", so a string comparison
        # reports a newer release as older. This is why the comparison exists.
        ("0.9.9", "0.9.10", "newer_available"),
        ("0.9.10", "0.9.9", "source_behind"),
        ("0.9.3", "0.9.10", "newer_available"),
        ("0.9.10", "0.9.10", "current"),
        ("1.0.0", "0.9.10", "source_behind"),
        ("0.9.10", "1.0.0", "newer_available"),
        (None, "0.9.10", "unknown"),
        ("0.9.10", None, "unknown"),
        ("0.9.10", "", "unknown"),
        ("", "0.9.10", "unknown"),
        ("not.a.version", "0.9.10", "unknown"),
    ],
)
def test_version_status(running, source, expected) -> None:
    assert version_status(running, source) == expected


def test_text_comparison_would_get_it_wrong() -> None:
    """Pin the premise, so nobody 'simplifies' this to a string compare."""
    assert "0.9.10" < "0.9.9"                                  # as text: wrong
    assert version_status("0.9.9", "0.9.10") == "newer_available"  # as versions: right


# ------------------------------------------------------------------- behaviour

def test_missing_manifest_is_unknown_not_an_error(tmp_path) -> None:
    r = datalib.datalib_update(netsource=tmp_path, quiet=True)
    assert isinstance(r, UpdateStatus)
    assert r.status == "unknown"
    assert r.source_version is None


def test_reads_the_shared_version_manifest(tmp_path) -> None:
    """All three languages read the same file, so one publish serves them all."""
    (tmp_path / "VERSION").write_text("99.0.0\n", encoding="utf-8")
    r = datalib.datalib_update(netsource=tmp_path, quiet=True)
    assert r.source_version == "99.0.0"
    assert r.status == "newer_available"
    assert r.running == datalib.__version__


def test_older_manifest_reports_source_behind(tmp_path) -> None:
    (tmp_path / "VERSION").write_text("0.0.1\n", encoding="utf-8")
    r = datalib.datalib_update(netsource=tmp_path, quiet=True)
    assert r.status == "source_behind"


def test_netsource_argument_wins_over_the_environment(tmp_path, monkeypatch) -> None:
    other = tmp_path / "other"
    other.mkdir()
    (other / "VERSION").write_text("42.0.0\n", encoding="utf-8")
    monkeypatch.setenv("DATALIB_NETSOURCE", str(tmp_path))
    r = datalib.datalib_update(netsource=other, quiet=True)
    assert r.source_version == "42.0.0"


def test_environment_is_used_when_no_argument(tmp_path, monkeypatch) -> None:
    (tmp_path / "VERSION").write_text("7.7.7\n", encoding="utf-8")
    monkeypatch.setenv("DATALIB_NETSOURCE", str(tmp_path))
    r = datalib.datalib_update(quiet=True)
    assert r.source_version == "7.7.7"


def test_quiet_prints_nothing(tmp_path, capsys) -> None:
    datalib.datalib_update(netsource=tmp_path, quiet=True)
    assert capsys.readouterr().out == ""


def test_report_names_the_three_coordinates(tmp_path, capsys) -> None:
    (tmp_path / "VERSION").write_text("99.0.0\n", encoding="utf-8")
    datalib.datalib_update(netsource=tmp_path)
    out = capsys.readouterr().out
    assert "running" in out and "net site" in out and "site version" in out
    assert "99.0.0" in out
    # and it must tell the user what to run, since it will not run it
    assert "pip install" in out


def test_does_not_install(tmp_path) -> None:
    """Declared installs: false, and asserted against the AST rather than the text.

    The function prints the string ``pip install ...`` as the command for the user
    to run, so a text search finds a match that is not a call. Walking the AST
    distinguishes a call from a string literal.
    """
    assert DECL["installs"] is False
    src = (REPO / "python" / "src" / "datalib" / "update.py").read_text(encoding="utf-8")
    tree = ast.parse(src)
    called = {
        node.func.attr if isinstance(node.func, ast.Attribute) else getattr(node.func, "id", "")
        for node in ast.walk(tree)
        if isinstance(node, ast.Call)
    }
    for forbidden in ("run", "check_call", "check_output", "Popen", "system", "rmtree"):
        assert forbidden not in called, f"datalib_update must not call {forbidden}"
    assert "subprocess" not in src.split("__all__")[0], "must not import subprocess"
