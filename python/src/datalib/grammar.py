"""Folder-name grammar (contract v1, config/grammar.md).

The single parser/formatter for the 1/3/5/8-token folder names::

    <CCC>                                             1 token   country
    <CCC>_<YYYY>_<SSSS>                               3 tokens  survey folder
    <CCC>_<YYYY>_<SSSS>_v<MM>_M                       5 tokens  master vintage
    <CCC>_<YYYY>_<SSSS>_v<MM>_M_v<AA>_A_<HHHH>        8 tokens  adaptation vintage

Token positions when splitting on "_" (1-based): 1 country, 2 year, 3 survey,
4 master vintage, 6 adaptation vintage, 8 collection.

Vintages are integers everywhere in the API; the display form is ``v%02d``
("latest" is the numeric maximum, never alphabetical order).
"""

from __future__ import annotations

from dataclasses import dataclass

from .errors import InvalidArgumentError

__all__ = [
    "ParsedName",
    "parse_vintage",
    "format_vintage",
    "parse_year",
    "survey_folder",
    "master_folder",
    "adaptation_folder",
    "parse_name",
]


@dataclass(frozen=True)
class ParsedName:
    """A parsed 1/3/5/8-token folder name.

    Returned by parse_name(). Fields beyond the parsed level are None
    (e.g. a "survey"-level name has no master_version).

    Attributes
    ----------
    level : str
        Depth of the name: "country", "survey", "master" or "adaptation".
    country : str
        Country token, uppercased.
    year : int or None
        Survey year (token 2); None for country-level names.
    survey : str or None
        Survey acronym token, uppercased; None for country-level names.
    master_version : int or None
        Master vintage as an integer (token 4, ``v<MM>``).
    adaptation_version : int or None
        Adaptation vintage as an integer (token 6, ``v<AA>``).
    collection : str or None
        Collection token (token 8), uppercased; adaptation level only.
    """

    level: str  # "country" | "survey" | "master" | "adaptation"
    country: str
    year: int | None = None
    survey: str | None = None
    master_version: int | None = None
    adaptation_version: int | None = None
    collection: str | None = None


def parse_vintage(value: int | str) -> int:
    """Normalize a vintage spelled ``1``, ``01``, ``v01`` or ``V01`` to an int.

    Vintages are integers everywhere in the API (contract semantics 2);
    this is the single input normalizer.

    Parameters
    ----------
    value : int or str
        Vintage as an int or a string with an optional leading ``v``/``V``.

    Returns
    -------
    int
        The vintage number (>= 1).

    Raises
    ------
    InvalidArgumentError
        If ``value`` is not a positive integer in an accepted spelling.
    """
    if isinstance(value, bool):
        raise InvalidArgumentError("vintage must be a number such as 01 or v01.")
    if isinstance(value, int):
        n = value
    elif isinstance(value, str):
        raw = value.strip().lower()
        if raw.startswith("v"):
            raw = raw[1:]
        if not raw.isdigit():
            raise InvalidArgumentError(
                f"vintage must be a number such as 01 or v01 (got {value!r})."
            )
        n = int(raw)
    else:
        raise InvalidArgumentError(
            f"vintage must be a number such as 01 or v01 (got {value!r})."
        )
    if n < 1:
        raise InvalidArgumentError(f"vintage must be a positive number (got {value!r}).")
    return n


def format_vintage(n: int) -> str:
    """Format an integer vintage in the canonical ``v%02d`` form.

    Parameters
    ----------
    n : int
        Vintage number (>= 1).

    Returns
    -------
    str
        The display form, e.g. ``v01`` for 1, ``v10`` for 10.

    Raises
    ------
    InvalidArgumentError
        If ``n`` is not a positive integer (bools are rejected).
    """
    if not isinstance(n, int) or isinstance(n, bool) or n < 1:
        raise InvalidArgumentError(f"vintage must be a positive integer (got {n!r}).")
    return f"v{n:02d}"


def parse_year(value: int | str) -> int:
    """Coerce a year given as int or numeric string.

    Parameters
    ----------
    value : int or str
        The survey year, e.g. ``2019`` or ``"2019"``.

    Returns
    -------
    int
        The year as an integer.

    Raises
    ------
    InvalidArgumentError
        If ``value`` is neither an int nor a digits-only string.
    """
    if isinstance(value, bool):
        raise InvalidArgumentError(f"year must be an integer (got {value!r}).")
    if isinstance(value, int):
        return value
    if isinstance(value, str) and value.strip().isdigit():
        return int(value.strip())
    raise InvalidArgumentError(f"year must be an integer (got {value!r}).")


