"""Golden load cases (shared tests/cases_load.csv) — must pass unmodified.

Row counts pin the merge semantics (person 1:1 outer chain, then hh m:1
outer keeping unmatched hh rows); the expect_windex8 column pins the
no-mutation contract (windex5 == 8 must SURVIVE loading — the pre-contract
Stata loader silently recoded it to missing).
"""

from __future__ import annotations

import pandas as pd
import pytest

from conftest import read_cases

import datalib as dl
from datalib.errors import InvalidArgumentError, NotFoundError

CASES = read_cases("cases_load.csv")


def _counts(result) -> tuple[int, int]:
    """(row count, windex5==8 count) over a DataFrame or a module dict."""
    frames = list(result.values()) if isinstance(result, dict) else [result]
    n = sum(len(df) for df in frames)
    w8 = sum(
        int((df["windex5"] == 8).sum())
        for df in frames
        if "windex5" in df.columns
    )
    return n, w8


@pytest.mark.parametrize("case", CASES, ids=[c["case_id"] for c in CASES])
def test_load_case(case: dict[str, str], fixture_root) -> None:
    kwargs = dict(
        country=case["country"],
        year=case["year"] or None,
        survey=case["survey"] or None,
        kind=case["kind"] or "adaptation",
        collection=case["collection"] or None,
        modules=case["modules"].split() or None,
        master_version=case["master_version"] or None,
        merge=not case["nomerge"],
        root=fixture_root,
    )
    if case["expect_error"]:
        with pytest.raises((InvalidArgumentError, NotFoundError)):
            dl.load(**kwargs)
        return

    result = dl.load(**kwargs)
    if case["nomerge"]:
        assert isinstance(result, dict)
    else:
        assert isinstance(result, pd.DataFrame)

    n, w8 = _counts(result)
    assert n == int(case["expect_n"]), f"row count for {case['case_id']}"
    if case["expect_windex8"]:
        assert w8 == int(case["expect_windex8"]), (
            f"windex5==8 count for {case['case_id']} (no-mutation contract)"
        )

    # provenance columns are always present after load
    frames = list(result.values()) if isinstance(result, dict) else [result]
    for df in frames:
        assert "ctrycode" in df.columns
        assert "year" in df.columns
        assert (df["ctrycode"] == case["country"].upper()).all()
