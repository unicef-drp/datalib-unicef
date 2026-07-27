# datalib (R)

R implementation of the **datalib contract v1** — the language-neutral folder
grammar and semantics for the UNICEF survey-microdata library shared by the
Stata (`stata/`), R (`r/`) and Python (`python/`) ports. The contract lives in
[`config/grammar.md`](../config/grammar.md); the collection registry in
[`config/collections.yml`](../config/collections.yml) (a byte-identical copy is
bundled at `inst/collections.yml` and asserted by the test suite).

## Install from the UNICEF net site (Z:)

The package is not on CRAN and the repository is private, so the LAN share is the
supported install path:

```r
install.packages("Z:/_pkg/datalib/R/datalib_0.9.19.tar.gz",
                 repos = NULL, type = "source")
```

A built source tarball is published per version, alongside a `VERSION` manifest that
all three language legs read. `datalib_update()` prints the exact command for
whatever version the site currently holds, so you do not have to track the filename.
Previous versions stay available under `Z:/_pkg/datalib/<version>/R/` for rollback.

## Install

```r
install.packages(c("yaml", "haven", "fs"))

# from a clone, without installing:
lapply(list.files("r/R", full.names = TRUE), source)

# or install the subdirectory:
remotes::install_github("unicef-drp/datalib-unicef", subdir = "r")
```

## Use

```r
library(datalib)

datalib_countries(root = "Z:/datalib")
datalib_surveys("ZWE", root = "Z:/datalib")
datalib_resolve("ZWE", 2019, "MICS", collection = "HLT", root = "Z:/datalib")

df <- datalib_load("ZWE", 2019, "MICS", collection = "HLT",
                   module = c("household", "hhmembers"), root = "Z:/datalib")
```

> **Argument names change in v0.10.0.** The three ports are converging on
> Stata's vocabulary, so R's `module =` becomes `modules =` and `merge = TRUE`
> becomes `nomerge = FALSE` (inverted polarity — it fails loudly rather than
> silently doing the opposite). Today's names are the ones shown above.

All 13 canonical commands are exported, under the same names as the other two
ports: `datalib_config`, `datalib_root`, `datalib_countries`, `datalib_surveys`,
`datalib_vintages`, `datalib_adaptations`, `datalib_resolve`, `datalib_files`,
`datalib_catalog`, `datalib_load`, `datalib_browse`, `datalib_create`,
`datalib_map_drive`. R exports the canonical names only — the Stata-verbatim
aliases (`getuserconfig`, `mapzdrive`) exist in Stata and Python but not here.

## Configuration

There is no R equivalent of Stata's `getuserconfig` *side effects*: the reader
returns a list and sets nothing global. `datalib_config()` is the reader.

```r
datalib_config()                                     # logged-in user's block
datalib_config(user = "jdoe")
datalib_config(config = "C:/cfg/user_config.yml")    # pin one file
datalib_config(configdir = "C:/cfg")                 # search another directory
```

The library root resolves in the contract precedence order — explicit argument
→ `DATALIB_ROOT` → `options(datalib.root=)` → config resolution → error. Config
resolution is a **two-file, key-presence search**: the current user's block is
looked up in `~/.config/user_config.yml` (shared with the CSO Toolkit) and then
`~/.config/datalib_config.yml`, and the first file whose block carries a
non-empty `datalib:` key wins. Where it came from is reported on the returned
value:

```r
r <- datalib_root()
attr(r, "source_stage")   # "argument" | "env" | "option" |
                          # "config_generic" | "config_package" | "unset"
attr(r, "source_file")
```

`datalib_root()` **normalises** what it returns (`fs::path_norm` collapses
`..`, expands `~`, strips a trailing separator). Stata returns the literal
string and Python returns a `Path`, so the three ports agree on the resolved
*directory*, not on its spelling — compare normalised paths, never bytes. See
[`config/grammar.md`](../config/grammar.md) section 7.

**Not yet at parity with Stata** (tracked for v0.10.0 — see the
[Alignment status table](../config/grammar.md#alignment-status)): `find`-mode
root resolution, the structural library test, and the config bootstrap that
writes a prepopulated `user_config.yml`. Until those land, R needs an existing
config file or an explicit `root =`.

## Am I running the current version?

```r
datalib_update()                       # report only
datalib_update(netsource = "Z:/_pkg/datalib")
r <- datalib_update(quiet = TRUE)      # returns the result invisibly
r$status   # "current" | "newer_available" | "source_behind" | "unknown"
```

Reports three coordinates — the version you are running, the version published at
the net site, and which way they differ — reading the **same** `VERSION` manifest as
the Stata and Python legs, so one publish serves all three.

**It does not install.** `install.packages()` over a namespace that is already
loaded is unsafe on Windows, where the package's own files are locked by the running
session, so this prints the exact command for you to run in a fresh session instead.
That is a deliberate difference from Stata, where `datalib , update install` can
replace ado-files in place because Stata has no package manager and no
loaded-namespace problem. Asserted by a test that walks the parse tree, so the
function cannot quietly gain an install call later.

Why this exists at all, given `install.packages()` and `update.packages()`: this
package is **not on CRAN** and the repository is private, so there is no registry for
the usual machinery to query. When `datalib` has been *sourced* from a clone rather
than installed, `running` is `NA` and the status is `unknown` — there is genuinely no
installed version to compare.

## Tests

```r
# from the repo root
testthat::test_dir("r/tests/testthat")
```

The suite includes doc-truth tests: every documented `\arguments` entry must
match the function's `formals()`, so **regenerate the `.Rd` files after any
signature change** (`roxygen2::roxygenise("r")`) or the suite fails. Golden
conformance cases are shared with the other two ports and read from
[`tests/`](../tests/) at the repo root.

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

---

[← datalib README](../README.md) · [Documentation hub](../docs/README.md)
