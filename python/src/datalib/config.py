"""User configuration (~/.config/user_config.yml) and library-root resolution.

The config file is a two-level YAML map: ``<username>: {key: value}`` with the
keys githubFolder, teamsRoot, zDrive (default "Z:/"), zDriveUNC and an optional
``datalib`` key naming the library root (contract v1).

Root resolution precedence (config/grammar.md section 7):
    explicit ``root=`` argument -> ``DATALIB_ROOT`` environment variable ->
    ``datalib:`` key in the user block of user_config.yml -> DatalibRootNotSet.
"""

from __future__ import annotations

import getpass
import os
from dataclasses import dataclass
from pathlib import Path

import yaml

from .errors import ConfigFileNotFound, DatalibRootNotSet, UserBlockNotFound

__all__ = ["UserConfig", "RootResolution", "getuserconfig", "resolve_root"]


@dataclass(frozen=True)
class UserConfig:
    """One user's block from user_config.yml.

    The camelCase field names mirror the YAML keys verbatim for R/Stata
    parity; they are not renamed to snake_case.

    Attributes
    ----------
    user : str
        The user name whose block was read.
    config_path : Path
        The config file the block came from.
    githubFolder : str or None
        Local GitHub working folder, if configured.
    teamsRoot : str or None
        Teams (SharePoint-synced) root folder, if configured.
    zDrive : str
        Team drive letter/root; defaults to ``Z:/`` when absent.
    zDriveUNC : str or None
        UNC path behind the team drive, if configured.
    datalib : str or None
        Optional library root (contract root-resolution step 3).
    """

    user: str
    config_path: Path
    githubFolder: str | None
    teamsRoot: str | None
    zDrive: str
    zDriveUNC: str | None
    datalib: str | None


def _config_dir() -> Path:
    """The directory searched for config files.

    ``DATALIB_CONFIG_DIR`` overrides it (fallback preserved); otherwise
    ``~/.config`` under ``USERPROFILE`` on Windows / ``HOME`` elsewhere.
    """
    override = os.environ.get("DATALIB_CONFIG_DIR", "").strip()
    if override:
        return Path(override)
    if os.name == "nt":
        home = os.environ.get("USERPROFILE", "") or str(Path.home())
    else:
        home = os.environ.get("HOME", "") or str(Path.home())
    return Path(home) / ".config"


def _default_config_path() -> Path:
    """The default (generic) config location: ``<config dir>/user_config.yml``."""
    return _config_dir() / "user_config.yml"


def _config_file_list(config: Path | str | None) -> list[Path]:
    """The ordered config files to consult for the ``datalib:`` key.

    An explicit ``config`` (or the ``DATALIB_CONFIG`` env var) pins a single
    file and disables the fallback; otherwise the two-file list
    (``user_config.yml`` then ``datalib_config.yml``) is searched in the
    config directory.
    """
    if config is not None and str(config).strip():
        return [Path(config)]
    env_file = os.environ.get("DATALIB_CONFIG", "").strip()
    if env_file:
        return [Path(env_file)]
    d = _config_dir()
    return [d / "user_config.yml", d / "datalib_config.yml"]


@dataclass(frozen=True)
class RootResolution:
    """The resolved library root plus where it came from.

    ``source_stage`` is one of ``argument``, ``env``, ``config_generic``,
    ``config_package`` -- byte-identical to the R and Stata implementations
    (Python has no ``option`` stage). ``source_file`` is the config file when
    the root came from a file, else ``""``.
    """

    root: Path
    source_stage: str
    source_file: str


