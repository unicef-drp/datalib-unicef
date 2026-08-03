"""Fill demo/datalib/ with real survey data, fetched under YOUR OWN provider agreement.

    export IPUMS_API_KEY=...            # or set it in the environment on Windows
    pip install ipumspy                 # optional dependency, demo-only
    python demo/fetch_demo_library.py                 # fetch IPUMS DHS, partition it
    python demo/fetch_demo_library.py --place-mics DIR  # place your own MICS downloads
    python demo/fetch_demo_library.py --clean         # remove fetched data, keep skeleton

NOTHING IS REDISTRIBUTED
------------------------
This script downloads to your machine using your credentials. No survey microdata is
committed to this repository, and the deny-all .gitignore makes committing it by
accident impossible -- verified by make_demo_skeleton.py rather than assumed.

WHY IPUMS, AND WHAT IT ACTUALLY DEMONSTRATES
--------------------------------------------
IPUMS DHS returns ONE harmonized rectangular extract spanning the samples requested --
which is the opposite shape from the archive datalib manages. That mismatch is the
point of the demo rather than a problem with it: this script partitions that single
file into ``<CCC>/<CCC>_<YYYY>_<PROG>/..._v01_M/Data/Stata/``, turning a flat extract into
a resolvable library. Organising an archive is what datalib is for, so the demo shows
the tool doing its actual job rather than merely reading a tree someone else arranged.

WHY MICS IS MANUAL, AND WILL STAY MANUAL
----------------------------------------
Not an omission. MICS microdata is registration-gated and COUNTRY-OWNED: UNICEF
distributes on behalf of the countries that own it, so redistribution is not UNICEF's to
grant, and there is no training/model dataset of the kind DHS publishes. IPUMS MICS
exists but is not among the collections the IPUMS API supports, so even that route is a
manual web extract. So ``--place-mics`` takes files YOU already downloaded and puts them
where datalib expects; it never fetches.

Third-party GitHub repositories republishing MICS microdata do exist. Do not point this
script at one: it would route around the provider's terms and drag this repository into
that decision.

STATUS OF THE IPUMS IDENTIFIERS
-------------------------------
``ipums.collection`` and every ``ipums_sample`` in manifest.yml are UNVERIFIED -- written
without an API key, so never checked against the live sample list. This script does not
pretend otherwise: it surfaces the API's own rejection, naming the code at fault, so the
first real run tells you exactly what to correct in the manifest.
"""

from __future__ import annotations

import argparse
import os
import re
import shutil
import sys
from pathlib import Path

try:
    import yaml
except ImportError:  # pragma: no cover -- environment, not logic
    raise SystemExit(
        "  PyYAML is required to read demo/manifest.yml:  pip install pyyaml\n"
        "  (both demo scripts need it; see demo/README.md)"
    )

from _common import latest_vintage

HERE = Path(__file__).resolve().parent
DATA_SUFFIXES = {".dta", ".csv", ".sav", ".zip", ".pdf", ".do", ".xml"}


def load_manifest() -> dict:
    with (HERE / "manifest.yml").open(encoding="utf-8") as fh:
        return yaml.safe_load(fh)


def library_root(man: dict) -> Path:
    root = HERE / man["library_dir"]
    if not root.is_dir():
        sys.exit("  demo/datalib is missing. Run: python demo/make_demo_skeleton.py")
    return root


def stata_dir(root: Path, s: dict, unit: str) -> Path:
    survey = f"{s['iso3']}_{s['year']}_{s['programme']}"
    return root / s["iso3"] / survey / unit / "Data" / "Stata"


def clean(root: Path) -> int:
    """Remove fetched data, leave the committed skeleton exactly as cloned."""
    removed = 0
    for p in root.rglob("*"):
        if p.is_file() and p.name != ".gitkeep" and p.name != ".datalib":
            p.unlink()
            removed += 1
    # demo/_extract too: --clean claims to restore the pre-fetch state, and leaving the
    # raw IPUMS download behind after --keep-extract would make that claim false.
    raw = HERE / "_extract"
    if raw.is_dir():
        n = sum(1 for p in raw.rglob("*") if p.is_file())
        # NOT ignore_errors: --clean advertises that it restores the pre-fetch state, so a
        # removal that silently failed would make the success message a lie -- and leave
        # provider bytes on disk while telling the operator they are gone.
        try:
            shutil.rmtree(raw)
        except OSError as exc:
            # Recount AFTER the failure. rmtree deletes as it walks, so it can remove some
            # files before raising -- reporting the pre-deletion count would overstate what
            # is left, and the whole point of this branch is to tell the operator accurately
            # how much provider data is still on disk.
            left = sum(1 for p in raw.rglob("*") if p.is_file()) if raw.is_dir() else 0
            print(f"  FAILED to remove demo/_extract: {exc}")
            print(f"  {left} of {n} raw download file(s) are STILL THERE. Remove by hand.")
            return 1
        print(f"  removed demo/_extract ({n} raw download file(s))")
    print(f"  removed {removed} fetched file(s); skeleton and .gitkeep untouched")
    return 0


