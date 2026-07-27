"""Unit tests for the single folder-name parser/formatter (grammar.py)."""

from __future__ import annotations

import pytest

from datalib.errors import InvalidArgumentError
from datalib.grammar import (
    adaptation_folder,
    format_vintage,
    master_folder,
    parse_name,
    parse_vintage,
    parse_year,
    survey_folder,
)


# ---- vintages: accept 1 / 01 / v01 / V01; integers internally; v%02d out ----


@pytest.mark.parametrize(
    "value,expected",
    [(1, 1), ("1", 1), ("01", 1), ("v01", 1), ("V01", 1), (" v2 ", 2),
     ("v10", 10), (10, 10), ("V09", 9)],
)
def test_parse_vintage_accepted_spellings(value, expected) -> None:
    assert parse_vintage(value) == expected


@pytest.mark.parametrize("value", ["", "vv1", "x1", "1.5", "-1", 0, -3, None, 1.5, True])
def test_parse_vintage_rejects(value) -> None:
    with pytest.raises(InvalidArgumentError):
        parse_vintage(value)


def test_format_vintage() -> None:
    assert format_vintage(1) == "v01"
    assert format_vintage(10) == "v10"
    with pytest.raises(InvalidArgumentError):
        format_vintage(0)


def test_numeric_latest_not_alphabetical() -> None:
    # v10 > v09 numerically even though "v10" < "v09" alphabetically is False;
    # the point: comparisons happen on ints, never strings
    assert max(parse_vintage("v09"), parse_vintage("v10")) == 10


# ---- year coercion ----


def test_parse_year() -> None:
    assert parse_year(2019) == 2019
    assert parse_year("2019") == 2019
    with pytest.raises(InvalidArgumentError):
        parse_year("MICS")


# ---- folder-name formatting ----


def test_folder_formatting_roundtrip() -> None:
    assert survey_folder("ZWE", 2019, "MICS") == "ZWE_2019_MICS"
    assert master_folder("ZWE", 2019, "MICS", 2) == "ZWE_2019_MICS_v02_M"
    assert (
        adaptation_folder("ZWE", 2019, "MICS", 2, 1, "HLT")
        == "ZWE_2019_MICS_v02_M_v01_A_HLT"
    )


# ---- parsing 1/3/5/8-token names ----


def test_parse_name_country() -> None:
    p = parse_name("zwe")
    assert (p.level, p.country) == ("country", "ZWE")


def test_parse_name_survey() -> None:
    p = parse_name("ZWE_2019_MICS")
    assert (p.level, p.country, p.year, p.survey) == ("survey", "ZWE", 2019, "MICS")


def test_parse_name_master() -> None:
    p = parse_name("BRA_2015_PNAD_v10_M")
    assert p.level == "master"
    assert p.master_version == 10
    assert p.adaptation_version is None


def test_parse_name_adaptation() -> None:
    p = parse_name("ZWE_2019_MICS_v02_M_v01_A_HLT")
    assert p.level == "adaptation"
    assert (p.master_version, p.adaptation_version, p.collection) == (2, 1, "HLT")
    # token positions: 1 country, 2 year, 3 survey, 4 vm, 6 va, 8 collection
    assert (p.country, p.year, p.survey) == ("ZWE", 2019, "MICS")


def test_parse_name_case_normalizes() -> None:
    p = parse_name("zwe_2019_mics_V02_m_v01_a_hlt")
    assert p.level == "adaptation"
    assert (p.country, p.survey, p.collection) == ("ZWE", "MICS", "HLT")
    assert (p.master_version, p.adaptation_version) == (2, 1)


@pytest.mark.parametrize(
    "bad",
    ["", "ZWE_2019", "ZWE_2019_MICS_v01", "ZWE_2019_MICS_v01_X",
     "ZWE_YEAR_MICS", "ZWE_2019_MICS_v01_M_v01_A", "ZWE_2019_MICS_vXX_M"],
)
def test_parse_name_rejects(bad) -> None:
    with pytest.raises(InvalidArgumentError):
        parse_name(bad)