def getuserconfig(
    user: str | None = None, config: Path | str | None = None
) -> UserConfig:
    """Load one user's block from ~/.config/user_config.yml (or ``config``).

    Canonical contract name: ``datalib_config`` (``getuserconfig`` is the
    verbatim cross-language alias kept from Stata). The file is a two-level
    YAML map ``<username>: {key: value}``; only the requested user's block
    is read, with ``zDrive`` defaulting to ``Z:/``.

    Parameters
    ----------
    user : str or None, optional
        User name keying the block; defaults to the current login user.
    config : Path or str or None, optional
        Path of the YAML file; defaults to ``~/.config/user_config.yml``.

    Returns
    -------
    UserConfig
        The user's configuration block with all keys coerced to str.

    Raises
    ------
    ConfigFileNotFound
        If the config file does not exist at the resolved path.
    UserBlockNotFound
        If the file has no mapping entry for ``user``.
    """
    if user is None or not str(user).strip():
        user = getpass.getuser()
    path = _default_config_path() if config is None else Path(config)

    if not path.is_file():
        raise ConfigFileNotFound(
            f"Configuration file not found at expected path: {path}. "
            "Please create or move your 'user_config.yml' to this location "
            "(a template lives in the repo under config/user_config.yml)."
        )

    with open(path, "r", encoding="utf-8") as fh:
        data = yaml.safe_load(fh)

    block = data.get(user) if isinstance(data, dict) else None
    if not isinstance(block, dict):
        raise UserBlockNotFound(
            f"Configuration file found at: {path}, but it has no entry for "
            f"user '{user}'."
        )

    def _get(key: str) -> str | None:
        value = block.get(key)
        return None if value is None else str(value)

    return UserConfig(
        user=user,
        config_path=path,
        githubFolder=_get("githubFolder"),
        teamsRoot=_get("teamsRoot"),
        zDrive=_get("zDrive") or "Z:/",
        zDriveUNC=_get("zDriveUNC"),
        datalib=_get("datalib"),
    )


def _resolve_config_root(
    user: str | None, config: Path | str | None
) -> RootResolution | None:
    """Search the config file list for the current user's ``datalib:`` key.

    Returns the resolution for the FIRST file whose user block carries a
    non-empty ``datalib:`` key (key-presence, block-level -- a missing key
    falls through to the next file, never merged), or ``None``.
    """
    for f in _config_file_list(config):
        if not f.is_file():
            continue
        try:
            cfg = getuserconfig(user=user, config=f)
        except (ConfigFileNotFound, UserBlockNotFound):
            continue
        if cfg.datalib and cfg.datalib.strip():
            stage = "config_generic" if f.name == "user_config.yml" else "config_package"
            return RootResolution(Path(cfg.datalib.strip()), stage, str(f))
    return None


def resolve_root(
    root: Path | str | None = None,
    *,
    user: str | None = None,
    config: Path | str | None = None,
    report: bool = False,
) -> Path | RootResolution:
    """Resolve the library root per the contract precedence chain.

    Canonical contract name: ``datalib_root``. Precedence (config/grammar.md
    section 7): explicit ``root`` argument, then the ``DATALIB_ROOT``
    environment variable, then the ``datalib:`` key in the current user's
    block of the config files -- ``~/.config/user_config.yml`` (shared with
    the CSO Toolkit) then ``~/.config/datalib_config.yml``. The first file
    whose user block carries a non-empty ``datalib:`` key wins (key-presence,
    block-level). A missing/blank step falls through to the next, and the path
    is **not** existence-checked -- a nonexistent root resolves successfully and
    fails later, when the library is read.

    The value is returned as a ``Path``, so its string form is not necessarily
    the spelling that was configured: on Windows ``Z:/a`` comes back as
    ``Z:\\a``. Stata returns the literal string and R normalises via
    ``fs::path_norm``, so the three languages agree on the resolved directory
    rather than on its bytes; the contract pins identity, not spelling.

    Test/isolation hooks: ``DATALIB_CONFIG`` pins exactly one file (fallback
    disabled); ``DATALIB_CONFIG_DIR`` searches the two-file list in a
    directory other than ``~/.config`` (fallback preserved).

    Parameters
    ----------
    root : Path or str or None, optional
        Explicit library root; wins over every other source when non-blank.
    user : str or None, optional
        User name for the config-block fallback; defaults to the login user.
    config : Path or str or None, optional
        A single config file; when given, pins that file and disables the
        two-file fallback.
    report : bool, optional
        When ``True``, return a :class:`RootResolution` (root + source_stage
        + source_file) instead of a bare ``Path``.

    Returns
    -------
    Path or RootResolution
        The resolved library root, or its :class:`RootResolution` when
        ``report=True``.

    Raises
    ------
    DatalibRootNotSet
        If every step of the precedence chain comes up empty.
    """

    def _out(res: RootResolution) -> Path | RootResolution:
        return res if report else res.root

    if root is not None and str(root).strip():
        return _out(RootResolution(Path(root), "argument", ""))

    env = os.environ.get("DATALIB_ROOT", "").strip()
    if env:
        return _out(RootResolution(Path(env), "env", ""))

    res = _resolve_config_root(user, config)
    if res is not None:
        return _out(res)

    raise DatalibRootNotSet(
        "datalib root not set: pass root=, set the DATALIB_ROOT environment "
        "variable, or add a 'datalib:' key to your user block in "
        "~/.config/user_config.yml (or ~/.config/datalib_config.yml)."
    )
