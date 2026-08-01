"""The two version claims ``datalib.ado`` makes about itself must equal VERSION.

Both questions are answerable from the **working tree alone**, which is why they
live here rather than in :mod:`test_stamps_history`: that module's question needs git
history, and history is unavailable in a shallow clone and misleading in a generated
one, so it is withheld from the public distribution. These two are answerable in any
checkout, generated or not -- and they are the ones that guard what an operator sees:

* the ``*!`` stamp, which ``which datalib`` reads off disk;
* the ``local RUNNING`` literal, which ``_dl_update`` reports as the version the
  *session* is executing.

Through 0.9.31 all three tests shared one file. Withholding that file from the public
tree to suppress the history question therefore dropped these two as well -- silently,
because a test that is absent reports nothing. Copilot caught it reviewing the 0.9.31
sync PR. The lesson generalises past this file: excluding a file from a distribution
removes everything in it, so a file is the wrong unit of exclusion unless everything
in it shares the reason for being excluded.
"""

from __future__ import annotations

import re

import pytest
from _stamps_common import FRONT_DOOR, stamp_of


def test_the_front_door_stamp_tracks_the_package_version(repo_root) -> None:
    """-which datalib- must not report a version the package has outgrown."""
    version = (repo_root / "VERSION").read_text(encoding="utf-8").strip()
    path = repo_root / FRONT_DOOR
    if not path.is_file():
        pytest.skip(f"{FRONT_DOOR} not found")
    stamp = stamp_of(path)
    assert stamp == version, (
        f"{FRONT_DOOR} stamps {stamp} but the package is {version}. This file is "
        f"the front door: -which datalib- reports its stamp, so it tracks VERSION "
        f"exactly. Bump the *! line."
    )


def test_the_running_literal_tracks_the_package_version(repo_root) -> None:
    """The version datalib.ado compiles into itself must equal VERSION.

    ``datalib.ado`` carries the version twice: the ``*!`` stamp, which ``which
    datalib`` reads off *disk*, and a ``local RUNNING`` literal it passes to
    ``_dl_update`` so the session can report what it is actually *running*. The
    second copy cannot be derived from the first -- reading the stamp at runtime
    would mean reading the file from disk, which is precisely the thing the literal
    exists to be compared against -- so it is a genuine duplicate, and a duplicate
    with no enforcer is how ``datalib.sthlp`` drifted five releases.

    A literal that lagged would be worse than no check at all: it would report a
    stale session on every install, and a warning that fires when nothing is wrong
    gets ignored, taking the true positives with it.
    """
    version = (repo_root / "VERSION").read_text(encoding="utf-8").strip()
    path = repo_root / FRONT_DOOR
    if not path.is_file():
        pytest.skip(f"{FRONT_DOOR} not found")
    text = path.read_text(encoding="utf-8", errors="replace")
    m = re.search(r'^\s*local\s+RUNNING\s+"([0-9]+(?:\.[0-9]+)*)"', text, re.MULTILINE)
    assert m, (
        f"{FRONT_DOOR} has no `local RUNNING \"x.y.z\"' line. It is what tells the "
        f"operator which version their session is running; without it -update- can "
        f"only report what is on disk."
    )
    assert m.group(1) == version, (
        f"{FRONT_DOOR} compiles in RUNNING={m.group(1)} but the package is {version}. "
        f"This literal is reported to the operator as the version their session is "
        f"executing, so a lagging value claims a stale session on every install."
    )
