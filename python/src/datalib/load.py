"""load(): read module files from a resolved vintage and merge them.

Contract merge semantics (config/grammar.md sections 4-5):

* A person module whose registry ``linevar`` != ``line_number`` has that
  variable renamed to ``line_number`` on load (the single documented
  normalization; values are never mutated).
* Person-level modules chain 1:1 (outer) on ``keys_person``; hh-level modules
  attach m:1 (outer, keeping unmatched hh rows) on ``keys_hh`` — 1:1 on
  ``keys_hh`` when only hh modules are loaded.
* Keys are validated per module (isid-equivalent: present, never missing,
  unique); failure raises a typed error naming the module.
* ``merge=False`` returns a dict of module name -> DataFrame.
* ``ctrycode`` and ``year`` provenance columns are added (post-merge, or per
  frame when merge=False), only when absent.
"""

from __future__ import annotations

from collections.abc import Sequence
from copy import deepcopy
from pathlib import Path

import pandas as pd

from .catalog import VintagePaths, resolve
from .errors import FileNotFoundInLibrary, InvalidArgumentError
from .io import read_dta
from .registry import Collection, collections

__all__ = ["load"]

_INDICATOR = "__datalib_merge__"


def _validate_keys(name: str, df: pd.DataFrame, keys: Sequence[str]) -> None:
    """isid-equivalent: keys exist, are never missing, and identify rows."""
    missing_cols = [k for k in keys if k not in df.columns]
    if missing_cols:
        raise InvalidArgumentError(
            f"Cannot merge: module {name!r} lacks key column(s) "
            f"{', '.join(missing_cols)} (keys: {', '.join(keys)}). "
            "Drop that module from modules or use merge=False."
        )
    sub = df[list(keys)]
    if sub.isna().any().any() or sub.duplicated().any():
        raise InvalidArgumentError(
            f"Cannot merge: keys ({', '.join(keys)}) do not uniquely identify "
            f"rows of module {name!r} (missing or duplicated identifiers in "
            "the data). Drop that module from modules or use merge=False."
        )


def _stata_merge(
    left: pd.DataFrame, right: pd.DataFrame, keys: Sequence[str]
) -> pd.DataFrame:
    """Outer merge with Stata semantics for overlapping non-key columns:
    the master (left) values win; rows only in using (right) take its values.
    """
    keys = list(keys)
    overlap = [c for c in left.columns if c in right.columns and c not in keys]
    merged = left.merge(
        right,
        on=keys,
        how="outer",
        suffixes=("", "__using"),
        indicator=_INDICATOR,
    )
    right_only = merged[_INDICATOR] == "right_only"
    for col in overlap:
        using = f"{col}__using"
        merged[col] = merged[col].where(~right_only, merged[using])
        merged = merged.drop(columns=[using])
    return merged.drop(columns=[_INDICATOR])


def _add_provenance(df: pd.DataFrame, country: str, year: int) -> pd.DataFrame:
    """Add ctrycode/year provenance columns in place, only when absent."""
    if "ctrycode" not in df.columns:
        df["ctrycode"] = country
    if "year" not in df.columns:
        df["year"] = year
    return df


def _module_paths(
    rp: VintagePaths, modules: Sequence[str]
) -> list[tuple[str, Path]]:
    """(module, path) pairs under Data/Stata; typed error if a file is missing."""
    out: list[tuple[str, Path]] = []
    for module in modules:
        path = rp.data_stata / f"{rp.stem}_{module}.dta"
        if not path.is_file():
            raise FileNotFoundInLibrary(
                f"Module file not found: {path.name} (in {rp.data_stata})."
            )
        out.append((module, path))
    return out


