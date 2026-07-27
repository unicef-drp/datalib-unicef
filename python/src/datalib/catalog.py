"""Pure path logic over the library tree: enumerate, resolve, browse.

Behavior mirrors stata/d/datalib_resolve.ado (the contract reference):
uppercase-once at the boundary, exact (case-normalized) matching, numeric
latest for years and vintages, and the resolved folder verified to exist.

Enumerators (countries/surveys/vintages/adaptations/catalog) return empty
results when nothing matches; resolvers and browse raise typed errors.
"""

from __future__ import annotations

import fnmatch
import os
from dataclasses import dataclass
from pathlib import Path

from .config import resolve_root
from .errors import (
    CountryNotFound,
    InvalidArgumentError,
    SurveyNotFound,
    VintageNotFound,
)
from .grammar import (
    ParsedName,
    adaptation_folder,
    format_vintage,
    master_folder,
    parse_name,
    parse_vintage,
    parse_year,
    survey_folder,
)

__all__ = [
    "VintagePaths",
    "VintageCatalog",
    "AdaptationVintage",
    "AdaptationInfo",
    "CatalogEntry",
    "Entry",
    "Listing",
    "countries",
    "surveys",
    "vintages",
    "adaptations",
    "resolve",
    "files",
    "catalog",
    "browse",
]

_SECTIONS = {
    "data": ("Data", "Stata"),
    "data-original": ("Data", "Original"),
    "data-r": ("Data", "R"),
    "data-other": ("Data", "Other"),
    "doc": ("Doc",),
    "programs": ("Programs",),
}


# ---------------------------------------------------------------------------
# return structures
# ---------------------------------------------------------------------------


@dataclass(frozen=True)
class VintagePaths:
    """A resolved vintage: identity fields plus every standard path.

    Returned by resolve() and create(). Paths follow the fixed layout
    inside a vintage folder: ``Data/{Original,Stata,R,Other}``, ``Doc/``
    and ``Programs/`` (config/grammar.md folder grammar).

    Attributes
    ----------
    root : Path
        The resolved library root.
    country_dir : Path
        ``<root>/<CCC>/``.
    survey_dir : Path
        ``<root>/<CCC>/<CCC>_<YYYY>_<SSSS>/``.
    vintage_dir : Path
        The resolved master or adaptation vintage folder.
    data : Path
        ``<vintage_dir>/Data``.
    data_stata : Path
        ``<vintage_dir>/Data/Stata`` (module .dta files live here).
    data_original : Path
        ``<vintage_dir>/Data/Original``.
    data_other : Path
        ``<vintage_dir>/Data/Other``.
    data_r : Path
        ``<vintage_dir>/Data/R``.
    doc : Path
        ``<vintage_dir>/Doc``.
    programs : Path
        ``<vintage_dir>/Programs``.
    stem : str
        The on-disk vintage folder name (prefix of module file names).
    country : str
        Country token, uppercased.
    year : int
        Survey year.
    survey : str
        Survey acronym, uppercased.
    kind : str
        "master" or "adaptation".
    collection : str or None
        Collection token for adaptations; None for masters.
    master_version : int
        Master vintage number.
    adaptation_version : int or None
        Adaptation vintage number; None for masters.
    """

    root: Path
    country_dir: Path
    survey_dir: Path
    vintage_dir: Path
    data: Path
    data_stata: Path
    data_original: Path
    data_other: Path
    data_r: Path
    doc: Path
    programs: Path
    stem: str
    country: str
    year: int
    survey: str
    kind: str
    collection: str | None
    master_version: int
    adaptation_version: int | None


@dataclass(frozen=True)
class AdaptationVintage:
    """One adaptation vintage folder found under a survey folder.

    Attributes
    ----------
    master_version : int
        The master vintage the adaptation is attached to.
    adaptation_version : int
        The adaptation vintage number.
    collection : str
        The collection token (uppercased), e.g. ``HLT``.
    """

    master_version: int
    adaptation_version: int
    collection: str


