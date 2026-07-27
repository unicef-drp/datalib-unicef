"""Typed error taxonomy for datalib (contract v1, config/grammar.md section 6).

Mapping to the language-neutral contract:
    invalid input                        -> InvalidArgumentError   (Stata 198)
    not found (country/survey/vintage/f) -> NotFoundError          (Stata 198/601)
    config file missing                  -> ConfigFileNotFound     (Stata 601)
    user block missing                   -> UserBlockNotFound      (Stata 459)
    library root unset                   -> DatalibRootNotSet      (Stata 198)
"""

from __future__ import annotations

__all__ = [
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
]


class DatalibError(Exception):
    """Base class for all datalib errors.

    Every typed error raised by this package derives from DatalibError,
    so callers can catch the whole taxonomy with a single except clause.
    Subclasses map 1:1 onto the contract error table in config/grammar.md.
    """


class InvalidArgumentError(DatalibError):
    """An argument is invalid or an operation is not supported.

    Contract error "invalid input" (Stata exit 198, R class
    ``datalib_error_input``). Raised for malformed vintages/years/names,
    unknown kinds/sections/engines/collections, and merge-key violations.
    """


class NotFoundError(DatalibError):
    """A requested library object does not exist on disk.

    Contract error "not found" (Stata exit 198/601, R class
    ``datalib_error_input``). Parent of the specific CountryNotFound,
    SurveyNotFound, VintageNotFound and FileNotFoundInLibrary errors.
    """


class CountryNotFound(NotFoundError):
    """The country folder does not exist under the library root.

    Raised by resolve() and browse() when the (uppercased, exact-matched)
    country token has no corresponding directory directly under the root.
    Enumerators return empty results instead of raising this error.
    """


class SurveyNotFound(NotFoundError):
    """No survey folder matches the request.

    Raised by resolve() and browse() when no ``<CCC>_<YYYY>_<SSSS>`` folder
    matches the requested country/year/survey (exact-suffix matching for
    survey, numerically latest year when year is omitted).
    """


class VintageNotFound(NotFoundError):
    """No master/adaptation vintage folder matches the request.

    Raised when the requested (or defaulted numeric-latest) master or
    adaptation vintage folder is absent under the survey folder, including
    when an adaptation has no master vintage to attach to.
    """


class FileNotFoundInLibrary(NotFoundError):
    """A data file expected inside a vintage folder is missing.

    Raised by load() when a requested module file
    ``<vintage-folder-name>_<module>.dta`` does not exist under Data/Stata/,
    and by read_dta() for a missing .dta path.
    """


class ConfigFileNotFound(DatalibError):
    """The user configuration file is missing.

    Contract error "config file missing" (Stata exit 601, R class
    ``datalib_error_config_missing``). Raised by getuserconfig() when
    ~/.config/user_config.yml (or the explicit ``config`` path) is absent.
    """


class UserBlockNotFound(DatalibError):
    """The config file has no block for the requested user.

    Contract error "user block missing" (Stata exit 459, R class
    ``datalib_error_user_missing``). Raised by getuserconfig() when the
    two-level YAML map has no entry keyed by the (login) user name.
    """


class DatalibRootNotSet(DatalibError):
    """No library root could be resolved.

    Contract error "library root unset" (Stata exit 198, R class
    ``datalib_error_input``). Raised after the full precedence chain fails:
    no ``root=`` argument, no DATALIB_ROOT environment variable, and no
    ``datalib:`` key in the user block of ~/.config/user_config.yml.
    """


class DriveMappingError(DatalibError):
    """Mapping a network drive failed or conflicts with an existing mapping.

    Raised by mapzdrive() when ``net use`` exits non-zero, or when the
    target letter is already mapped to a different UNC path and
    ``force=True`` was not passed.
    """


class UnsupportedPlatformError(DatalibError):
    """The operation is only available on Windows.

    Raised by mapzdrive() on any non-win32 platform: drive-letter mapping
    via ``net use`` has no meaning elsewhere, and the contract keeps the
    failure typed rather than letting a subprocess error leak through.
    """
