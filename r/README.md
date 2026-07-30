# datalib (R)

R implementation of the **datalib contract v1** — the language-neutral folder
grammar and semantics for the UNICEF survey-microdata library shared by the
Stata (`stata/`), R (`r/`) and Python (`python/`) ports. The contract lives in
[`config/grammar.md`](../config/grammar.md); the collection registry in
[`config/collections.yml`](../config/collections.yml) (a byte-identical copy is
bundled at `inst/collections.yml` and asserted by the test suite).

## Install from the UNICEF net site (Z:)

The package is not on CRAN and the repository is private, so the LAN share is the
supported install path. **Note the `utils::` prefix** — it is not decoration, see
below:

```r
utils::install.packages("Z:/_pkg/datalib/R/datalib_0.9.28.tar.gz",
                        repos = NULL, type = "source")
```

A built source tarball is published per version, alongside a `VERSION` manifest that
all three language legs read. Previous versions stay available under
`Z:/_pkg/datalib/<version>/R/` for rollback.

### Why `utils::`, and what happens without it in RStudio

Plain `install.packages()` **works** — the package installs correctly — but in
**RStudio** it then throws a confusing error that looks like a failure and is not:

```text
* DONE (datalib)
Error in file(con, "r") : cannot open the connection
In addition: Warning messages:
1: In packageDescription(pkgName, lib.loc = dirname(pkgPath)) :
  no package 'datalib_0.9.27.tar.gz' was found
2: In file(con, "r") :
  cannot open file 'Z:/.../datalib_0.9.27.tar.gz/DESCRIPTION': No such file or directory
```

This is an RStudio bug, not a datalib one, and it fires on **any** single local-file
install. RStudio hooks `utils::install.packages` to record where each package came
from (`resources/app/R/Tools.R:2362`):

```r
isLocal <- is.null(repos) || any(grepl("/", pkgs, fixed = TRUE))
if (isLocal) {
   result <- eval(call, ...)                        # the real install -- succeeds
   if (is.character(pkgs) && length(pkgs) == 1L)
      .rs.recordPackageSource(pkgs, local = TRUE)   # <- handed the TARBALL path
}
```

and `recordPackageSourceImpl` (`Tools.R:2078`) assumes that path is an *installed
package directory*:

```r
pkgName <- basename(pkgPath)                                     # "datalib_0.9.27.tar.gz"
pkgDesc <- packageDescription(pkgName, lib.loc = dirname(pkgPath))
```

`basename()` of a tarball is not a package name, and `<tarball>/DESCRIPTION` does not
exist, so the bookkeeping fails *after* the install has already succeeded. The
`utils::` prefix calls the real function directly and skips the hook — the same
bypass RStudio documents on its neighbouring `remove.packages` hook ("Use
`utils::remove.packages()` to bypass this hook if necessary").

Diagnosed from `traceback()`, which is worth remembering as the first move on any
post-install error like this:

```text
5: file(con, "r")
4: readLines(descPath, warn = FALSE)
3: .rs.recordPackageSourceImpl(pkgPath, db, local)
2: .rs.recordPackageSource(pkgs, local = TRUE)
1: install.packages(...)
```

Equivalent, and immune because it never enters R's console at all:

```bash
R CMD INSTALL "Z:/_pkg/datalib/R/datalib_0.9.28.tar.gz"
```

### Dependencies are not resolved for you

`repos = NULL` installs *only* the tarball — unlike Stata's `net install`, which has
no dependency concept because everything is in the `.pkg`. On a fresh machine, install
the three `Imports` first or the first `library(datalib)` fails with a bare
`there is no package called 'fs'`:

```r
install.packages(c("yaml", "haven", "fs"))
```

### `datalib_update()` reports; it does not install

It tells you whether the site holds something newer and returns `status` as
`"current"`, `"newer_available"`, `"source_behind"` or `"unknown"`. It deliberately
does **not** install: `install.packages()` over a loaded namespace is unsafe on
Windows, where the running session locks the package's own files. Run the install
line yourself, then restart the session — the R equivalent of Stata's `discard`.

## Install

```r
install.packages(c("yaml", "haven", "fs"))
```

**Option A: install the package** (from the public distribution repository):

```r
remotes::install_github("unicef-drp/datalib-unicef", subdir = "r")
library(datalib)
```

**Option B: source from a clone, without installing.** Two things bite here, so the
snippet is defensive rather than short:

```r
clone <- "C:/GitHub/mytasks/datalib-unicef"   # <- your clone, absolute

src <- list.files(file.path(clone, "r", "R"), pattern = "[.]R$", full.names = TRUE)
stopifnot(length(src) > 0)                    # fails loudly on a wrong path
invisible(lapply(src, source))

# The collection registry ships inside the package, so a sourced copy has to be
# told where it is. Without this, anything taking collection= cannot resolve.
options(datalib.collections.path = file.path(clone, "r", "inst", "collections.yml"))
```

Why not the one-liner `lapply(list.files("r/R", full.names = TRUE), source)`: with a
relative path and the wrong working directory, `list.files()` returns `character(0)`,
`lapply()` returns an empty list, **and nothing reports a problem** -- the next call
then fails with `could not find function "datalib_resolve"`, which points at the
wrong thing entirely. The `stopifnot()` turns a silent no-op into an error at the line
that caused it.

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