def fetch_ipums(man: dict, root: Path, keep_extract: bool) -> int:
    key = os.environ.get("IPUMS_API_KEY")
    if not key:
        print("  IPUMS_API_KEY is not set.")
        print("  Get a free key at https://account.ipums.org/api_keys and export it.")
        print("  Nothing was downloaded.")
        return 2
    try:
        from ipumspy import IpumsApiClient, MicrodataExtract, readers
    except ImportError:
        print("  ipumspy is not installed. It is a DEMO-ONLY dependency, deliberately")
        print("  not required by the datalib packages:  pip install ipumspy")
        return 2

    surveys = man["surveys"]
    samples = [s["ipums_sample"] for s in surveys]
    cfg = man["ipums"]

    print(f"  collection={cfg['collection']}  samples={len(samples)}  "
          f"variables={len(cfg['variables'])}")
    print("  NOTE: collection and sample codes in manifest.yml are UNVERIFIED.")

    client = IpumsApiClient(key)
    extract = MicrodataExtract(
        collection=cfg["collection"],
        description="datalib demo library (see demo/README.md)",
        samples=samples,
        variables=list(cfg["variables"]),
        data_format=cfg.get("data_format", "stata"),
    )
    try:
        client.submit_extract(extract)
        print("  submitted; waiting (this is IPUMS-side, typically minutes)")
        client.wait_for_extract(extract)
        dl = HERE / "_extract"
        dl.mkdir(exist_ok=True)
        client.download_extract(extract, download_dir=dl)
    except Exception as exc:  # noqa: BLE001 -- the API's message is the useful part
        print("  IPUMS REJECTED THE REQUEST. Its own words:")
        print(f"    {type(exc).__name__}: {exc}")
        print("  If it names a sample or collection, fix that value in demo/manifest.yml")
        print("  and drop its UNVERIFIED comment. Do not work around the rejection.")
        return 1

    ddi_files = sorted(dl.glob("*.xml"))
    dat_files = sorted(p for p in dl.iterdir() if p.suffix in {".gz", ".dta", ".zip"})
    if not ddi_files or not dat_files:
        print(f"  downloaded to {dl} but could not identify DDI + data; inspect it by hand.")
        return 1

    ddi = readers.read_ipums_ddi(ddi_files[0])
    df = readers.read_microdata(ddi, dat_files[0])
    print(f"  extract: {len(df):,} rows x {len(df.columns)} columns")

    written = partition(df, man, root)
    if not keep_extract:
        shutil.rmtree(dl, ignore_errors=True)
    print(f"  wrote {written} file(s) into the skeleton")
    return 0


def partition(df, man: dict, root: Path) -> int:
    """Split one integrated extract into the datalib layout. This IS the demo.

    Partitioned on SAMPLE, never on YEAR. An earlier version filtered with
    ``df[df[ycol] == s["year"]]``, which is wrong the moment two requested surveys share
    a year -- and this manifest has two such collisions, BGD/IDN in 2017 and COL/ZWE in
    2015. It would have written Bangladeshi and Indonesian rows into BOTH countries'
    folders, silently, and the demo would have shown confident nonsense. Caught in review.

    SAMPLE is one value per requested sample, so the mapping is exact. Where it cannot be
    established this function writes NOTHING and says why: a demo library containing the
    wrong country's data is worse than an empty one, because the emptiness is visible.
    """
    cols = {c.upper(): c for c in df.columns}
    # No ycol: YEAR is deliberately NOT part of the partition, and binding it would
    # imply otherwise to the next reader.
    scol, ccol = cols.get("SAMPLE"), cols.get("COUNTRY")
    if not scol:
        print("  extract has no SAMPLE column, so it cannot be split by survey.")
        print("  YEAR alone is NOT a discriminator here: BGD/IDN share 2017 and COL/ZWE")
        print("  share 2015, so filtering on it would mix countries. Add SAMPLE to")
        print("  demo/manifest.yml -> ipums.variables and refetch. Nothing was written.")
        print(f"  columns present: {', '.join(sorted(df.columns))}")
        return 0

    # SAMPLE may arrive as the IPUMS string id or as a labelled integer, depending on how
    # the extract was read. Compare on the string form of whichever it is, and report the
    # observed values when a manifest code does not appear -- the operator needs to see
    # what IPUMS actually called it, since these codes are UNVERIFIED.
    observed = {str(v) for v in df[scol].unique()}

    written = 0
    for s in man["surveys"]:
        want = str(s["ipums_sample"])
        sub = df[df[scol].astype(str) == want]
        if sub.empty:
            print(f"    {s['iso3']} {s['year']}: sample '{want}' not in the extract -- skipped")
            print(f"      SAMPLE values present: {', '.join(sorted(observed))}")
            continue
        if ccol and sub[ccol].nunique() > 1:
            print(f"    {s['iso3']} {s['year']}: sample '{want}' spans "
                  f"{sub[ccol].nunique()} countries -- refusing to write a mixed file")
            continue
        survey = f"{s['iso3']}_{s['year']}_{s['programme']}"
        units = [f"{survey}_{v}" for v in s["vintages"]]
        if s["vintages"] and s.get("adaptations"):
            master = latest_vintage(s["vintages"])
            units += [f"{survey}_{master}_v01_A_{a}" for a in s["adaptations"]]
        for unit in units:
            d = stata_dir(root, s, unit)
            if not d.is_dir():
                print(f"    {unit}: not in the skeleton -- run make_demo_skeleton.py")
                continue
            sub.to_stata(d / f"{unit}_household.dta", write_index=False, version=118)
            written += 1
    return written