@dataclass(frozen=True)
class VintageCatalog:
    """Vintages available under one survey folder.

    Returned by vintages(). Empty tuples mean nothing matched (the
    enumerators never raise for missing folders).

    Attributes
    ----------
    masters : tuple of int
        Master vintage numbers present, sorted ascending.
    adaptations : tuple of AdaptationVintage
        Adaptation vintages present, sorted by (collection, master,
        adaptation).
    """

    masters: tuple[int, ...]
    adaptations: tuple[AdaptationVintage, ...]

    @property
    def has_master(self) -> bool:
        """Whether at least one master vintage exists."""
        return bool(self.masters)

    @property
    def has_adaptation(self) -> bool:
        """Whether at least one adaptation vintage exists."""
        return bool(self.adaptations)

    @property
    def latest_master(self) -> int | None:
        """The numerically largest master vintage, or None when none exist."""
        return max(self.masters) if self.masters else None


@dataclass(frozen=True)
class AdaptationInfo:
    """One adaptation collection under a survey folder, with vintage count.

    Attributes
    ----------
    name : str
        Collection token (uppercased), e.g. ``HLT``.
    n_vintages : int
        Number of adaptation vintage folders of that collection.
    """

    name: str
    n_vintages: int


@dataclass(frozen=True)
class CatalogEntry:
    """One vintage folder in the whole-library catalog().

    Attributes
    ----------
    country : str
        Country token, uppercased.
    year : int
        Survey year.
    survey : str
        Survey acronym, uppercased.
    kind : str
        "master" or "adaptation".
    collection : str or None
        Collection token for adaptations; None for masters.
    master_version : int
        Master vintage number.
    adaptation_version : int or None
        Adaptation vintage number; None for masters.
    vintage_folder : str
        The on-disk vintage folder name.
    """

    country: str
    year: int
    survey: str
    kind: str
    collection: str | None
    master_version: int
    adaptation_version: int | None
    vintage_folder: str


@dataclass(frozen=True)
class Entry:
    """One directory entry in a browse() Listing.

    Attributes
    ----------
    name : str
        The on-disk directory name.
    kind : str
        What the entry is: "country", "survey", "master", "adaptation"
        or "section".
    token : str or None
        Feed this to the next browse() call to descend; None for
        section entries (leaves of the navigation).
    """

    name: str
    kind: str  # "country" | "survey" | "master" | "adaptation" | "section"
    token: str | None


@dataclass(frozen=True)
class Listing:
    """The result of one browse() step: a path and its entries.

    Attributes
    ----------
    path : Path
        The directory that was listed.
    level : str
        Depth of ``path``: "root", "country", "survey", "master" or
        "adaptation".
    entries : tuple of Entry
        The subdirectories, each carrying the token for the next step.
    """

    path: Path
    level: str
    entries: tuple[Entry, ...]

    def __repr__(self) -> str:  # pragma: no cover - cosmetic
        lines = [f"{self.level}: {self.path}"]
        lines += [f"  {e.name}  [{e.kind}]" for e in self.entries]
        return "\n".join(lines)


# ---------------------------------------------------------------------------
# scandir helpers (case-normalized exact matching)
# ---------------------------------------------------------------------------


def _scan_dirs(path: Path) -> list[str]:
    """Names of subdirectories of ``path`` (empty when path is missing)."""
    try:
        with os.scandir(path) as it:
            return [e.name for e in it if e.is_dir()]
    except (FileNotFoundError, NotADirectoryError):
        return []


def _match_dir(parent: Path, name: str) -> str | None:
    """Case-insensitive exact directory match; returns the on-disk name."""
    target = name.lower()
    for d in _scan_dirs(parent):
        if d.lower() == target:
            return d
    return None


def _norm_upper(value: str, what: str) -> str:
    """Trim and uppercase a required string input (contract semantics 1)."""
    if not isinstance(value, str) or not value.strip():
        raise InvalidArgumentError(f"{what} must be a non-empty string.")
    return value.strip().upper()


