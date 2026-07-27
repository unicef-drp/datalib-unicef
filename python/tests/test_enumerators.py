"""Behavioural tests for the four enumerators, against the committed fixture.

Added in v0.9.6 to close a real gap: before this file, ``datalib_countries``,
``datalib_surveys``, ``datalib_vintages`` and ``datalib_adaptations`` -- four of
the thirteen canonical commands -- had **no behavioural coverage at all** in
either CI-runnable language. The only references anywhere in the suite were
name-surface lists in :mod:`test_docs` (that the function exists and is
exported), which cannot catch a wrong return value.

These are deliberately NOT shared golden cases. The three ports return
structurally different objects for the same query -- Stata's
``datalib_adaptations`` returns ``r(collections)="HLT IPUMS"`` and its
``datalib_vintages`` returns bare integers in ``r(masters)="9 10"``, R returns
data frames whose ``folder`` column holds full vintage folder names, and Python
returns ``VintageCatalog`` / ``AdaptationInfo`` objects. A single shared
``expect_items`` column could therefore match at most one language. Whether the
return shapes should converge is a contract question for
``config/grammar.md``, not something a CSV can paper over; until it is settled,
each language asserts its own shape against the same fixture tree.
"""

from __future__ import annotations

import pytest

import datalib as dl


def test_countries_are_uppercase_and_complete(fixture_root) -> None:
    assert dl.datalib_countries(root=fixture_root) == ["BRA", "KEN", "ZWE"]


def test_surveys_lists_the_survey_folder(fixture_root) -> None:
    assert dl.datalib_surveys("ZWE", root=fixture_root) == ["ZWE_2019_MICS"]


def test_country_is_uppercased_at_the_boundary(fixture_root) -> None:
    """Contract rule 1: inputs are trimmed and uppercased before matching."""
    assert dl.datalib_surveys("zwe", root=fixture_root) == ["ZWE_2019_MICS"]
    assert dl.datalib_surveys("  ZWE  ", root=fixture_root) == ["ZWE_2019_MICS"]


def test_vintages_reports_masters_as_integers(fixture_root) -> None:
    cat = dl.datalib_vintages("ZWE", 2019, "MICS", root=fixture_root)
    assert cat.masters == (1, 2)


def test_latest_master_is_the_numeric_maximum_not_alphabetical(fixture_root) -> None:
    """Contract rule 2: latest is the numeric maximum, so v10 > v09.

    BRA_2015_PNAD carries v09 and v10 precisely so this cannot pass by accident:
    directory-listing or alphabetical order would pick v09.
    """
    cat = dl.datalib_vintages("BRA", 2015, "PNAD", root=fixture_root)
    assert cat.masters == (9, 10)
    assert max(cat.masters) == 10


def test_adaptations_lists_collection_names(fixture_root) -> None:
    names = [a.name for a in dl.datalib_adaptations("ZWE", 2019, "MICS", root=fixture_root)]
    assert names == ["HLT", "IPUMS"]


def test_a_country_with_no_adaptations_returns_empty(fixture_root) -> None:
    assert dl.datalib_adaptations("BRA", 2015, "PNAD", root=fixture_root) == []


def test_present_but_empty_root_is_an_empty_listing(tmp_path) -> None:
    """A root that exists but holds no countries is empty, not an error.

    This is the half of enumerator emptiness the contract already settles; the
    absent-parent half is the divergence below.
    """
    assert dl.datalib_countries(root=tmp_path) == []


@pytest.mark.xfail(
    strict=True,
    reason=(
        "v0.10.0: Python must raise on an absent parent. Stata exits 198 and R "
        "raises datalib_error_input for an unknown country; Python returns []. "
        "Tracked in the config/grammar.md Alignment status table "
        "('enumerators error on an absent parent'). strict=True means this "
        "becomes a FAILURE the moment Python is fixed -- delete the marker then."
    ),
)
def test_unknown_country_raises(fixture_root) -> None:
    with pytest.raises(dl.errors.NotFoundError):
        dl.datalib_surveys("XXX", root=fixture_root)
