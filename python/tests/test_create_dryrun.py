"""create(): dry-run (the default) must be pure — it reports paths and
touches NOTHING (contract v1 fixed the old Stata _mkdir check-mode side
effect). Real creation is exercised only inside tmp_path.
"""

from __future__ import annotations

from pathlib import Path

import pytest

import datalib as dl
from datalib.errors import InvalidArgumentError, VintageNotFound


def _tree_snapshot(root: Path) -> list[str]:
    return sorted(str(p.relative_to(root)) for p in root.rglob("*"))


def test_dryrun_is_default_and_touches_nothing(fixture_root) -> None:
    before = _tree_snapshot(fixture_root)
    paths = dl.create("ZWE", 2019, "MICS", kind="master", root=fixture_root)
    after = _tree_snapshot(fixture_root)
    assert before == after, "dry-run create must not touch the tree"
    # latest master on disk is v02 -> latest+1 increment rule
    assert paths.stem == "ZWE_2019_MICS_v03_M"
    assert not paths.vintage_dir.exists()


def test_dryrun_adaptation_increments_latest(fixture_root) -> None:
    before = _tree_snapshot(fixture_root)
    paths = dl.create("zwe", 2019, "mics", kind="adaptation", root=fixture_root)
    assert _tree_snapshot(fixture_root) == before
    # master defaults to latest (v02); HLT adaptation v01 exists -> v02
    assert paths.stem == "ZWE_2019_MICS_v02_M_v02_A_HLT"
    assert paths.master_version == 2
    assert paths.adaptation_version == 2
    assert not paths.vintage_dir.exists()


def test_dryrun_new_survey_defaults_to_v01(tmp_path) -> None:
    paths = dl.create("ALB", 2020, "MICS", kind="master", root=tmp_path)
    assert paths.stem == "ALB_2020_MICS_v01_M"
    assert list(tmp_path.iterdir()) == [], "dry-run created files"


def test_adaptation_without_master_errors(tmp_path) -> None:
    with pytest.raises(VintageNotFound):
        dl.create("ALB", 2020, "MICS", kind="adaptation", root=tmp_path)


def test_real_create_builds_standard_tree(tmp_path) -> None:
    paths = dl.create("ALB", 2020, "MICS", kind="master", dry_run=False, root=tmp_path)
    assert paths.vintage_dir.is_dir()
    for sub in (
        paths.data_original,
        paths.data_stata,
        paths.data_r,
        paths.data_other,
        paths.doc,
        paths.programs,
    ):
        assert sub.is_dir(), sub


def test_existing_vintage_requires_overwrite(tmp_path) -> None:
    dl.create("ALB", 2020, "MICS", kind="master", master_version=1,
              dry_run=False, root=tmp_path)
    with pytest.raises(InvalidArgumentError):
        dl.create("ALB", 2020, "MICS", kind="master", master_version=1,
                  root=tmp_path)
    # explicit overwrite resolves to the same folder without error
    paths = dl.create("ALB", 2020, "MICS", kind="master", master_version=1,
                      overwrite=True, root=tmp_path)
    assert paths.stem == "ALB_2020_MICS_v01_M"