def _parse_dir(name: str) -> ParsedName | None:
    """parse_name() that returns None instead of raising on non-grammar names."""
    try:
        return parse_name(name)
    except InvalidArgumentError:
        return None


# ---------------------------------------------------------------------------
# enumerators
# ---------------------------------------------------------------------------


def countries(root: Path | str | None = None) -> list[str]:
    """List the countries available in the library.

    Canonical contract name: ``datalib_countries``. Enumerates the
    directories directly under the library root; an empty list means the
    root exists but holds no folders.

    Parameters
    ----------
    root : Path or str or None, optional
        Library root override; None follows the contract precedence chain
        (DATALIB_ROOT, then the ``datalib:`` config key).

    Returns
    -------
    list of str
        Sorted unique (uppercased) country folder names.

    Raises
    ------
    DatalibRootNotSet
        If no library root can be resolved.
    """
    rootp = resolve_root(root)
    return sorted({d.upper() for d in _scan_dirs(rootp)})


def surveys(country: str, *, root: Path | str | None = None) -> list[str]:
    """List the survey folders of one country.

    Canonical contract name: ``datalib_surveys``. The country input is
    trimmed/uppercased and matched exactly (case-insensitively) against
    the folders under the root; an unknown country yields ``[]`` rather
    than an error (enumerator semantics).

    Parameters
    ----------
    country : str
        Country token, e.g. ``BRA``.
    root : Path or str or None, optional
        Library root override; None follows the contract precedence chain.

    Returns
    -------
    list of str
        Sorted survey folder names (``<CCC>_<YYYY>_<SSSS>``), on-disk
        spelling; empty when the country has none or does not exist.

    Raises
    ------
    InvalidArgumentError
        If ``country`` is empty or not a string.
    DatalibRootNotSet
        If no library root can be resolved.
    """
    rootp = resolve_root(root)
    country = _norm_upper(country, "country")
    actual = _match_dir(rootp, country)
    if actual is None:
        return []
    return sorted(_scan_dirs(rootp / actual))


def _survey_dir(
    rootp: Path, country: str, year: int, survey: str
) -> tuple[Path, str] | None:
    """Locate a survey folder; (path, on-disk name) or None when absent."""
    actual_country = _match_dir(rootp, country)
    if actual_country is None:
        return None
    svyfld = survey_folder(country, year, survey)
    actual_svy = _match_dir(rootp / actual_country, svyfld)
    if actual_svy is None:
        return None
    return rootp / actual_country / actual_svy, actual_svy


def vintages(
    country: str,
    year: int | str,
    survey: str,
    *,
    root: Path | str | None = None,
) -> VintageCatalog:
    """List the master and adaptation vintages under one survey folder.

    Canonical contract name: ``datalib_vintages``. Inputs are normalized
    once at the boundary (trim/uppercase, year coerced to int); a missing
    survey folder yields an empty catalog rather than an error.

    Parameters
    ----------
    country : str
        Country token, e.g. ``BRA``.
    year : int or str
        Survey year, e.g. ``2019``.
    survey : str
        Survey acronym, e.g. ``MICS``.
    root : Path or str or None, optional
        Library root override; None follows the contract precedence chain.

    Returns
    -------
    VintageCatalog
        Sorted master vintage numbers and adaptation vintages found.

    Raises
    ------
    InvalidArgumentError
        If ``country``/``survey`` are empty or ``year`` is not an integer.
    DatalibRootNotSet
        If no library root can be resolved.
    """
    rootp = resolve_root(root)
    country = _norm_upper(country, "country")
    survey = _norm_upper(survey, "survey")
    year = parse_year(year)
    hit = _survey_dir(rootp, country, year, survey)
    if hit is None:
        return VintageCatalog(masters=(), adaptations=())
    svy_dir, _ = hit
    masters: list[int] = []
    adapts: list[AdaptationVintage] = []
    for d in _scan_dirs(svy_dir):
        parsed = _parse_dir(d)
        if parsed is None:
            continue
        if parsed.level == "master":
            masters.append(parsed.master_version)  # type: ignore[arg-type]
        elif parsed.level == "adaptation":
            adapts.append(
                AdaptationVintage(
                    master_version=parsed.master_version,  # type: ignore[arg-type]
                    adaptation_version=parsed.adaptation_version,  # type: ignore[arg-type]
                    collection=parsed.collection,  # type: ignore[arg-type]
                )
            )
    return VintageCatalog(
        masters=tuple(sorted(masters)),
        adaptations=tuple(
            sorted(
                adapts,
                key=lambda a: (a.collection, a.master_version, a.adaptation_version),
            )
        ),
    )


