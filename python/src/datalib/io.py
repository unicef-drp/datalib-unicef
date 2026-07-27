""".dta reading engine abstraction.

Default engine is ``pandas`` (pandas.read_stata, already present in approved
interpreters); ``pyreadstat`` is available as the optional ``[fidelity]``
extra (better label/tagged-missing fidelity, but a C extension). ``auto``
prefers pyreadstat when importable and falls back to pandas.

Contract: loaders never mutate values — ``convert_categoricals`` defaults to
False so numeric codes survive; labels are carried in DtaMeta.
"""

from __future__ import annotations

from collections.abc import Mapping, Sequence
from dataclasses import dataclass, field
from pathlib import Path

import pandas as pd

from .errors import FileNotFoundInLibrary, InvalidArgumentError

__all__ = ["DtaMeta", "read_dta"]

_ENGINES = ("pandas", "pyreadstat", "auto")


@dataclass(frozen=True)
class DtaMeta:
    """Best-effort metadata read alongside a .dta file.

    Labels are carried here rather than applied to the data (loaders
    never mutate values); fidelity depends on the engine used.

    Attributes
    ----------
    path : Path
        The .dta file the metadata came from.
    engine : str
        The engine that actually read the file: "pandas" or "pyreadstat".
    variable_labels : mapping of str to str
        Variable name -> variable label (empty when unavailable).
    value_labels : mapping of str to mapping
        Variable/label-set name -> {code: label} (empty when unavailable).
    """

    path: Path
    engine: str
    variable_labels: Mapping[str, str] = field(default_factory=dict)
    value_labels: Mapping[str, Mapping] = field(default_factory=dict)


def _read_pandas(
    path: Path,
    columns: Sequence[str] | None,
    convert_categoricals: bool,
) -> tuple[pd.DataFrame, DtaMeta]:
    """Read via pandas.read_stata; labels collected best-effort."""
    with pd.read_stata(
        path,
        convert_categoricals=convert_categoricals,
        columns=list(columns) if columns is not None else None,
        iterator=True,
    ) as reader:
        df = reader.read()
        try:
            variable_labels = dict(reader.variable_labels())
        except Exception:  # pragma: no cover - defensive
            variable_labels = {}
        try:
            value_labels = dict(reader.value_labels())
        except Exception:  # pragma: no cover - defensive
            value_labels = {}
    meta = DtaMeta(
        path=path,
        engine="pandas",
        variable_labels=variable_labels,
        value_labels=value_labels,
    )
    return df, meta


def _read_pyreadstat(
    path: Path,
    columns: Sequence[str] | None,
    convert_categoricals: bool,
) -> tuple[pd.DataFrame, DtaMeta]:
    """Read via pyreadstat; typed error when the extra is not installed."""
    try:
        import pyreadstat
    except ImportError as exc:
        raise InvalidArgumentError(
            "engine='pyreadstat' requested but pyreadstat is not installed "
            "(pip install unicef-datalib[fidelity])."
        ) from exc
    df, meta = pyreadstat.read_dta(
        str(path),
        usecols=list(columns) if columns is not None else None,
        apply_value_formats=convert_categoricals,
    )
    out = DtaMeta(
        path=path,
        engine="pyreadstat",
        variable_labels=dict(meta.column_names_to_labels or {}),
        value_labels=dict(meta.variable_value_labels or {}),
    )
    return df, out


def read_dta(
    path: Path | str,
    *,
    columns: Sequence[str] | None = None,
    convert_categoricals: bool = False,
    engine: str = "pandas",
) -> tuple[pd.DataFrame, DtaMeta]:
    """Read one .dta file, returning (DataFrame, DtaMeta).

    Values are never mutated: ``convert_categoricals`` defaults to False
    so numeric codes survive, with labels carried in the metadata. Engine
    "auto" prefers pyreadstat when importable and falls back to pandas.

    Parameters
    ----------
    path : Path or str
        Path of the .dta file to read.
    columns : sequence of str or None, optional
        Column subset to read; None reads everything.
    convert_categoricals : bool, optional
        Apply value labels as pandas categoricals (default False).
    engine : str, optional
        "pandas" (default), "pyreadstat" or "auto".

    Returns
    -------
    tuple of (pandas.DataFrame, DtaMeta)
        The data and the best-effort label metadata.

    Raises
    ------
    InvalidArgumentError
        If ``engine`` is unknown, or "pyreadstat" is requested but not
        installed.
    FileNotFoundInLibrary
        If ``path`` is not an existing file.
    """
    if engine not in _ENGINES:
        raise InvalidArgumentError(
            f"engine must be one of: {', '.join(_ENGINES)} (got {engine!r})."
        )
    p = Path(path)
    if not p.is_file():
        raise FileNotFoundInLibrary(f"File not found: {p}.")
    if engine == "auto":
        try:
            import pyreadstat  # noqa: F401
            engine = "pyreadstat"
        except ImportError:
            engine = "pandas"
    if engine == "pyreadstat":
        return _read_pyreadstat(p, columns, convert_categoricals)
    return _read_pandas(p, columns, convert_categoricals)
