"""The six shared file-section names are identical across the three languages.

Pins the datalib_files surface alignment (contract v1): data, data-original,
data-r, data-other, doc, programs — plus the fixture's known data content.
"""

from __future__ import annotations

import pytest

import datalib as dl

SECTIONS = ["data", "data-original", "data-r", "data-other", "doc", "programs"]


@pytest.mark.parametrize("section", SECTIONS)
def test_section_accepted(section: str, fixture_root) -> None:
    paths = dl.files(
        "ZWE", 2019, "MICS", collection="HLT", section=section, root=fixture_root
    )
    assert isinstance(paths, list)


def test_data_section_lists_the_four_modules(fixture_root) -> None:
    paths = dl.files("ZWE", 2019, "MICS", collection="HLT", root=fixture_root)
    assert len(paths) == 4


def test_unknown_section_raises(fixture_root) -> None:
    from datalib.errors import InvalidArgumentError

    with pytest.raises(InvalidArgumentError):
        dl.files("ZWE", 2019, "MICS", collection="HLT",
                 section="nope", root=fixture_root)
