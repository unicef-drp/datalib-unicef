"""Is the datalib you are running the current one?

The Python counterpart of Stata's ``datalib , update``, reading the **same**
version manifest, so one publish serves all three languages.

**It does not install anything.** ``pip install`` over a package whose own module
is already imported leaves the interpreter holding half-replaced modules, so this
reports and prints the exact command rather than running it. That is a deliberate
difference from Stata, where ``datalib , update install`` can replace ado-files in
place because Stata has no package manager and no imported-module problem.

Why this exists at all, given pip: this package is **not on PyPI**, and the
repository is private, so ``pip install -U`` has no index to consult. The net site
is the only place a version can be discovered.
"""

from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path

__all__ = ["UpdateStatus", "datalib_update"]

_DEFAULT_NETSOURCE = "Z:/_pkg/datalib"
_MANIFEST = "VERSION"


@dataclass(frozen=True)
class UpdateStatus:
    """The three coordinates of an update check, plus the direction.

    Attributes
    ----------
    running : str
        Version of the ``datalib`` currently imported.
    source : str
        Net site that was consulted.
    source_version : str or None
        Version the net site publishes, or ``None`` when no manifest was found.
    status : str
        ``"current"``, ``"newer_available"``, ``"source_behind"`` or
        ``"unknown"``.
    """

    running: str
    source: str
    source_version: str | None
    status: str


def _as_tuple(version: str) -> tuple[int, ...]:
    """Version string to a comparable tuple of integers.

    Component-wise, because text order is wrong for versions: as strings
    ``"0.9.10" < "0.9.9"``, which is backwards and is the whole reason for
    comparing rather than eyeballing. Non-numeric components are dropped rather
    than raising, so a pre-release suffix degrades to a coarser comparison
    instead of an error.
    """
    out: list[int] = []
    for part in str(version).strip().split("."):
        digits = ""
        for ch in part:
            if ch.isdigit():
                digits += ch
            else:
                break
        if digits == "":
            break
        out.append(int(digits))
    return tuple(out)


def version_status(running: str | None, source_version: str | None) -> str:
    """Name the direction between two version strings.

    Split out of :func:`datalib_update` so it is testable without a net site.

    Parameters
    ----------
    running : str or None
        The version in use.
    source_version : str or None
        The version published at the net site.

    Returns
    -------
    str
        ``"current"``, ``"newer_available"``, ``"source_behind"`` or
        ``"unknown"`` when either side is missing or unparseable.
    """
    if not running or not source_version:
        return "unknown"
    a = _as_tuple(running)
    b = _as_tuple(source_version)
    if not a or not b:
        return "unknown"
    if b > a:
        return "newer_available"
    if b < a:
        return "source_behind"
    return "current"


def datalib_update(
    netsource: str | os.PathLike[str] | None = None,
    quiet: bool = False,
) -> UpdateStatus:
    """Check whether a newer datalib is published, and report the direction.

    Does not install: see the module docstring. The net site is resolved from
    ``netsource``, then the ``DATALIB_NETSOURCE`` environment variable, then
    ``Z:/_pkg/datalib``.

    Parameters
    ----------
    netsource : str or PathLike or None, optional
        Directory holding the published ``VERSION`` manifest.
    quiet : bool, optional
        When True, return the result without printing the report.

    Returns
    -------
    UpdateStatus
        The running version, the net site, its version, and the direction.
    """
    from . import __version__ as running

    if netsource is not None and str(netsource).strip():
        src = str(netsource).strip()
    else:
        src = os.environ.get("DATALIB_NETSOURCE", "").strip() or _DEFAULT_NETSOURCE
    src = src.replace("\\", "/").rstrip("/") or _DEFAULT_NETSOURCE

    source_version: str | None = None
    manifest = Path(src) / _MANIFEST
    try:
        if manifest.is_file():
            first = manifest.read_text(encoding="utf-8").splitlines()
            if first and first[0].strip():
                source_version = first[0].strip()
    except OSError:
        source_version = None

    status = version_status(running, source_version)
    result = UpdateStatus(
        running=running, source=src, source_version=source_version, status=status
    )

    if not quiet:
        bar = "-" * 68
        print(f"\n{bar}\ndatalib update (Python)\n{bar}")
        print(f"  running        : {running}")
        print(f"  net site       : {src}")
        print(
            f"  site version   : "
            f"{source_version if source_version else f'no {_MANIFEST} file at {src}'}"
        )
        if status == "newer_available":
            # Name the ARTEFACT, not the directory. The net site holds one built
            # wheel per version, and `pip install <dir>` on the containing folder
            # fails. A wheel also needs no build backend, which matters here: this
            # project builds with hatchling, which an operator will not have
            # installed, so a source-tree install would try to fetch it.
            wheel = f"{src}/python/unicef_datalib-{source_version}-py3-none-any.whl"
            print(
                "\n  A newer datalib is published. This does not install it --\n"
                "  pip-installing a package whose module is already imported leaves\n"
                "  the interpreter inconsistent. From a shell, run:\n"
                f'    pip install --upgrade "{wheel}"'
            )
        elif status == "current":
            print(f"\n  Up to date - running and published are both {running}.")
        elif status == "source_behind":
            print(
                f"\n  The net site is OLDER than what you are running "
                f"({source_version} < {running}).\n"
                "  Do not reinstall from it: that would downgrade you. A stale\n"
                "  snapshot on this net site once reinstated a data-mutation bug."
            )
        else:
            print(
                f"\n  Cannot compare: no {_MANIFEST} manifest at the net site.\n"
                "  Pass netsource=, or set DATALIB_NETSOURCE."
            )
        print(bar)

    return result