def load(
    country: str,
    year: int | str | None = None,
    survey: str | None = None,
    *,
    modules: Sequence[str] | None = None,
    collection: str | None = None,
    kind: str = "adaptation",
    master_version: int | str | None = None,
    adaptation_version: int | str | None = None,
    merge: bool = True,
    columns: Sequence[str] | None = None,
    convert_categoricals: bool = False,
    engine: str = "pandas",
    root: Path | str | None = None,
) -> pd.DataFrame | dict[str, pd.DataFrame]:
    """Load (and by default merge) module files from a resolved vintage.

    Canonical contract name: ``datalib_load``. Resolution follows
    resolve() (same normalization, latest-vintage defaults and typed
    errors). Loaders never mutate values (contract semantics 4): the
    single documented normalization is renaming a person module's
    registry ``linevar`` to ``line_number`` when they differ. Merging
    follows contract semantics 5: person modules chain 1:1 on
    ``keys_person``; hh modules attach m:1 on ``keys_hh`` (1:1 when only
    hh modules are loaded); keys are validated per module
    (isid-equivalent); unmatched rows are kept (outer join) and the merge
    indicator is not retained. ``ctrycode``/``year`` provenance columns
    are added only when absent, and provenance metadata is attached under
    ``df.attrs["datalib"]``.

    Parameters
    ----------
    country : str
        Country token, e.g. ``BRA``.
    year : int or str or None, optional
        Survey year; None picks the numerically latest.
    survey : str or None, optional
        Survey acronym; None picks the survey of the latest-year folder.
    modules : sequence of str or None, optional
        Module names to load (lowercased/trimmed; validated against the
        collection registry when one applies). None loads every module of
        the collection; required for master vintages.
    collection : str or None, optional
        Collection token for adaptations (default ``HLT``).
    kind : str, optional
        "adaptation" (default) or "master".
    master_version : int or str or None, optional
        Master vintage; None means latest on disk.
    adaptation_version : int or str or None, optional
        Adaptation vintage; None means latest of the collection.
    merge : bool, optional
        Merge the modules into one DataFrame (default True); False
        returns a dict of module name -> DataFrame.
    columns : sequence of str or None, optional
        Column subset passed to the .dta reader; None reads everything.
    convert_categoricals : bool, optional
        Apply value labels as pandas categoricals (default False, so
        numeric codes survive; labels are carried in metadata instead).
    engine : str, optional
        .dta reader: "pandas" (default), "pyreadstat" or "auto".
    root : Path or str or None, optional
        Library root override; None follows the contract precedence chain.

    Returns
    -------
    pandas.DataFrame or dict of str to pandas.DataFrame
        The merged frame, or ``{module: DataFrame}`` when ``merge=False``.

    Raises
    ------
    InvalidArgumentError
        If an input is malformed, a module is unknown to the collection,
        modules are omitted for a master vintage, merge keys are missing/
        non-unique, or merge keys are unknown for the selection.
    CountryNotFound
        If the country folder does not exist under the root.
    SurveyNotFound
        If no survey folder matches the request.
    VintageNotFound
        If the requested (or defaulted) vintage folder is absent.
    FileNotFoundInLibrary
        If a requested module file is missing under Data/Stata/.
    DatalibRootNotSet
        If no library root can be resolved.
    """
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

    # ---- registry lookup (adaptations of known collections only) ----
    coll: Collection | None = None
    if rp.kind == "adaptation":
        coll = collections().get(rp.collection or "")

    # ---- module list ----
    if modules is None:
        if coll is None:
            raise InvalidArgumentError(
                "modules must be specified for master vintages (no collection "
                "registry applies)."
            )
        module_list = list(coll.module_names)
    else:
        module_list = [str(m).strip().lower() for m in modules if str(m).strip()]
        if not module_list:
            raise InvalidArgumentError("modules must not be empty.")
        if coll is not None:
            for m in module_list:
                coll.module(m)  # exact registry match; raises if unknown

    # ---- load each module ----
    frames: dict[str, pd.DataFrame] = {}
    for module, path in _module_paths(rp, module_list):
        df, _meta = read_dta(
            path,
            columns=columns,
            convert_categoricals=convert_categoricals,
            engine=engine,
        )
        if coll is not None:
            spec = coll.module(module)
            if (
                spec.level == "person"
                and spec.linevar != "line_number"
                and spec.linevar in df.columns
            ):
                df = df.rename(columns={spec.linevar: "line_number"})
        frames[module] = df

    provenance = {
        "stem": rp.stem,
        "vintage_dir": str(rp.vintage_dir),
        "files": [f"{rp.stem}_{m}.dta" for m in module_list],
        "engine": engine,
        "country": rp.country,
        "year": rp.year,
        "kind": rp.kind,
        "collection": rp.collection,
        "master_version": rp.master_version,
        "adaptation_version": rp.adaptation_version,
    }

    if not merge:
        for module, df in frames.items():
            _add_provenance(df, rp.country, rp.year)
            df.attrs["datalib"] = deepcopy(provenance)
        return frames

    if len(frames) == 1:
        df = next(iter(frames.values()))
        _add_provenance(df, rp.country, rp.year)
        df.attrs["datalib"] = provenance
        return df

    # ---- multi-module merge: keys required and validated per module ----
    if coll is None:
        raise InvalidArgumentError(
            "Cannot merge: module merge keys unknown for this selection. "
            "Use merge=False."
        )
    person = [m for m in module_list if coll.module(m).level == "person"]
    hh = [m for m in module_list if coll.module(m).level == "hh"]
    for module in module_list:
        keys = coll.keys_hh if coll.module(module).level == "hh" else coll.keys_person
        _validate_keys(module, frames[module], keys)

    ordered = person + hh
    merged = frames[ordered[0]]

    # chain the remaining person-level modules 1:1 on the person keys
    for module in person[1:]:
        merged = _stata_merge(merged, frames[module], coll.keys_person)

    # attach hh-level modules (m:1 when person modules present, else 1:1)
    for module in hh:
        if module == ordered[0]:
            continue
        merged = _stata_merge(merged, frames[module], coll.keys_hh)

    _add_provenance(merged, rp.country, rp.year)
    merged.attrs["datalib"] = provenance
    return merged
