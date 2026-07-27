"""The error taxonomy has an enforcer (contract v1, grammar.md section 6).

Two things are asserted here, and neither had ever been asserted before:

1. **Doc truth.** ``config/grammar.md`` section 6 and
   ``tests/error_taxonomy.csv`` must agree row for row. Nothing in any suite had
   ever *read* ``grammar.md`` -- every reference to it was a prose citation --
   which is how its taxonomy table came to document an accidental Stata rc 601
   leak as though it were the design, and to claim a ``source_stage`` vocabulary
   that was "byte-identical across languages" immediately before listing three
   per-language exceptions.

2. **Code truth, for Python's column.** Each row's exception name must exist in
   :mod:`datalib.errors` and must actually be raised by a real trigger. Asserting
   the name exists is not enough: a name can survive a rename while nothing
   raises it any more.

The R and Stata columns are asserted by their own suites
(``test-taxonomy.R``, ``run_conformance.do`` Part 8), because only that language
can trigger its own errors.
"""

from __future__ import annotations

import getpass
import re
from pathlib import Path

import pytest

import datalib as dl
from datalib import errors as E

from conftest import read_cases

ROWS = read_cases("error_taxonomy.csv")


# --------------------------------------------------------------------- doc truth


def _grammar_table(repo_root: Path) -> list[dict[str, str]]:
    """Parse the section 6 taxonomy table out of config/grammar.md."""
    text = (repo_root / "config" / "grammar.md").read_text(encoding="utf-8")
    header = "| contract error | Stata rc | R condition classes | Python exception |"
    assert header in text, (
        "config/grammar.md section 6 no longer has the expected taxonomy table "
        "header; the doc-truth test cannot find the table it must check"
    )
    out: list[dict[str, str]] = []
    for line in text.split(header, 1)[1].splitlines():
        raw = line.strip()
        if not raw.startswith("|"):
            if out:
                break                            # table ended
            continue                             # not into the rows yet
        cells = [c.strip() for c in raw.strip("|").split("|")]
        # the |---|---| separator row
        if all(set(c) <= {"-", ":"} for c in cells):
            continue
        assert len(cells) == 4, f"malformed taxonomy row in grammar.md: {raw!r}"
        # Cells are prose: a value may or may not be backticked, and a cell may
        # hold several space-separated tokens (`198` `601`). Normalise by dropping
        # backticks and collapsing whitespace, so the CSV is compared on values
        # rather than on markdown decoration.
        norm = [re.sub(r"\s+", " ", c.replace("`", "")).strip() for c in cells]
        out.append(
            {
                "error_name": norm[0],
                "stata_rc": norm[1],
                "r_classes": norm[2],
                "python_exc": norm[3],
            }
        )
    return out


def test_grammar_table_matches_the_csv(repo_root: Path) -> None:
    """grammar.md section 6 is the prose; the CSV is the machine-readable form."""
    assert _grammar_table(repo_root) == [dict(r) for r in ROWS]


def test_taxonomy_csv_covers_every_contract_error() -> None:
    assert [r["error_name"] for r in ROWS] == [
        "input_invalid",
        "not_found",
        "config_file_missing",
        "user_block_missing",
        "root_unset",
    ]


# -------------------------------------------------------------------- code truth


@pytest.mark.parametrize("row", ROWS, ids=[r["error_name"] for r in ROWS])
def test_python_exception_name_exists(row) -> None:
    exc = getattr(E, row["python_exc"], None)
    assert exc is not None, (
        f"{row['error_name']}: grammar.md names {row['python_exc']}, "
        f"which does not exist in datalib.errors"
    )
    assert issubclass(exc, E.DatalibError)


def _trigger(error_name: str, fixture_root, tmp_path, monkeypatch):
    """A real call that must raise the row's exception."""
    if error_name == "input_invalid":
        return lambda: dl.datalib_vintages(
            "ZWE", "notayear", "MICS", root=fixture_root
        )
    if error_name == "not_found":
        # CountryNotFound is a NotFoundError subclass, so the documented parent
        # is what a portable caller catches.
        return lambda: dl.datalib_resolve("XXX", 2019, "MICS", root=fixture_root)
    if error_name == "config_file_missing":
        return lambda: dl.datalib_config(config=tmp_path / "no_such_file.yml")
    if error_name == "user_block_missing":
        cfg = tmp_path / "user_config.yml"
        cfg.write_text('someoneelse:\n  datalib: "Z:/x"\n', encoding="utf-8")
        return lambda: dl.datalib_config(user="nobody", config=cfg)
    if error_name == "root_unset":
        # A block that exists for this user but carries no datalib: key -- the
        # only path to DatalibRootNotSet, since a missing file raises
        # ConfigFileNotFound instead.
        cfg = tmp_path / "user_config.yml"
        cfg.write_text(f"{getpass.getuser()}:\n  githubFolder: \"C:/GitHub\"\n",
                       encoding="utf-8")
        monkeypatch.delenv("DATALIB_ROOT", raising=False)
        monkeypatch.setenv("DATALIB_CONFIG", str(cfg))
        return dl.datalib_root
    raise AssertionError(f"no trigger defined for {error_name!r}")


@pytest.mark.parametrize("row", ROWS, ids=[r["error_name"] for r in ROWS])
def test_documented_exception_is_the_one_raised(
    row, fixture_root, tmp_path, monkeypatch
) -> None:
    exc = getattr(E, row["python_exc"])
    with pytest.raises(exc):
        _trigger(row["error_name"], fixture_root, tmp_path, monkeypatch)()