def adaptations(
    country: str,
    year: int | str,
    survey: str,
    *,
    root: Path | str | None = None,
) -> list[AdaptationInfo]:
    """List the adaptation collections under one survey folder.

    Canonical contract name: ``datalib_adaptations``. Aggregates the
    adaptation vintages reported by vintages() into one row per collection
    with its vintage count; a missing survey folder yields ``[]``.

    Parameters
    ----------
    country : str
        Country token, e.g. ``BRA``.
    year : int or str
        Survey year, e.g. ``2019``.
    survey : str
        Survey acronym, e.g. ``MICS``.
    root : Path or str or None, optional
        Library root override; None follows the contract precedence chain.

    Returns
    -------
    list of AdaptationInfo
        One entry per collection, sorted by collection name.

    Raises
    ------
    InvalidArgumentError
        If ``country``/``survey`` are empty or ``year`` is not an integer.
    DatalibRootNotSet
        If no library root can be resolved.
    """
    cat = vintages(country, year, survey, root=root)
    counts: dict[str, int] = {}
    for a in cat.adaptations:
        counts[a.collection] = counts.get(a.collection, 0) + 1
    return [AdaptationInfo(name=k, n_vintages=v) for k, v in sorted(counts.items())]


# ---------------------------------------------------------------------------
# resolve
# ---------------------------------------------------------------------------


