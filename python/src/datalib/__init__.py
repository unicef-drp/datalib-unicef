"""datalib — client for the UNICEF microdata library folder standard.

Python binding of the language-neutral datalib contract v1
(config/grammar.md). The contract's canonical ``datalib_<verb>`` tokens are
exported verbatim as aliases of the idiomatic names, so the identical name
works in Stata, R and Python. ``getuserconfig`` / ``mapzdrive`` keep their
existing names in all three languages.
"""

from __future__ import annotations

from .catalog import (
    AdaptationInfo,
    AdaptationVintage,
    CatalogEntry,
    Entry,
    Listing,
    VintageCatalog,
    VintagePaths,
    adaptations,
    browse,
    catalog,
    countries,
    files,
    resolve,
    surveys,
    vintages,
)
from .config import UserConfig, getuserconfig, resolve_root
from .create import create
from .drive import MapResult, MapStatus, mapzdrive
from .errors import (
    ConfigFileNotFound,
    CountryNotFound,
    DatalibError,
    DatalibRootNotSet,
    DriveMappingError,
    FileNotFoundInLibrary,
    InvalidArgumentError,
    NotFoundError,
    SurveyNotFound,
    UnsupportedPlatformError,
    UserBlockNotFound,
    VintageNotFound,
)
from .grammar import ParsedName, format_vintage, parse_name, parse_vintage
from .io import DtaMeta, read_dta
from .load import load
from .registry import Collection, ModuleSpec, contract_version, get_collection
from .update import UpdateStatus, datalib_update

__version__ = "0.9.19"
CONTRACT_VERSION = "1"

# ---- canonical cross-language aliases (contract: datalib_<verb>) ----
datalib_config = getuserconfig
datalib_root = resolve_root
datalib_countries = countries
datalib_surveys = surveys
datalib_vintages = vintages
datalib_adaptations = adaptations
datalib_resolve = resolve
datalib_files = files
datalib_catalog = catalog
datalib_load = load
datalib_browse = browse
datalib_create = create
datalib_map_drive = mapzdrive
map_drive = mapzdrive

__all__ = [
    # idiomatic surface
    "load",
    "resolve",
    "files",
    "catalog",
    "browse",
    "create",
    "countries",
    "surveys",
    "vintages",
    "adaptations",
    "getuserconfig",
    "resolve_root",
    "mapzdrive",
    "map_drive",
    "read_dta",
    # canonical contract aliases
    "datalib_config",
    "datalib_root",
    "datalib_countries",
    "datalib_surveys",
    "datalib_vintages",
    "datalib_adaptations",
    "datalib_resolve",
    "datalib_files",
    "datalib_catalog",
    "datalib_load",
    "datalib_browse",
    "datalib_create",
    "datalib_map_drive",
    # structures
    "UserConfig",
    "VintagePaths",
    "VintageCatalog",
    "AdaptationVintage",
    "AdaptationInfo",
    "CatalogEntry",
    "Entry",
    "Listing",
    "ParsedName",
    "Collection",
    "ModuleSpec",
    "DtaMeta",
    "MapResult",
    "MapStatus",
    # grammar / registry helpers
    "parse_vintage",
    "format_vintage",
    "parse_name",
    "get_collection",
    "contract_version",
    "UpdateStatus",
    "datalib_update",
    # errors
    "DatalibError",
    "InvalidArgumentError",
    "NotFoundError",
    "CountryNotFound",
    "SurveyNotFound",
    "VintageNotFound",
    "FileNotFoundInLibrary",
    "ConfigFileNotFound",
    "UserBlockNotFound",
    "DatalibRootNotSet",
    "DriveMappingError",
    "UnsupportedPlatformError",
    # meta
    "__version__",
    "CONTRACT_VERSION",
]
