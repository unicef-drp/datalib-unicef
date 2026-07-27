"""create(): report (dry run, the default) or create a new vintage tree.

Dry-run mode is pure: it computes the target paths and touches nothing
(contract v1 fixes the old Stata ``_mkdir`` check-mode side effect).

Version defaults follow the latest+1 increment rule: an omitted
``master_version`` (kind='master') or ``adaptation_version`` becomes the
numerically latest on disk plus one (1 when none exists). An adaptation's
omitted ``master_version`` defaults to the latest existing master, which must
exist.
"""

from __future__ import annotations

from pathlib import Path

from .catalog import VintagePaths, _match_dir, _norm_upper, _parse_dir, _scan_dirs
from .config import resolve_root
from .errors import InvalidArgumentError, VintageNotFound
from .grammar import (
    adaptation_folder,
    master_folder,
    parse_vintage,
    parse_year,
    survey_folder,
)

__all__ = ["create"]

_TREE = (
    ("Data", "Original"),
    ("Data", "Stata"),
    ("Data", "R"),
    ("Data", "Other"),
    ("Doc",),
    ("Programs",),
)


def create(
    country: str,
    year: int | str,
    survey: str,
    *,
    kind: str = "adaptation",
    collection: str | None = None,
    master_version: int | str | None = None,
    adaptation_version: int | str | None = None,
    overwrite: bool = False,
    dry_run: bool = True,
    root: Path | str | None = None,
) -> VintagePaths:
    """Compute (and with ``dry_run=False`` create) a new vintage folder tree.

    Canonical contract name: ``datalib_create``. Dry-run mode (the
    default) is pure: it computes the target paths and touches nothing.
    Omitted versions follow the latest+1 increment rule: a new master (or
    adaptation) becomes the numerically latest on disk plus one, 1 when
    none exists; an adaptation's omitted ``master_version`` defaults to
    the latest existing master, which must exist. With ``dry_run=False``
    the standard tree Data/{Original,Stata,R,Other}, Doc/ and Programs/
    is created (parents included, existing directories kept).

    Parameters
    ----------
    country : str
        Country token, e.g. ``BRA``. Required.
    year : int or str
        Survey year, e.g. ``2019``. Required.
    survey : str
        Survey acronym, e.g. ``MICS``. Required.
    kind : str, optional
        "adaptation" (default) or "master".
    collection : str or None, optional
        Collection token for adaptations (default ``HLT``); must be None
        for kind="master".
    master_version : int or str or None, optional
        Master vintage; None means latest+1 for kind="master", or the
        latest existing master for adaptations.
    adaptation_version : int or str or None, optional
        Adaptation vintage; None means latest+1 for the collection under
        the chosen master.
    overwrite : bool, optional
        Allow reusing an existing vintage folder (default False).
    dry_run : bool, optional
        Report only, create nothing (default True).
    root : Path or str or None, optional
        Library root override; None follows the contract precedence chain.

    Returns
    -------
    VintagePaths
        Identity fields plus every standard path of the (planned) vintage.

    Raises
    ------
    InvalidArgumentError
        If an input is malformed, ``collection`` is combined with
        kind="master", or the target folder exists without ``overwrite``.
    VintageNotFound
        If an adaptation is requested but no master vintage exists to
        attach it to.
    DatalibRootNotSet
        If no library root can be resolved.
    """
    rootp = resolve_root(root)

    country = _norm_upper(country, "country")
    survey = _norm_upper(survey, "survey")
    year = parse_year(year)
    kind = (kind or "adaptation").strip().lower()
    if kind not in ("master", "adaptation"):
        raise InvalidArgumentError("kind must be 'master' or 'adaptation'.")
    collection = (
        _norm_upper(collection, "collection") if collection not in (None, "") else None
    )
    if kind == "adaptation" and collection is None:
        collection = "HLT"
    if kind == "master" and collection is not None:
        raise InvalidArgumentError("collection applies only to kind='adaptation'.")

    vm = None if master_version in (None, "") else parse_vintage(master_version)
    va = None if adaptation_version in (None, "") else parse_vintage(adaptation_version)

    # existing tree (all optional at create time)
    actual_country = _match_dir(rootp, country) or country
    country_dir = rootp / actual_country
    svyfld = survey_folder(country, year, survey)
    actual_svy = _match_dir(country_dir, svyfld) or svyfld
    survey_dir = country_dir / actual_svy

    masters: list[int] = []
    adapts: dict[int, list[int]] = {}
    for d in _scan_dirs(survey_dir):
        parsed = _parse_dir(d)
        if parsed is None:
            continue
        if parsed.level == "master":
            masters.append(parsed.master_version)  # type: ignore[arg-type]
        elif parsed.level == "adaptation" and parsed.collection == collection:
            adapts.setdefault(parsed.master_version, []).append(  # type: ignore[arg-type]
                parsed.adaptation_version  # type: ignore[arg-type]
            )

    if kind == "master":
        if vm is None:
            vm = (max(masters) + 1) if masters else 1
        vfolder = master_folder(country, year, survey, vm)
    else:
        if vm is None:
            if not masters:
                raise VintageNotFound(
                    f"No master vintage found under {svyfld} to attach the "
                    f"{collection} adaptation to."
                )
            vm = max(masters)
        if va is None:
            existing = adapts.get(vm, [])
            va = (max(existing) + 1) if existing else 1
        vfolder = adaptation_folder(
            country, year, survey, vm, va, collection  # type: ignore[arg-type]
        )

    existing_vintage = _match_dir(survey_dir, vfolder)
    if existing_vintage is not None and not overwrite:
        raise InvalidArgumentError(
            f"Vintage folder {vfolder} already exists under {svyfld} "
            "(pass overwrite=True to reuse it)."
        )

    base = survey_dir / (existing_vintage or vfolder)
    paths = VintagePaths(
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
        stem=existing_vintage or vfolder,
        country=country,
        year=year,
        survey=survey,
        kind=kind,
        collection=collection,
        master_version=vm,
        adaptation_version=va,
    )

    if not dry_run:
        for parts in _TREE:
            base.joinpath(*parts).mkdir(parents=True, exist_ok=True)

    return paths
