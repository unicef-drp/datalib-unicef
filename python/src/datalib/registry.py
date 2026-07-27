"""Collection registry loaded from the bundled copy of collections.yml.

The repository file ``config/collections.yml`` is the single source of truth;
the copy shipped inside this package must match it byte-for-byte (asserted by
``tests/test_registry_sync.py``).
"""

from __future__ import annotations

from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path

import yaml

from .errors import InvalidArgumentError

__all__ = [
    "ModuleSpec",
    "Collection",
    "registry_path",
    "contract_version",
    "collections",
    "get_collection",
]


@dataclass(frozen=True)
class ModuleSpec:
    """A module a collection ships: its level and person-line variable.

    Attributes
    ----------
    name : str
        Module name (lowercase), e.g. ``hh`` or ``wm``.
    level : str
        Merge level: "hh" (household) or "person".
    linevar : str
        The person-line variable in the raw file; when it differs from
        ``line_number`` the loader renames it on load (the single
        documented normalization).
    """

    name: str
    level: str  # "hh" | "person"
    linevar: str = "line_number"


@dataclass(frozen=True)
class Collection:
    """A collection: module list (in registry order) and merge keys.

    Attributes
    ----------
    name : str
        Collection token (uppercase), e.g. ``HLT``.
    keys_hh : tuple of str
        Household-level merge keys.
    keys_person : tuple of str
        Person-level merge keys.
    modules : tuple of ModuleSpec
        The modules the collection ships, in registry order.
    """

    name: str
    keys_hh: tuple[str, ...]
    keys_person: tuple[str, ...]
    modules: tuple[ModuleSpec, ...]

    @property
    def module_names(self) -> tuple[str, ...]:
        """The module names, in registry order."""
        return tuple(m.name for m in self.modules)

    def module(self, name: str) -> ModuleSpec:
        """Look up one module of this collection by exact name.

        Parameters
        ----------
        name : str
            Module name, e.g. ``hh`` (exact registry match, no aliasing).

        Returns
        -------
        ModuleSpec
            The module's registry entry.

        Raises
        ------
        InvalidArgumentError
            If the collection has no module of that name.
        """
        for m in self.modules:
            if m.name == name:
                return m
        raise InvalidArgumentError(
            f"module {name!r} is not part of collection {self.name} "
            f"(expected one of: {', '.join(self.module_names)})."
        )


def registry_path() -> Path:
    """Path of the bundled collections.yml copy.

    Returns
    -------
    Path
        The collections.yml shipped next to this module (kept
        byte-identical to the repository config/collections.yml).
    """
    return Path(__file__).with_name("collections.yml")


@lru_cache(maxsize=1)
def _raw() -> dict:
    """The bundled collections.yml parsed once (cached); typed error if malformed."""
    with open(registry_path(), "r", encoding="utf-8") as fh:
        data = yaml.safe_load(fh)
    if not isinstance(data, dict) or "collections" not in data:
        raise InvalidArgumentError("bundled collections.yml is malformed.")
    return data


def contract_version() -> int:
    """The contract version pinned by the registry.

    Returns
    -------
    int
        The ``contract_version`` value from the bundled collections.yml
        (1 for contract v1).
    """
    return int(_raw()["contract_version"])


@lru_cache(maxsize=1)
def collections() -> dict[str, Collection]:
    """All collections defined by the registry.

    Parsed once from the bundled collections.yml and cached; modules keep
    registry order, and an omitted ``linevar`` defaults to
    ``line_number``.

    Returns
    -------
    dict of str to Collection
        Collections keyed by (uppercase) name, in registry order.
    """
    out: dict[str, Collection] = {}
    for name, spec in _raw()["collections"].items():
        modules = tuple(
            ModuleSpec(
                name=mod,
                level=str(mspec["level"]),
                linevar=str(mspec.get("linevar", "line_number")),
            )
            for mod, mspec in spec["modules"].items()
        )
        out[name] = Collection(
            name=name,
            keys_hh=tuple(spec["keys_hh"]),
            keys_person=tuple(spec["keys_person"]),
            modules=modules,
        )
    return out


def get_collection(name: str) -> Collection:
    """Look up a collection by name.

    The name is trimmed and uppercased before the (exact) registry
    lookup, matching the boundary normalization used everywhere else.

    Parameters
    ----------
    name : str
        Collection token, e.g. ``hlt`` or ``HLT``.

    Returns
    -------
    Collection
        The registry entry for the collection.

    Raises
    ------
    InvalidArgumentError
        If the registry has no collection of that name.
    """
    key = str(name).strip().upper()
    reg = collections()
    if key not in reg:
        raise InvalidArgumentError(
            f"unknown collection {name!r} (registry: {', '.join(reg)})."
        )
    return reg[key]
