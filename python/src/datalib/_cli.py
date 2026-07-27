"""Minimal CLI: ``python -m datalib {ls,config}``.

No console-script entry points are shipped (pip's unsigned .exe shims are
blocked by AppLocker); this module is reached only via ``python -m datalib``.
"""

from __future__ import annotations

import argparse
import sys

from .catalog import browse
from .config import getuserconfig
from .errors import DatalibError

__all__ = ["main"]


def main(argv: list[str] | None = None) -> int:
    """Entry point for ``python -m datalib``.

    Subcommands: ``ls`` lists library entries under a folder token via
    browse(); ``config`` prints the user's config block via
    getuserconfig(). Typed datalib errors are printed to stderr.

    Parameters
    ----------
    argv : list of str or None, optional
        Argument vector; None reads sys.argv (argparse default).

    Returns
    -------
    int
        Process exit code: 0 on success, 1 on any DatalibError.
    """
    parser = argparse.ArgumentParser(
        prog="python -m datalib",
        description="UNICEF microdata library client (contract v1).",
    )
    sub = parser.add_subparsers(dest="cmd", required=True)

    p_ls = sub.add_parser("ls", help="list library entries under a folder token")
    p_ls.add_argument("token", nargs="?", default=None, help="1/3/5/8-token folder name")
    p_ls.add_argument("--root", default=None, help="library root (else DATALIB_ROOT/config)")

    p_cfg = sub.add_parser("config", help="show the user's config block")
    p_cfg.add_argument("--user", default=None)
    p_cfg.add_argument("--config", default=None, help="path to user_config.yml")

    args = parser.parse_args(argv)
    try:
        if args.cmd == "ls":
            listing = browse(args.token, root=args.root)
            for entry in listing.entries:
                print(entry.name)
        elif args.cmd == "config":
            cfg = getuserconfig(user=args.user, config=args.config)
            for key in (
                "user",
                "config_path",
                "githubFolder",
                "teamsRoot",
                "zDrive",
                "zDriveUNC",
                "datalib",
            ):
                print(f"{key}: {getattr(cfg, key)}")
    except DatalibError as exc:
        print(f"datalib: {exc}", file=sys.stderr)
        return 1
    return 0
