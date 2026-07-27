# unicef-datalib (import name: `datalib`)

Python implementation of the **datalib contract v1** — the language-neutral
folder grammar and semantics for the UNICEF survey-microdata library shared by
the Stata (`stata/`), R (`r/`) and Python (`python/`) ports. The contract
lives in [`config/grammar.md`](../config/grammar.md); the collection registry
in [`config/collections.yml`](../config/collections.yml) (a byte-identical
copy is bundled inside the package and asserted by the test suite).

## Install from the UNICEF net site (Z:)

The package is not on PyPI and the repository is private, so the LAN share is the
supported install path:

```bash
pip install --upgrade "Z:/_pkg/datalib/python/unicef_datalib-0.9.19-py3-none-any.whl"
```

A built **wheel** is published per version -- deliberately, not a source tree: this
project builds with `hatchling`, which an operator will not have installed, so a
source install would try to fetch a build backend. A wheel needs none.
`datalib_update()` prints the exact command for whatever version the site holds.
Previous versions stay under `Z:/_pkg/datalib/<version>/python/` for rollback.

## Install

```
pip install --user .            # from this directory
pip install --user .[fidelity]  # optional pyreadstat engine (C extension)
```

Pure wheel, no console-script entry points (AppLocker blocks unsigned `.exe`
shims) — the CLI is `python -m datalib`.

## Use

```python
import datalib as dl

df = dl.load("ZWE", 2019, "MICS", collection="HLT",
             root="path/to/library")            # merged DataFrame
mods = dl.load("ZWE", 2019, "MICS", merge=False,
               root="path/to/library")          # {module: DataFrame}
rp = dl.resolve("BRA", survey="PNAD", kind="master",
                root="path/to/library")         # frozen VintagePaths
dl.browse("ZWE_2019_MICS", root="path/to/library")
```

Every function is also exported under its canonical cross-language token
(`dl.datalib_load`, `dl.datalib_resolve`, ...); `getuserconfig` and
`mapzdrive` keep their names verbatim.

Library root precedence: `root=` argument -> `DATALIB_ROOT` env var ->
`datalib:` key in your `~/.config/user_config.yml` block -> `DatalibRootNotSet`.

Loading notes:

- Engine default is `pandas.read_stata` with `convert_categoricals=False`
  (numeric codes survive; loaders never mutate values — e.g. `windex5 == 8`
  is preserved). `engine="pyreadstat"` is available with the `[fidelity]`
  extra.
- Merges use the registry keys: person modules chain 1:1 (outer) on
  `keys_person` (after `linevar` -> `line_number` normalization), then
  hh-level modules attach m:1 (outer, unmatched hh rows kept) on `keys_hh`.
  Keys are validated per module; failures raise `InvalidArgumentError`
  naming the module.
- `ctrycode` and `year` provenance columns are added (when absent) to every
  load result, for master as well as adaptation vintages.

## Am I running the current version?

```python
dl.datalib_update()                          # report only
dl.datalib_update(netsource="Z:/_pkg/datalib")
r = dl.datalib_update(quiet=True)
r.status   # "current" | "newer_available" | "source_behind" | "unknown"
```

Reports three coordinates — the version you are running, the version published at
the net site, and which way they differ — reading the **same** `VERSION` manifest as
the Stata and R legs, so one publish serves all three.

**It does not install.** `pip install` over a package whose own module is already
imported leaves the interpreter holding half-replaced modules, so this prints the
exact command instead. Asserted by a test that walks the AST, so the function cannot
quietly gain a `subprocess` call later.

Why this exists at all, given `pip install -U`: this package is **not on PyPI** and
the repository is private, so pip has no index to consult.

## CLI

```
python -m datalib ls [TOKEN] [--root ROOT]
python -m datalib config [--user U] [--config PATH]
```

## Tests

```
python -m pytest python/tests -q     # from the repo root
```

The conformance tests read the shared golden cases in
[`tests/cases_resolve.csv`](../tests/cases_resolve.csv) and
[`tests/cases_load.csv`](../tests/cases_load.csv) against the committed
fixture tree — all cases must pass unmodified.

## Authors and citation

`datalib` is joint work by **Joao Pedro Azevedo** and **Minh Cong Nguyen**: the
folder grammar, the resolver and the harmonized-adaptation model that this package
implements were designed together. This repository is the UNICEF adaptation; the
generic package and the paper live upstream in `jpazvd/datalib-dev`.

If you use `datalib` in your research, please cite the design paper as a draft:

> Azevedo, Joao Pedro and Nguyen, Minh Cong. *Harmonized Microdata Access with
> datalib: A Framework for Survey Data Management in Stata*. 2026. Unpublished
> working draft; not submitted or forthcoming. Kept in `paper/` in
> `jpazvd/datalib-dev`.

