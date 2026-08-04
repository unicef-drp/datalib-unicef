"""The bundled collections.yml must equal config/collections.yml byte-for-byte.

config/collections.yml is the single source of truth; the copy inside the
package exists only so installed wheels are self-contained.
"""

from __future__ import annotations

import datalib
from datalib.registry import collections, contract_version, get_collection, registry_path


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


def test_every_module_token_is_lowercase() -> None:
    """Every module token in the REGISTRY is lowercase. Scope is deliberate and narrow.

    This checks ``collections.yml`` only. It does not scan any deposit, so a mixed-case file
    on disk is not caught here -- it surfaces later as a load that cannot find its file. The
    registry is the half worth guarding because it is what the loader trusts to build the
    name; the disk half is a deposit-review question.

    A module token is part of a file name: ``load.py`` builds ``f"{rp.stem}_{module}.dta"``.
    So an uppercase token against a lowercase file -- or the reverse -- resolves on
    Windows and fails on Linux and macOS, which is where CI runs. Stata is worse: ``: dir``
    lowercases names on Windows, so the Stata leg cannot observe the true case even where
    the filesystem would forgive it, making ``..._ACG.dta`` unreadable from Stata anywhere.

    The real archive already has both conventions -- MICS/DHS deposits use ``_bh``,
    ``_adult``; IEA deposits use ``_ACG`` -- so this is a live inconsistency rather than a
    hypothetical one. The registry is the side that must not drift, because it is what the
    loader trusts.

    Collection NAMES stay uppercase (``HLT``, ``IPUMS``): those are identifiers an operator
    types, not file-name fragments. See grammar.md section "Shared semantics", rule 1.
    """
    # Iterate the REGISTRY, never a hard-coded list. A literal ("HLT", "IPUMS") would stop
    # enforcing the invariant the moment a collection is added -- which is the same
    # enumeration-goes-stale failure that made verify.ps1's manifest list short three times.
    # collections() is what load.py itself consults, so the guard covers exactly what the
    # loader trusts.
    reg = collections()
    assert reg, "registry is empty, so this guard would pass having checked nothing"
    offenders = [
        f"{name}.{mod}"
        for name, coll in reg.items()
        for mod in coll.module_names
        if mod != mod.lower()
    ]
    assert not offenders, (
        "module tokens must be lowercase; these are not: " + ", ".join(offenders)
    )
