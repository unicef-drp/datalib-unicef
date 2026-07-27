"""Golden resolve cases (shared tests/cases_resolve.csv) — must pass unmodified.

Empty year/survey/vintage cells mean "omitted -> default per contract";
lowercase inputs must normalize; expect_error rows must raise a typed error.
"""

from __future__ import annotations

import pytest

from conftest import read_cases

import datalib as dl
from datalib.errors import InvalidArgumentError, NotFoundError

CASES = read_cases("cases_resolve.csv")


@pytest.mark.parametrize("case", CASES, ids=[c["case_id"] for c in CASES])
def test_resolve_case(case: dict[str, str], fixture_root) -> None:
    kwargs = dict(
        country=case["country"],
        year=case["year"] or None,
        survey=case["survey"] or None,
        kind=case["kind"] or "adaptation",
        collection=case["collection"] or None,
        master_version=case["master_version"] or None,
        adaptation_version=case["adaptation_version"] or None,
        root=fixture_root,
    )
    if case["expect_error"]:
        assert case["expect_error"] == "input"
        with pytest.raises((InvalidArgumentError, NotFoundError)):
            dl.resolve(**kwargs)
    else:
        rp = dl.resolve(**kwargs)
        assert rp.vintage_dir.name == case["expect_vintage_folder"]
        assert rp.stem == case["expect_vintage_folder"]
        assert rp.vintage_dir.is_dir()