def resolve(
    country: str,
    year: int | str | None = None,
    survey: str | None = None,
    *,
    kind: str = "adaptation",
    collection: str | None = None,
    master_version: int | str | None = None,
    adaptation_version: int | str | None = None,
    root: Path | str | None = None,
) -> VintagePaths:
    """Resolve a vintage request to concrete on-disk paths.

    Canonical contract name: ``datalib_resolve``. Pure path logic — touches
    no data; mirrors stata/d/datalib_resolve.ado. Inputs are normalized
    once at the boundary (trim/uppercase; vintages accept ``1``/``01``/
    ``v01``/``V01``). Matching is exact for country and exact-suffix
    (``*_<SURVEY>``) for survey folders — never substring. Omitted
    defaults follow contract semantics 3: latest year among matching
    survey folders, latest master on disk, latest adaptation of the
    requested collection under the chosen master — all numeric maxima,
    never alphabetical. The resolved vintage folder must exist.

    Parameters
    ----------
    country : str
        Country token, e.g. ``BRA``. Required.
    year : int or str or None, optional
        Survey year; None picks the numerically latest year among the
        country's matching survey folders.
    survey : str or None, optional
        Survey acronym, e.g. ``MICS``; None picks the survey of the
        latest-year folder.
    kind : str, optional
        "adaptation" (default) or "master".
    collection : str or None, optional
        Collection token for adaptations (default ``HLT``); must be None
        for kind="master".
    master_version : int or str or None, optional
        Master vintage; None means latest master on disk.
    adaptation_version : int or str or None, optional
        Adaptation vintage; None means latest adaptation of the requested
        collection under the chosen master.
    root : Path or str or None, optional
        Library root override; None follows the contract precedence chain.

    Returns
    -------
    VintagePaths
        Identity fields plus every standard path of the resolved vintage.

    Raises
    ------
    InvalidArgumentError
        If an input is malformed, ``kind`` is unknown, or ``collection``
        is combined with kind="master".
    CountryNotFound
        If the country folder does not exist under the root.
    SurveyNotFound
        If no survey folder matches the request.
    VintageNotFound
        If the requested (or defaulted) vintage folder is absent.
    DatalibRootNotSet
        If no library root can be resolved.
    """
    rootp = resolve_root(root)

    # ---- normalize inputs once at the boundary ----
    country = _norm_upper(country, "country")
    survey = _norm_upper(survey, "survey") if survey not in (None, "") else None
    collection = (
        _norm_upper(collection, "collection") if collection not in (None, "") else None
    )
    kind = (kind or "adaptation").strip().lower()
    if kind not in ("master", "adaptation"):
        raise InvalidArgumentError("kind must be 'master' or 'adaptation'.")
    if kind == "adaptation" and collection is None:
        collection = "HLT"
    if kind == "master" and collection is not None:
        raise InvalidArgumentError("collection applies only to kind='adaptation'.")

    vm = None if master_version in (None, "") else parse_vintage(master_version)
    va = None if adaptation_version in (None, "") else parse_vintage(adaptation_version)
    year = None if year in (None, "") else parse_year(year)

    # ---- country: exact folder match ----
    actual_country = _match_dir(rootp, country)
    if actual_country is None:
        raise CountryNotFound(f"Country {country} not found in datalib ({rootp}).")
    country_dir = rootp / actual_country

    # ---- survey folders (exact suffix), latest-year default ----
    all_folders = _scan_dirs(country_dir)
    if survey is not None:
        flist = [f for f in all_folders if f.upper().endswith(f"_{survey}")]
    else:
        flist = all_folders
    if not flist:
        raise SurveyNotFound(
            f"{survey or 'survey'} for {country} not available."
        )

    if survey is None:
        # pick numerically latest year, then that folder's survey
        ymax = -1
        for f in flist:
            parsed = _parse_dir(f)
            if parsed is None or parsed.year is None:
                continue
            if parsed.year > ymax:
                ymax = parsed.year
                survey = parsed.survey
        if survey is None:
            raise SurveyNotFound(f"Could not determine the survey for {country}.")
        if year is None:
            year = ymax
    if year is None:
        ymax = -1
        for f in flist:
            parsed = _parse_dir(f)
            if parsed is not None and parsed.year is not None and parsed.year > ymax:
                ymax = parsed.year
        if ymax < 0:
            raise SurveyNotFound(f"Could not determine the survey year for {country}.")
        year = ymax

    svyfld = survey_folder(country, year, survey)
    actual_svy = _match_dir(country_dir, svyfld)
    if actual_svy is None:
        raise SurveyNotFound(f"Survey folder {svyfld} not found.")
    survey_dir = country_dir / actual_svy

    # ---- vintage defaults: numeric latest on disk ----
    vdirs = [
        d for d in _scan_dirs(survey_dir) if d.upper().startswith(f"{svyfld.upper()}_")
    ]
    if vm is None:
        best = -1
        for d in vdirs:
            parsed = _parse_dir(d)
            if parsed is not None and parsed.level == "master":
                best = max(best, parsed.master_version)  # type: ignore[type-var]
        if best < 0:
            raise VintageNotFound(f"No master vintage found under {svyfld}.")
        vm = best
    if kind == "adaptation" and va is None:
        best = -1
        for d in vdirs:
            parsed = _parse_dir(d)
            if (
                parsed is not None
                and parsed.level == "adaptation"
                and parsed.master_version == vm
                and parsed.collection == collection
            ):
                best = max(best, parsed.adaptation_version)  # type: ignore[type-var]
        if best < 0:
            raise VintageNotFound(
                f"No {collection} adaptation found under {svyfld} for master "
                f"{format_vintage(vm)}."
            )
        va = best

    # ---- vintage folder + existence check ----
    if kind == "adaptation":
        vfolder = adaptation_folder(
            country, year, survey, vm, va, collection  # type: ignore[arg-type]
        )
    else:
        vfolder = master_folder(country, year, survey, vm)
    actual_vintage = _match_dir(survey_dir, vfolder)
    if actual_vintage is None:
        raise VintageNotFound(f"Vintage folder {vfolder} not found under {svyfld}.")
    base = survey_dir / actual_vintage

    return VintagePaths(
        root=rootp,
        country_dir=country_dir,
        survey_dir=survey_dir,
        vintage_dir=base,
        data=base / "Data",
        data_stata=base / "Data" / "Stata",
        data_original=base / "Data" / "Original",
        data_other=base / "Data" / "Other",
        data_r=base / "Data" / "R",
        doc=base / "Doc",
        programs=base / "Programs",
        stem=actual_vintage,
        country=country,
        year=year,
        survey=survey,
        kind=kind,
        collection=collection,
        master_version=vm,
        adaptation_version=va,
    )


