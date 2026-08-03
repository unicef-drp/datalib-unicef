"""Build demo/datalib/ as an EMPTY skeleton -- folders and .gitkeep, no data.

    python demo/make_demo_skeleton.py            # (re)build the skeleton
    python demo/make_demo_skeleton.py --check     # fail if skeleton != manifest

WHY THE SKELETON IS COMMITTED AND THE DATA IS NOT
-------------------------------------------------
Survey microdata is governed by its provider's terms, not by this repository's MIT
licence. Committing DHS or MICS files to a public repository would redistribute them,
which neither provider permits and which UNICEF could not grant for MICS in any case,
since MICS data is country-owned. So the repository carries the SHAPE of the library --
which is authored here, and is the thing datalib's grammar is about -- and every byte
of data arrives at demo time under the user's own agreement.

The shape is worth committing on its own merits: it is a reviewable, diffable statement
of what the demo claims to contain, and `--check' turns a silent drift between the
manifest and the tree into a failure.

WHY THE DENY-ALL .gitignore IS LOAD-BEARING HERE
------------------------------------------------
.gitignore line 23 is `*', with specific re-includes. Under demo/ the effect is exactly
what is wanted: .gitkeep, *.py, *.md and demo/*.yml are committable, and .dta, .csv,
.zip and everything else a fetch produces are invisible to git. So a user who runs the
fetcher and then `git add -A' commits nothing they should not. That is not luck -- it is
the allowlist doing its job -- but it is verified rather than assumed: check_ignores()
runs on every ordinary build, with no flag to remember.
"""

from __future__ import annotations

import argparse
import shutil
import subprocess
from pathlib import Path

try:
    import yaml
except ImportError:  # pragma: no cover -- environment, not logic
    raise SystemExit(
        "  PyYAML is required to read demo/manifest.yml:  pip install pyyaml\n"
        "  (both demo scripts need it; see demo/README.md)"
    )

HERE = Path(__file__).resolve().parent


def load_manifest() -> dict:
    with (HERE / "manifest.yml").open(encoding="utf-8") as fh:
        return yaml.safe_load(fh)


def expected_dirs(man: dict) -> set[str]:
    """Every directory the manifest implies, as posix paths relative to the library root."""
    out: set[str] = set()
    vdirs = man["vintage_dirs"]
    entries = list(man.get("surveys") or []) + list(man.get("mics_manual") or [])
    for s in entries:
        survey = f"{s['iso3']}_{s['year']}_{s['programme']}"
        units = [f"{survey}_{v}" for v in s["vintages"]]
        if s["vintages"] and s.get("adaptations"):
            master = s["vintages"][-1]
            units += [f"{survey}_{master}_v01_A_{a}" for a in s["adaptations"]]
        for unit in units:
            for d in vdirs:
                out.add(f"{s['iso3']}/{survey}/{unit}/{d}")
    return out


def build(man: dict, root: Path) -> set[str]:
    if root.exists():
        shutil.rmtree(root)
    dirs = expected_dirs(man)
    for rel in sorted(dirs):
        d = root / rel
        d.mkdir(parents=True, exist_ok=True)
        # .gitkeep in the LEAF dirs only: git tracks files, not directories, so a leaf
        # without one vanishes from a fresh clone and the skeleton silently arrives
        # incomplete -- which is the whole failure this file exists to prevent.
        (d / ".gitkeep").write_text("", encoding="utf-8")

    (root / ".datalib").write_text(
        "# Presence-only marker: datalib treats this directory as a library.\n"
        "# The tree is a committed SKELETON. Data is fetched, never committed --\n"
        "# see demo/README.md.\n",
        encoding="utf-8",
    )
    return dirs