def _names_country(filename: str, iso3: str) -> bool:
    """Does this filename name this country, as a TOKEN rather than a substring?

    Substring matching put other countries' files in a country's folder. Real collisions
    among the ISO3 codes this demo uses:

        ETH in "METHODOLOGY.do"       COL in "PROTOCOL.dta"      IDN in "hhIDNumbers.csv"

    all match on a substring test and none of them names a country. Placing a file in the
    wrong country's directory is the same class of error as the YEAR-only partition bug: the
    demo would run, show plausible output, and be wrong about which country it described.

    KNOWN LIMIT, and it errs the safe way. Token matching requires the ISO3 to appear as its
    own separated field, so plenty of real provider filenames will NOT match::

        ZWE_2019_hh.dta   tokens ['2019','dta','hh','zwe']   matches
        etZW61FL.DTA      tokens ['dta','etzw61fl']          does NOT
        ZWHR62DT.DTA      tokens ['dta','zwhr62dt']          does NOT
        zw_hh.sav         tokens ['hh','sav','zw']           does NOT -- 2-letter DHS code

    DHS-style names glue a two-letter country code to the recode and version, so nothing in
    them is an ISO3 token. Those files are SKIPPED and named in the output rather than placed,
    which is the direction to fail in: an operator who sees "nothing matched" renames or moves
    the files, whereas a misplaced file is discovered later, if at all. Widen this only with a
    country-code table, never by relaxing back to a substring test.
    """
    tokens = {tok.lower() for tok in re.split(r"[^A-Za-z0-9]+", filename) if tok}
    return iso3.lower() in tokens


def place_mics(man: dict, root: Path, src: Path) -> int:
    """Copy MICS files the user already downloaded into the expected locations."""
    entries = man.get("mics_manual") or []
    if not entries:
        print("  manifest.yml has an empty ``mics_manual`` list, so there is nothing to place.")
        print("  Add the surveys you hold, rerun make_demo_skeleton.py, then rerun this.")
        return 0
    if not src.is_dir():
        sys.exit(f"  --place-mics: {src} is not a directory")

    # Every data file present, so a non-match can be REPORTED BY NAME rather than merely
    # counted. The docstring promised named skips and this function only printed a per-survey
    # summary, which left an operator knowing something failed but not which file to rename --
    # and renaming is the whole remedy for a DHS-style name that carries no ISO3 token.
    candidates = [p for p in src.rglob("*")
                  if p.is_file() and p.suffix.lower() in DATA_SUFFIXES]
    matched_any: set[Path] = set()

    placed = 0
    for s in entries:
        survey = f"{s['iso3']}_{s['year']}_{s['programme']}"
        found = [p for p in candidates if _names_country(p.name, s["iso3"])]
        matched_any.update(found)
        if not found:
            print(f"    {survey}: nothing in {src} named '{s['iso3']}' as a token -- skipped")
            continue
        for v in s["vintages"]:
            d = stata_dir(root, s, f"{survey}_{v}")
            if not d.is_dir():
                print(f"    {survey}_{v}: not in the skeleton -- run make_demo_skeleton.py")
                continue
            for f in found:
                shutil.copy2(f, d / f.name)
                placed += 1
    unmatched = sorted(p.name for p in candidates if p not in matched_any)
    if unmatched:
        # ALL of them, uncapped. A truncated list defeats the purpose: the operator's next
        # action is to rename the files that did not match, and they cannot rename what they
        # cannot see. Bounded by their own source directory, and this runs interactively.
        print(f"  {len(unmatched)} data file(s) matched NO survey and were not placed:")
        for name in unmatched:
            print(f"    {name}")
        print("  Token matching needs the ISO3 as its own field, so DHS-style names like")
        print("  ZWHR62DT.DTA carry no ISO3 and cannot match. Rename them (ZWE_...) or add")
        print("  the survey to mics_manual in demo/manifest.yml.")
    print(f"  placed {placed} file(s). They remain gitignored; do not force-add them.")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description="Fetch/place demo data. Nothing is redistributed.")
    ap.add_argument("--clean", action="store_true", help="remove fetched data, keep the skeleton")
    ap.add_argument("--place-mics", metavar="DIR",
                    help="directory of MICS files YOU downloaded, to copy into the layout")
    ap.add_argument("--keep-extract", action="store_true",
                    help="keep the raw IPUMS download in demo/_extract for inspection")
    args = ap.parse_args()

    man = load_manifest()
    root = library_root(man)

    if args.clean:
        return clean(root)
    if args.place_mics:
        return place_mics(man, root, Path(args.place_mics).resolve())
    return fetch_ipums(man, root, args.keep_extract)


if __name__ == "__main__":
    raise SystemExit(main())