def survey_folder(country: str, year: int, survey: str) -> str:
    """Format the 3-token survey folder name ``<CCC>_<YYYY>_<SSSS>``.

    Pure string formatting; inputs are joined as given (callers uppercase
    at the boundary per contract semantics 1).

    Parameters
    ----------
    country : str
        Country token (``<CCC>``).
    year : int
        Survey year (``<YYYY>``).
    survey : str
        Survey acronym token (``<SSSS>``).

    Returns
    -------
    str
        The survey folder name.
    """
    return f"{country}_{year}_{survey}"


def master_folder(country: str, year: int, survey: str, master_version: int) -> str:
    """Format the 5-token master vintage folder name ``<CCC>_<YYYY>_<SSSS>_v<MM>_M``.

    Parameters
    ----------
    country : str
        Country token (``<CCC>``).
    year : int
        Survey year (``<YYYY>``).
    survey : str
        Survey acronym token (``<SSSS>``).
    master_version : int
        Master vintage number, rendered as ``v%02d``.

    Returns
    -------
    str
        The master vintage folder name.

    Raises
    ------
    InvalidArgumentError
        If ``master_version`` is not a positive integer.
    """
    return f"{survey_folder(country, year, survey)}_{format_vintage(master_version)}_M"


def adaptation_folder(
    country: str,
    year: int,
    survey: str,
    master_version: int,
    adaptation_version: int,
    collection: str,
) -> str:
    """Format the 8-token adaptation folder name ``<CCC>_<YYYY>_<SSSS>_v<MM>_M_v<AA>_A_<HHHH>``.

    Parameters
    ----------
    country : str
        Country token (``<CCC>``).
    year : int
        Survey year (``<YYYY>``).
    survey : str
        Survey acronym token (``<SSSS>``).
    master_version : int
        Master vintage number, rendered as ``v%02d``.
    adaptation_version : int
        Adaptation vintage number, rendered as ``v%02d``.
    collection : str
        Collection token (``<HHHH>``), e.g. ``HLT``.

    Returns
    -------
    str
        The adaptation vintage folder name.

    Raises
    ------
    InvalidArgumentError
        If either vintage is not a positive integer.
    """
    return (
        f"{master_folder(country, year, survey, master_version)}"
        f"_{format_vintage(adaptation_version)}_A_{collection}"
    )


def _try_vintage(token: str) -> int | None:
    """Parse a ``v<NN>`` token to an int, or None when it is not one."""
    token = token.strip().lower()
    if token.startswith("v") and token[1:].isdigit():
        return int(token[1:])
    return None


def parse_name(name: str) -> ParsedName:
    """Parse a 1/3/5/8-token folder name into its grammar components.

    Splits on ``_`` and classifies the name as country (1 token), survey
    (3 tokens), master vintage (5 tokens, ``..._v<MM>_M``) or adaptation
    vintage (8 tokens, ``..._v<MM>_M_v<AA>_A_<HHHH>``). Country, survey
    and collection tokens are uppercased; vintages become integers.

    Parameters
    ----------
    name : str
        A folder name in the contract grammar (not a path).

    Returns
    -------
    ParsedName
        The parsed components, with ``level`` naming the depth.

    Raises
    ------
    InvalidArgumentError
        If ``name`` does not match any of the four grammar shapes.
    """
    if not isinstance(name, str) or not name.strip():
        raise InvalidArgumentError(f"not a datalib folder name: {name!r}.")
    tokens = name.strip().split("_")
    if len(tokens) == 1:
        return ParsedName(level="country", country=tokens[0].upper())
    if len(tokens) >= 3:
        country = tokens[0].upper()
        survey = tokens[2].upper()
        if not tokens[1].isdigit():
            raise InvalidArgumentError(f"not a datalib folder name: {name!r} (bad year).")
        year = int(tokens[1])
        if len(tokens) == 3:
            return ParsedName(level="survey", country=country, year=year, survey=survey)
        if len(tokens) == 5 and tokens[4].upper() == "M":
            vm = _try_vintage(tokens[3])
            if vm is not None:
                return ParsedName(
                    level="master",
                    country=country,
                    year=year,
                    survey=survey,
                    master_version=vm,
                )
        if len(tokens) == 8 and tokens[4].upper() == "M" and tokens[6].upper() == "A":
            vm = _try_vintage(tokens[3])
            va = _try_vintage(tokens[5])
            if vm is not None and va is not None:
                return ParsedName(
                    level="adaptation",
                    country=country,
                    year=year,
                    survey=survey,
                    master_version=vm,
                    adaptation_version=va,
                    collection=tokens[7].upper(),
                )
    raise InvalidArgumentError(f"not a datalib folder name: {name!r}.")
