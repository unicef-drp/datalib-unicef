# demo — a live-demo library, fetched not committed

This directory holds the **shape** of a datalib library and the code to fill it. It holds
**no survey data**, and it never will.

```
demo/
  manifest.yml             what the demo library contains — declared, reviewable, diffable
  make_demo_skeleton.py    builds demo/datalib/ as empty folders + .gitkeep
  fetch_demo_library.py    downloads the data with YOUR credentials, into that skeleton
  datalib/                 78 leaf dirs + .gitkeep + a .datalib marker, 0 bytes of data
```

## Why the data is not here

Survey microdata is governed by its provider's terms, not by this repository's MIT
licence. [`LICENSE`](../LICENSE) says so directly:

> Survey microdata accessed THROUGH this software is likewise not covered: it is governed
> by the terms of its own provider (UNICEF MICS, DHS, national statistical offices),
> independent of this licence.

DHS forbids redistribution of its microdata, "either directly or within any tool /
dashboard". MICS is **country-owned** — UNICEF distributes on behalf of the countries
that own it, so redistribution is not UNICEF's to grant. Committing either to a public
repository would breach those terms no matter how few rows were involved.

So the repository carries what *is* ours to license — the layout, which is authored here
and is the thing datalib's grammar is about — and every byte of data arrives at demo time
under your own agreement.

**You cannot commit the data by accident.** `.gitignore` starts with a deny-all `*`, and
under `demo/` only `.gitkeep`, `*.py`, `*.md`, `demo/*.yml` and the `.datalib` marker are
re-included. `.dta`, `.csv`, `.zip` and `.pdf` are invisible to git.
`make_demo_skeleton.py` **proves** this on every run rather than asserting it, by planting
probe files and checking `git add --dry-run` refuses them.

## Setup

```bash
python demo/make_demo_skeleton.py          # already committed; run only after editing the manifest
pip install pyyaml ipumspy                 # demo-only, NOT datalib dependencies
export IPUMS_API_KEY=...                   # free: https://account.ipums.org/api_keys
python demo/fetch_demo_library.py
```

Then point datalib at it:

```stata
datalib, library(demo/datalib) countries
```

To undo: `python demo/fetch_demo_library.py --clean` removes every fetched file and leaves
the skeleton exactly as cloned.

## What the demo actually demonstrates

IPUMS DHS returns **one harmonized rectangular extract** spanning the samples you asked
for. That is the *opposite* shape from the archive datalib manages — and that is the
point. `fetch_demo_library.py` partitions that single file into
`<CCC>/<CCC>_<YYYY>_<PROG>/..._v01_M/Data/Stata/`, so the demo shows datalib doing its
actual job: turning a flat extract into a resolvable library, with countries, surveys,
vintages and adaptations that `datalib_resolve` and `datalib_load` can navigate.

The manifest declares six real DHS surveys — BGD 2017, COL 2015, ETH 2016, IDN 2017,
NGA 2018, ZWE 2015 — chosen so the tree exercises the grammar: COL carries **two
vintages** (so "latest wins" is visible) and **two adaptations**; IDN carries **none**, so
the empty-adaptation case appears too.

## MICS is manual, and will stay manual

There is no MICS equivalent of DHS's model datasets, and **IPUMS MICS is not among the
collections the IPUMS API supports** — so even that route is a manual web extract. Hence
`--place-mics DIR`, which copies files *you* already downloaded into the layout. It never
fetches.

Third-party GitHub repositories republishing MICS microdata exist. Do not point this
script at one — it would route around the provider's terms and pull this repository into
that decision.

## The IPUMS identifiers are unverified

`ipums.collection` and every `ipums_sample` in `manifest.yml` were written **without an
API key**, so they have never been checked against the live sample list, and IPUMS's API
reference is JavaScript-rendered and could not be read either. The country / year /
programme triples are all real DHS surveys; the IPUMS *sample identifiers* are a guess at
the naming pattern.

`fetch_demo_library.py` does not paper over this. It surfaces the API's own rejection,
naming the offending code, so the first real run tells you exactly what to correct here.
When you fix a value, delete its `UNVERIFIED` comment — that is how the manifest stops
lying about its own confidence.
