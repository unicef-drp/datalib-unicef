"""Helpers shared by the demo scripts, so there is one copy and not two.

``latest_vintage`` lived in BOTH make_demo_skeleton.py and fetch_demo_library.py, with
identical logic and identical docstrings. That is the duplicate-without-an-enforcer shape
this repository has been bitten by twice already: ``datalib.sthlp`` drifted five releases
behind the code it documented, and the ``local RUNNING`` literal in datalib.ado needed its own
test precisely because nothing else could notice it diverging from VERSION.

Here the risk is concrete rather than theoretical. The two copies compute where an
adaptation hangs -- the skeleton builder decides which directories to CREATE, the fetcher
decides which to WRITE INTO. If one copy were tightened and the other not, the fetcher would
write into directories the skeleton never made, or the skeleton would carry leaves the
fetcher never fills, and ``--check`` would pass either way because both agree with the manifest
in isolation.

Following the repository's existing pattern for this: tests/_stata_parse.py and
python/tests/_stamps_common.py are leading-underscore modules holding exactly what their
neighbours must not each own a copy of.
"""

from __future__ import annotations


def latest_vintage(vintages: list[str]) -> str:
    """The NUMERIC maximum vintage, not the last one listed.

    datalib defines "latest" as the highest vintage number -- v10_M beats v09_M -- and the
    conformance fixtures pin exactly that with BRA v09/v10. Taking ``vintages[-1]`` made the
    answer depend on YAML ordering, so reordering the manifest would silently hang
    adaptations off the wrong master and build a tree that contradicts the contract.
    """
    def key(v: str) -> tuple[int, str]:
        digits = "".join(c for c in v.split("_")[0] if c.isdigit())
        return (int(digits) if digits else -1, v)

    return max(vintages, key=key)