def check_ignores(root: Path) -> tuple[list[str], str | None]:
    """Prove git would refuse to commit fetched data, rather than trusting it would.

    Returns (leaked, error). `error' is non-None when the probe could not run at all --
    which must NOT be read as "nothing leaked". An earlier version ignored git's return
    code and inferred safety from empty stdout, so outside a worktree, or with git absent,
    it reported the tree safe having tested nothing: a guard that cannot fail.

    Extensions are enumerated broadly on purpose, and include the ones that HAVE leaked.
    `.do' was committable under this tree until review caught it -- MICS ships .do syntax
    files that --place-mics copies -- and `.py', `.md' and `.R' leaked too while the deny
    rule sat above the global re-includes instead of below them.
    """
    stem = "ETH/ETH_2016_DHS/ETH_2016_DHS_v01_M"
    probes = [f"{stem}/Data/Stata/probe.{e}" for e in
              ("dta", "csv", "sav", "zip", "do", "xml", "py", "md", "R")]
    probes += [f"{stem}/Doc/probe.pdf", "probe.zip"]

    leaked: list[str] = []
    for rel in probes:
        p = root / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_bytes(b"")
        # `git check-ignore -q' exits 0 when a rule matches -- INCLUDING a negation --
        # so it cannot answer "would this be committed?". `git add --dry-run' can.
        try:
            r = subprocess.run(
                ["git", "add", "--dry-run", "--", str(p)],
                cwd=root.parent.parent, capture_output=True, text=True, timeout=30,
            )
        except (OSError, subprocess.TimeoutExpired) as exc:
            p.unlink()
            return leaked, f"could not run git: {exc}"
        p.unlink()
        # git exits non-zero when the path is ignored, and prints "add '<path>'" when it
        # would stage it. Anything else means the probe itself failed, and silence from a
        # failed probe is exactly the false reassurance this guard exists to avoid.
        out, err = r.stdout.strip(), r.stderr.strip()
        if out.startswith("add "):
            leaked.append(rel)
        elif r.returncode != 0 and "ignored by one of your .gitignore files" not in err:
            return leaked, f"git add --dry-run failed unexpectedly on {rel}: {err or out}"
    return leaked, None


def main() -> int:
    ap = argparse.ArgumentParser(description="Build or verify the demo skeleton.")
    ap.add_argument("--check", action="store_true",
                    help="verify the committed skeleton matches manifest.yml; nonzero if not")
    args = ap.parse_args()

    man = load_manifest()
    root = HERE / man["library_dir"]

    if not args.check:
        dirs = build(man, root)
        leaked, error = check_ignores(root)
        print(f"  built {root}")
        print(f"  {len(dirs)} leaf directories, {len(dirs)} .gitkeep files, 0 bytes of data")
        if error:
            print(f"  COULD NOT VERIFY the ignore rules: {error}")
            print("  Treating this as a failure: an unrun guard is not a passed one.")
            return 1
        if leaked:
            print("  WARNING: these would be COMMITTABLE, so fetched data could leak:")
            for rel in leaked:
                print(f"    {rel}")
            return 1
        print("  verified: 11 file types under the skeleton are not committable,")
        print("            including .do, which leaked until a review caught it")
        return 0

    want = expected_dirs(man)
    if not root.is_dir():
        print(f"  MISSING {root} -- run: python demo/make_demo_skeleton.py")
        return 1
    have = {
        p.relative_to(root).as_posix()
        for p in root.rglob("*")
        if p.is_dir() and not any(c.is_dir() for c in p.iterdir())
    }
    missing, extra = sorted(want - have), sorted(have - want)
    nokeep = sorted(
        d for d in want if (root / d).is_dir() and not (root / d / ".gitkeep").is_file()
    )
    if not (missing or extra or nokeep):
        print(f"  demo/datalib matches manifest.yml ({len(want)} leaf directories)")
        return 0
    print("  demo/datalib has DRIFTED from manifest.yml")
    for label, items in (("missing", missing), ("not in manifest", extra),
                         ("no .gitkeep", nokeep)):
        if items:
            print(f"    {label}: {', '.join(items[:4])}"
                  + (f" (+{len(items) - 4} more)" if len(items) > 4 else ""))
    print("  rerun: python demo/make_demo_skeleton.py")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