# ---------------------------------------------------------------------------
# files / catalog / browse
# ---------------------------------------------------------------------------


def files(
    country: str,
    year: int | str | None = None,
    survey: str | None = None,
    *,
    section: str = "data",
    kind: str = "adaptation",
    collection: str | None = None,
    master_version: int | str | None = None,
    adaptation_version: int | str | None = None,
    pattern: str = "*",
    root: Path | str | None = None,
) -> list[Path]:
    """List the files inside one section of a resolved vintage.

    Canonical contract name: ``datalib_files``. Resolution follows
    resolve() (same normalization, defaults and errors); the chosen
    section directory is then listed non-recursively, with the glob
    ``pattern`` matched case-insensitively against file names.

    Parameters
    ----------
    country : str
        Country token, e.g. ``BRA``.
    year : int or str or None, optional
        Survey year; None picks the numerically latest.
    survey : str or None, optional
        Survey acronym; None picks the survey of the latest-year folder.
    section : str, optional
        Which vintage subfolder to list: "data" (Data/Stata, default),
        "data-original", "data-r", "data-other", "doc" or "programs".
    kind : str, optional
        "adaptation" (default) or "master".
    collection : str or None, optional
        Collection token for adaptations (default ``HLT``).
    master_version : int or str or None, optional
        Master vintage; None means latest on disk.
    adaptation_version : int or str or None, optional
        Adaptation vintage; None means latest of the collection.
    pattern : str, optional
        Case-insensitive fnmatch glob applied to file names (default "*").
    root : Path or str or None, optional
        Library root override; None follows the contract precedence chain.

    Returns
    -------
    list of Path
        Sorted full paths of the matching files; empty when the section
        folder is missing or nothing matches.

    Raises
    ------
    InvalidArgumentError
        If ``section`` is unknown or a resolve() input is malformed.
    CountryNotFound
        If the country folder does not exist under the root.
    SurveyNotFound
        If no survey folder matches the request.
    VintageNotFound
        If the requested (or defaulted) vintage folder is absent.
    DatalibRootNotSet
        If no library root can be resolved.
    """
    if section not in _SECTIONS:
        raise InvalidArgumentError(
            f"section must be one of: {', '.join(_SECTIONS)} (got {section!r})."
        )
    rp = resolve(
        country,
        year,
        survey,
        kind=kind,
        collection=collection,
        master_version=master_version,
        adaptation_version=adaptation_version,
        root=root,
    )
    base = rp.vintage_dir.joinpath(*_SECTIONS[section])
    try:
        with os.scandir(base) as it:
            names = [e.name for e in it if e.is_file()]
    except (FileNotFoundError, NotADirectoryError):
        return []
    pat = pattern.lower()
    return sorted(base / n for n in names if fnmatch.fnmatch(n.lower(), pat))


