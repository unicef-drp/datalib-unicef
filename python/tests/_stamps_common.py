"""Reading the version a Stata file claims for itself.

Shared by :mod:`test_stamps`, which asks questions answerable from the working tree
alone, and :mod:`test_stamps_history`, which asks one that needs git history. The
split matters: the history question cannot be answered in a *generated* repository
-- the public distribution arrives one commit per release, touching hundreds of
files, so every file appears to have changed at that release -- while the two
working-tree questions are answerable anywhere and guard what ``which datalib``
reports to whoever installed it. Shipping them together meant withholding the whole
file from the public tree and losing both, which is what happened in 0.9.31 and is
what this module exists to prevent recurring.
"""

from __future__ import annotations

import re
from pathlib import Path

# datalib.ado is the exception, and deliberately so: -which datalib- is how
# everyone actually checks what they have, and it reports THIS file's stamp. A
# front door that reports a version eight releases behind the package sends people
# to the wrong conclusion, so this one file tracks VERSION exactly. The stamp bump
# is itself a content change, so it does not violate the only-bump-what-changed
# convention -- it just means this file changes every release.
FRONT_DOOR = "stata/src/d/datalib.ado"

_STAMP = re.compile(r"^\s*\*!\s*(?:Version:\s*)?v?\s*([0-9]+(?:\.[0-9]+)*)", re.MULTILINE)
_HELP_STAMP = re.compile(r"\{right:Version\s+([0-9]+(?:\.[0-9]+)*)\}")


def as_tuple(version: str) -> tuple[int, ...]:
    return tuple(int(p) for p in version.split(".") if p.isdigit())


def stamp_of(path: Path) -> str | None:
    """The version a source or help file claims for itself."""
    text = path.read_text(encoding="utf-8", errors="replace")
    if path.suffix == ".sthlp":
        m = _HELP_STAMP.search(text)
        if m:
            return m.group(1)
    m = _STAMP.search(text)
    return m.group(1) if m else None
