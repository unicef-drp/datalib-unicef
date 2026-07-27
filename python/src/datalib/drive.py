"""mapzdrive: map the team network drive via ``net use`` (Windows only).

Failures raise DriveMappingError (typed) rather than returning a status
string; non-Windows platforms raise UnsupportedPlatformError. No shell is
ever involved (argument lists only).
"""

from __future__ import annotations

import subprocess
import sys
from dataclasses import dataclass
from enum import Enum
from pathlib import Path

from .config import getuserconfig
from .errors import DriveMappingError, InvalidArgumentError, UnsupportedPlatformError

__all__ = ["MapStatus", "MapResult", "mapzdrive"]


class MapStatus(Enum):
    """Outcome of a mapzdrive call.

    MAPPED means a new mapping was established; ALREADY_MAPPED means the
    letter already pointed at the requested UNC (nothing was done);
    DRYRUN means the call was a dry run and nothing was touched.
    """

    MAPPED = "mapped"
    ALREADY_MAPPED = "already_mapped"
    DRYRUN = "dryrun"


@dataclass(frozen=True)
class MapResult:
    """The mapping that was (or would be) established.

    Attributes
    ----------
    status : MapStatus
        What happened: MAPPED, ALREADY_MAPPED or DRYRUN.
    letter : str
        The normalized drive letter, e.g. ``Z:``.
    unc : str
        The UNC path behind the letter.
    """

    status: MapStatus
    letter: str
    unc: str


def _run_net(args: list[str]) -> subprocess.CompletedProcess:
    """Run net.exe with OEM decoding (errors replaced); never raises."""
    # OEM code page for net.exe output; errors replaced, never raises on decode
    return subprocess.run(
        args,
        capture_output=True,
        encoding="oem",
        errors="replace",
        check=False,
    )


def _normalize_letter(letter: str) -> str:
    """Normalize a drive-letter spelling ('z', 'Z:', 'Z:/') to ``Z:``."""
    raw = letter.strip().rstrip("/\\").rstrip(":")
    if len(raw) != 1 or not raw.isalpha():
        raise InvalidArgumentError(f"drive letter must be like 'Z:' (got {letter!r}).")
    return f"{raw.upper()}:"


def _query_mapping(letter: str) -> str | None:
    """UNC currently mapped to ``letter``, or None. Parses ``net use X:``."""
    proc = _run_net(["net", "use", letter])
    if proc.returncode != 0:
        return None
    for line in (proc.stdout or "").splitlines():
        for tok in line.split():
            if tok.startswith("\\\\"):
                return tok
    return None


def mapzdrive(
    *,
    letter: str | None = None,
    unc: str | None = None,
    user: str | None = None,
    config: Path | str | None = None,
    persistent: bool = True,
    force: bool = False,
    dry_run: bool = False,
) -> MapResult:
    """Map the Z: team drive (or ``letter``) to ``unc`` via ``net use``.

    Canonical contract name: ``datalib_map_drive`` (``mapzdrive`` is the
    verbatim cross-language alias kept from Stata). Windows only; no
    shell is ever involved (argument lists only). An omitted letter/UNC
    is filled from the user's config block (zDrive / zDriveUNC). When the
    letter is already mapped to the requested UNC nothing is done; when
    it points elsewhere, remapping requires ``force=True``.

    Parameters
    ----------
    letter : str or None, optional
        Drive letter such as ``Z:``; None takes zDrive from the config.
    unc : str or None, optional
        UNC path such as ``\\\\server\\share``; None takes zDriveUNC from
        the config.
    user : str or None, optional
        User name for the config lookup; defaults to the login user.
    config : Path or str or None, optional
        Config file path; defaults to ``~/.config/user_config.yml``.
    persistent : bool, optional
        Pass ``/persistent:yes`` (default) or ``/persistent:no``.
    force : bool, optional
        Unmap a conflicting existing mapping first (default False).
    dry_run : bool, optional
        Report the intended mapping without touching anything
        (default False).

    Returns
    -------
    MapResult
        The mapping that was (or would be) established, with its status.

    Raises
    ------
    UnsupportedPlatformError
        If the platform is not Windows.
    InvalidArgumentError
        If the letter is malformed or no UNC path is available.
    DriveMappingError
        If the letter is mapped elsewhere without ``force``, or a
        ``net use`` command fails.
    ConfigFileNotFound
        If defaults are needed but the config file is missing.
    UserBlockNotFound
        If defaults are needed but the user has no config block.
    """
    if sys.platform != "win32":
        raise UnsupportedPlatformError("mapzdrive is only available on Windows.")

    if letter is None or unc is None:
        cfg = getuserconfig(user=user, config=config)
        if letter is None:
            letter = cfg.zDrive
        if unc is None:
            unc = cfg.zDriveUNC
    if not unc:
        raise InvalidArgumentError(
            "no UNC path to map: pass unc= or add zDriveUNC to your config block."
        )
    letter = _normalize_letter(letter)

    current = _query_mapping(letter)
    if current is not None:
        if current.rstrip("\\").lower() == unc.rstrip("\\").lower():
            return MapResult(status=MapStatus.ALREADY_MAPPED, letter=letter, unc=current)
        if not force:
            raise DriveMappingError(
                f"{letter} is already mapped to {current}; pass force=True to remap."
            )
        if not dry_run:
            proc = _run_net(["net", "use", letter, "/delete", "/y"])
            if proc.returncode != 0:
                raise DriveMappingError(
                    f"could not unmap {letter}: {(proc.stderr or '').strip()}"
                )

    if dry_run:
        return MapResult(status=MapStatus.DRYRUN, letter=letter, unc=unc)

    flag = "/persistent:yes" if persistent else "/persistent:no"
    proc = _run_net(["net", "use", letter, unc, flag])
    if proc.returncode != 0:
        raise DriveMappingError(
            f"mapping {letter} -> {unc} failed: {(proc.stderr or '').strip()}"
        )
    return MapResult(status=MapStatus.MAPPED, letter=letter, unc=unc)
