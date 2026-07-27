"""The bundled collections.yml must equal config/collections.yml byte-for-byte.

config/collections.yml is the single source of truth; the copy inside the
package exists only so installed wheels are self-contained.
"""

from __future__ import annotations

import datalib
from datalib.registry import contract_version, get_collection, registry_path


def test_bundled_registry_is_byte_identical(repo_root) -> None:
    canonical = repo_root / "config" / "collections.yml"
    bundled = registry_path()
    assert canonical.is_file(), f"missing source of truth: {canonical}"
    assert bundled.is_file(), f"missing bundled copy: {bundled}"
    assert bundled.read_bytes() == canonical.read_bytes(), (
        "bundled src/datalib/collections.yml has drifted from "
        "config/collections.yml — re-copy the canonical file byte-for-byte"
    )


def test_contract_version_pinned() -> None:
    assert str(contract_version()) == datalib.CONTRACT_VERSION == "1"


def test_registry_contents_match_contract() -> None:
    hlt = get_collection("HLT")
    assert hlt.module_names == ("household", "hhmembers", "adult", "children")
    assert hlt.keys_hh == ("svy_id", "cluster_id", "household_id")
    assert hlt.keys_person == ("svy_id", "cluster_id", "household_id", "line_number")
    assert hlt.module("hhmembers").linevar == "hh_line_number"
    assert hlt.module("household").level == "hh"

    ipums = get_collection("ipums")  # case-insensitive lookup
    assert ipums.module_names == ("hh", "bh", "ch", "fs", "hl", "mn", "wm")
    assert ipums.module("hh").level == "hh"
