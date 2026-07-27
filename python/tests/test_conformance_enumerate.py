"""Shared enumerator conformance cases (contract v1, grammar.md rule 9).

The contract pins the **value set** an enumerator returns, not the container, so
this file adapts Python's own return types to the normalised list defined in
``grammar.md`` rule 9 and compares against ``tests/cases_enumerate.csv`` -- the
same rows R and Stata assert.

The normalisation is what makes a shared corpus possible: Python returns
``VintageCatalog`` / ``AdaptationInfo`` objects, R returns data frames of full
folder names, Stata returns space-separated strings in ``r()``. A corpus that
matched the *container* could match at most one of the three, which is why the
first attempt at this file was abandoned as impossible.
"""

from __future__ import annotations

import pytest

import datalib as dl

from conftest import read_cases

CASES = read_cases("cases_enumerate.csv")


def _normalise(fn: str, country: str, year: str, survey: str, root) -> str:
    """Adapt Python's return type to the contract's normalised list.

    grammar.md rule 9 fixes both the value set and its order per enumerator;
    vintages sort NUMERICALLY (sorting 9 and 10 as text would give "10 9").
    """
    if fn == "countries":
        return " ".join(sorted(dl.datalib_countries(root=root)))
    if fn == "surveys":
        return " ".join(sorted(dl.datalib_surveys(country, root=root)))
    if fn == "vintages":
        cat = dl.datalib_vintages(country, year, survey, root=root)
        return " ".join(str(m) for m in sorted(cat.masters))
    if fn == "adaptations":
        got = dl.datalib_adaptations(country, year, survey, root=root)
        return " ".join(sorted(a.name for a in got))
    raise AssertionError(f"unknown fn in cases_enumerate.csv: {fn!r}")


@pytest.mark.parametrize("case", CASES, ids=[c["case_id"] for c in CASES])
def test_enumerate_case(case, fixture_root) -> None:
    got = _normalise(
        case["fn"], case["country"], case["year"], case["survey"], fixture_root
    )
    assert got == case["expect_values"], (
        f"{case['case_id']} ({case['fn']}): "
        f"expected {case['expect_values']!r}, got {got!r}"
    )


def test_every_enumerator_is_covered() -> None:
    """A corpus that silently stops covering an enumerator is worse than none."""
    assert {c["fn"] for c in CASES} == {
        "countries",
        "surveys",
        "vintages",
        "adaptations",
    }