def catalog(root: Path | str | None = None) -> list[CatalogEntry]:
    """Catalog every vintage folder in the library.

    Canonical contract name: ``datalib_catalog``. Walks the three-level
    tree root/country/survey/vintage, keeping only names that parse under
    the folder grammar (masters and adaptations); everything else is
    silently skipped.

    Parameters
    ----------
    root : Path or str or None, optional
        Library root override; None follows the contract precedence chain.

    Returns
    -------
    list of CatalogEntry
        One entry per vintage folder, sorted by (country, year, survey,
        master, kind, collection, adaptation); empty for an empty library.

    Raises
    ------
    DatalibRootNotSet
        If no library root can be resolved.
    """
    rootp = resolve_root(root)
    out: list[CatalogEntry] = []
    for c in _scan_dirs(rootp):
        for s in _scan_dirs(rootp / c):
            svy = _parse_dir(s)
            if svy is None or svy.level != "survey":
                continue
            for v in _scan_dirs(rootp / c / s):
                parsed = _parse_dir(v)
                if parsed is None or parsed.level not in ("master", "adaptation"):
                    continue
                out.append(
                    CatalogEntry(
                        country=parsed.country,
                        year=parsed.year,  # type: ignore[arg-type]
                        survey=parsed.survey,  # type: ignore[arg-type]
                        kind=parsed.level,
                        collection=parsed.collection,
                        master_version=parsed.master_version,  # type: ignore[arg-type]
                        adaptation_version=parsed.adaptation_version,
                        vintage_folder=v,
                    )
                )
    return sorted(
        out,
        key=lambda e: (
            e.country,
            e.year,
            e.survey,
            e.master_version,
            e.kind,
            e.collection or "",
            e.adaptation_version or 0,
        ),
    )


def browse(
    token: str | None = None, *, root: Path | str | None = None
) -> Listing:
    """Navigate the library one level at a time, statelessly.

    Canonical contract name: ``datalib_browse``. Each returned Entry
    carries the token to feed to the next browse() call: no token lists
    the countries at the root; a country token lists its survey folders;
    a survey token lists its vintage folders; a vintage token lists its
    sections (Data/Doc/Programs), whose entries are leaves (token=None).

    Parameters
    ----------
    token : str or None, optional
        A 1/3/5/8-token folder name to descend into, or None/blank for
        the root listing.
    root : Path or str or None, optional
        Library root override; None follows the contract precedence chain.

    Returns
    -------
    Listing
        The listed path, its level, and its entries.

    Raises
    ------
    InvalidArgumentError
        If ``token`` is not a valid folder-grammar name.
    CountryNotFound
        If the country folder does not exist under the root.
    SurveyNotFound
        If the survey folder named by ``token`` is absent.
    VintageNotFound
        If the vintage folder named by ``token`` is absent.
    DatalibRootNotSet
        If no library root can be resolved.
    """
    rootp = resolve_root(root)

    if token is None or not str(token).strip():
        entries = tuple(
            Entry(name=d, kind="country", token=d) for d in sorted(_scan_dirs(rootp))
        )
        return Listing(path=rootp, level="root", entries=entries)

    parsed = parse_name(str(token))

    if parsed.level == "country":
        actual = _match_dir(rootp, parsed.country)
        if actual is None:
            raise CountryNotFound(
                f"Country {parsed.country} not found in datalib ({rootp})."
            )
        path = rootp / actual
        entries = tuple(
            Entry(name=d, kind="survey", token=d) for d in sorted(_scan_dirs(path))
        )
        return Listing(path=path, level="country", entries=entries)

    hit = _survey_dir(rootp, parsed.country, parsed.year, parsed.survey)  # type: ignore[arg-type]
    if hit is None:
        raise SurveyNotFound(f"Survey folder {token} not found.")
    svy_dir, _ = hit

    if parsed.level == "survey":
        entries = []
        for d in sorted(_scan_dirs(svy_dir)):
            sub = _parse_dir(d)
            if sub is not None and sub.level in ("master", "adaptation"):
                kind = sub.level
            else:
                kind = "survey"
            entries.append(Entry(name=d, kind=kind, token=d))
        return Listing(path=svy_dir, level="survey", entries=tuple(entries))

    # master / adaptation vintage folder -> sections
    actual = _match_dir(svy_dir, str(token).strip())
    if actual is None:
        raise VintageNotFound(f"Vintage folder {token} not found.")
    path = svy_dir / actual
    entries = tuple(
        Entry(name=d, kind="section", token=None) for d in sorted(_scan_dirs(path))
    )
    return Listing(path=path, level=parsed.level, entries=entries)
