# datalib — developer guide

[← datalib README](../README.md) · [Documentation hub](../docs/README.md)

## Contents

- [Project overview](#project-overview)
- [Repo map](#repo-map)
- [The contract](#the-contract)
- [Command surface (Stata)](#command-surface-stata)
- [Return values](#return-values)
- [Per-language dev workflow](#per-language-dev-workflow)
- [Key gotchas](#key-gotchas)
- [Branch & PR conventions](#branch--pr-conventions)
- [Plans & history](#plans--history)

## Project overview

**datalib** manages standardized survey-microdata libraries: versioned **master**
(`CCC_YYYY_SSSS_vNN_M`) and harmonized **adaptation**
(`..._vMM_A_<COLLECTION>`) folders resolved from a country, year, and survey
acronym. Since v0.5.0 it is a **trilingual suite**: one language-neutral
contract ([config/grammar.md](../config/grammar.md) +
[config/collections.yml](../config/collections.yml)) implemented by a Stata ado
package (`stata/`), an R package (`r/`), and a Python package (`python/`), all
passing the **same golden conformance cases** in `tests/`.

The repository (`unicef-drp/datalib-unicef`) is currently **private**: Stata's
`net install` from the raw GitHub URL cannot work (no authentication is sent).
Install from a clone: `net install datalib, from("<clone>/stata") replace`.

Design paper: Azevedo & Nguyen, unpublished working draft (not submitted anywhere).

## Repo map

```
stata/                # The ado package (net-install root: datalib.pkg, stata.toc)
  src/d/              #   datalib.ado + the 13 datalib_* wrapper commands (+ .sthlp)
  src/g/  src/m/      #   getuserconfig · mapzdrive (per-operator config / Z: mapping)
  src/_/              #   internals: _dlw (loader engine), _foldernav, _mkdir, checks
  tools/              #   maintenance do-files, not shipped in datalib.pkg
  workflows/          #   project do-files (HLT / MICS-IPUMS imports, 9999 benchmark)
r/                    # R package "datalib" (same API; testthat suite)
python/               # Python package "unicef-datalib", import datalib (pytest suite)
scripts/py/  ps/      # Generic Python file utilities · PowerShell Z:-sync toolbox
config/               # THE CONTRACT: grammar.md + collections.yml + user_config template
docs/                 # Documentation hub (docs/README.md), reference PDFs, governance
tests/                # Conformance kit: golden cases + fixture library + Stata harness
internal/             # Working records (REORGANIZATION.md) and generated reports
.github/workflows/conformance.yml   # CI: R + Python conformance legs
```

`profile_datalib.do` is the project profile for this repo's own workflows (per-user
paths, analysis packages); it is **not** part of the installed package.

## The contract

[config/grammar.md](../config/grammar.md) is the language-neutral semantics —
read it before touching any resolver/loader:

- **Folder grammar**: master vintage = 5 `_`-separated tokens, adaptation = 8;
  inside a vintage: `Data/{Original,Stata,R,Other}`, `Doc/`, `Programs/`.
- **Uppercase once at the boundary**; matching is exact (country) or
  exact-suffix (survey) — never substring.
- **Vintages are integers**: inputs accept `1`/`01`/`v01`/`V01`; "latest" is the
  numeric maximum, never listing order. Defaults resolve from folders that
  actually exist, and the resolved vintage folder is verified pre-load.
- **Loaders never mutate data.** Two documented schema additions only:
  registry `linevar` → `line_number` rename, and provenance columns
  `ctrycode` + `year` added when absent (never overwritten) on **every** load,
  master and adaptation alike.
- **Merge**: person modules chain `1:1` on `keys_person`, hh modules attach
  `m:1` on `keys_hh`; keys validated per module (`isid`-equivalent) — failure
  stops with a typed error, never a row-order merge.
- **Error taxonomy** mapped per language (Stata 198/601/459 · R condition
  classes · Python exceptions) — grammar.md §6.
- **Root resolution** (Stata): `root()` option → `${datalib}` global (filled by
  `getuserconfig`/`datalib_config` from the `datalib:` config key when unset) →
  env `DATALIB_ROOT` → error. R/Python: argument → `DATALIB_ROOT` → language
  option → `datalib:` key in `~/.config/user_config.yml` → error. In all three
  this default is pure candidate selection — the path is **not** checked on disk.
  The **spelling** differs by design (Stata literal · R normalised · Python a
  `Path`), so never assert a returned root byte-for-byte across languages —
  compare normalised paths. grammar.md §7.
- **`find` mode** (Stata only, opt in; used by the `datalib` command): resolves
  the candidate against the disk — accepts the library or its container
  (`<cand>/datalib` first), refuses a directory that is not structurally a
  library, errors rather than substituting when a configured root is missing,
  and discovers a library named `datalib` under `${zDrive}`/`Z:/` only when
  nothing is configured (`source_stage` `discovered`). Specified in
  grammar.md §7; see also [tests/DIVERGENCES.md](../tests/DIVERGENCES.md).

[config/collections.yml](../config/collections.yml) is the **single source of
truth** for module lists, levels, `linevar`, and merge keys (HLT
`keys_hh: svy_id cluster_id household_id`; IPUMS `svy_id household_id`).
R and Python consume **byte-identical synced copies** (`r/inst/collections.yml`,
`python/src/datalib/collections.yml` — each suite asserts equality). The
**Stata leg mirrors the registry by hand** inside `stata/src/_/_dlw.ado` (no YAML
parser): any registry edit MUST be mirrored there; the shared conformance
cases are the drift guard.

### Conformance kit & test suites

- Golden cases: `tests/cases_resolve.csv` (12) + `tests/cases_load.csv` (6) run
  against the committed fixture library `tests/fixtures/library/`. Deliberate
  divergences from pre-0.5 behavior: [tests/DIVERGENCES.md](../tests/DIVERGENCES.md).
- **Stata harness** (122 cases across ten parts — 34 cross-language golden cases
  plus the Stata-only front-door, library-resolution, config-bootstrap, surface
  and update cases): from the repo root,
  `do "stata/tests/run_conformance.do"`
  — it `run`s the wrappers from the working tree (no reinstall needed) and
  exits with error 9 on any failure.
- **R** (237 tests): `Rscript -e 'testthat::test_dir("r/tests/testthat", stop_on_failure = TRUE)'`
- **Python** (311 tests + 1 xfail): `python -m pytest python/tests -q`
- **Doc-truth tests** (since v0.5.1): R `man/` pages and Python docstrings are
  mechanically checked — documented parameters must match the real signatures
  and export sets must match the contract. Changing a signature without its docs
  fails the suite.
- **CI** ([.github/workflows/conformance.yml](workflows/conformance.yml)): R +
  Python legs on push/PR to `main`/`dev` (Python 3.10 & 3.12). Stata cannot run
  in CI (no license) — the harness is a **manual, local release gate**.

## Command surface (Stata)

The legacy surface is **options-only**; in addition, `datalib` takes a
**subcommand** as its first token, dispatching to the matching `datalib_*`
wrapper (exact, lowercase, no abbreviation):

```stata
global datalib "Z:/datalib"     // or env DATALIB_ROOT, or the datalib: config key

datalib, country(ZWE) year(2019) survey(MICS) collection(HLT)  // load + merge HLT modules
datalib                          // no options: interactive SMCL folder navigation
datalib, country(ZWE)            // navigation scoped to one country
datalib, library(Z:/datalib-hlt) country(ZWE)   // name the library for this call
datalib, library(Z:/) country(ZWE)              // name the place holding it

datalib countries                // subcommand form -> datalib_countries
datalib resolve, country(ZWE) year(2019) survey(MICS) kind(master)
```

`library()` applies to the legacy surface and publishes the resolved library to
`${datalib}` (the clickable navigation links carry no options, so they must find
the same library next call). The subcommand form delegates root resolution to the
wrapper, which takes `root()` per call and does not touch the global.

The 13 contract wrappers (`help datalib_api` after install; same names in R and
Python — Python additionally exports `getuserconfig`/`mapzdrive` aliases):

| Command | Required options | Notes |
|---|---|---|
| `datalib_config` | — | wraps `getuserconfig`; fills `${datalib}` from the config key; `init` bootstraps a prepopulated config (+ `profile` for a startup `profile.do`) |
| `datalib_root` | — | resolve (and optionally `set`) the library root; `find` opts into disk resolution |
| `datalib_countries` | — | list country folders |
| `datalib_surveys` | `country()` | survey folders; latest year/survey |
| `datalib_vintages` | `country() year() survey()` | masters + adaptations on disk |
| `datalib_adaptations` | `country() year() survey()` | collections with adaptations |
| `datalib_resolve` | `country()` | pure path resolution — touches no data |
| `datalib_files` | `country()` | list one section: `data`, `data-original`, `data-r`, `data-other`, `doc`, `programs`; a missing section dir is an **empty listing, not an error** |
| `datalib_catalog` | `clear` | scan tree → one row per vintage folder in memory |
| `datalib_load` | `country()` | thin wrapper over `_dlw`; `modules()`, `kind(master|adaptation)`, `master_version()`→`vm()`, `adaptation_version()`→`va()` |
| `datalib_create` | `country() year() survey()` | **check-mode by default** (reports paths, zero side effects); add `create` to build the tree |
| `datalib_browse` | — | SMCL navigation with `root()`/`path()` control |
| `datalib_map_drive` | — | wraps `mapzdrive` (Z: mapping from config) |

Examples that run against a populated library:

```stata
datalib_resolve, country(ZWE) year(2019) survey(MICS) collection(HLT)
datalib_load, country(ZWE) survey(MICS) modules(household hhmembers) clear
datalib_files, country(ZWE) year(2019) survey(MICS) section(doc)
datalib_catalog, clear
datalib_create, country(ALB) year(2020) survey(MICS)          // dry check
```

Internals (`stata/src/_/`): `_dlw` v1.10 is the loader engine (registry-keyed
`isid`-validated merges, provenance columns, vintage pre-checks); `_foldernav`
is the interactive SMCL navigator; `_mkdir` builds folder trees (**requires**
`path()` and `country()`; the module option is `module()`); `_ctrycheck`/`_svycheck`/
`_vcheck`/`_adaptcheck` validate inputs.

## Return values

`datalib` / `datalib_load` (from `_dlw`): `r(harmonization)` = resolved vintage
folder name; `r(filename1)`…`r(filenameN)` per loaded module/file; with
`filename()`: `r(data1)`/`r(doc1)`/`r(programs1)` full paths per section flag.

`datalib_resolve`: `r(vintage_folder)`, `r(survey_folder)`, `r(file_stem)`,
`r(data_stata)`, `r(data_original)`, `r(data_r)`, `r(data_other)`, `r(doc)`,
`r(programs)`, plus the resolved `r(country)`/`r(year)`/`r(survey)`/`r(kind)`/
`r(collection)`/`r(master_version)`/`r(adaptation_version)`/`r(root)`.

Enumeration wrappers return word lists + counts: `r(countries)`+`r(n)`;
`r(surveys)`+`r(latest_year)`+`r(latest_survey)`; `r(masters)`/`r(adaptations)`
+`r(latest_master)`+`r(has_master)`/`r(has_adaptation)`; `r(collections)`+`r(n)`.
`datalib_files`: `r(files)`, `r(n)`, `r(dir)`, `r(section)`. `datalib_create`:
`r(existed)`, `r(created)`, `r(path)` + the section paths.

## Per-language dev workflow

- **Stata**: edit `stata/src/d/*.ado` or `stata/src/_/*.ado` → from the repo root in
  Stata: `do "stata/tests/run_conformance.do"`. Update the co-located `.sthlp`.
- **R**: edit `r/R/*.R` → `Rscript -e 'testthat::test_dir("r/tests/testthat", stop_on_failure = TRUE)'`.
  Regenerate `man/` (roxygen2) when signatures change — doc-truth tests fail otherwise.
- **Python**: edit `python/src/datalib/*.py` → `python -m pytest python/tests -q`.
  Keep numpy-style docstrings in sync with signatures (doc-truth tests).
- **Registry change**: edit `config/collections.yml` → copy **byte-identical**
  to `r/inst/collections.yml` and `python/src/datalib/collections.yml` →
  hand-mirror in `stata/src/_/_dlw.ado` → run all three suites.
- A behavior change must keep **all implemented languages passing the same
  golden cases**; contract semantics never change in one language alone.

## Key gotchas

1. **`.gitignore` is a deny-all allowlist** (`*` first). New file *types or
   paths* need explicit `!` rules or they are **silently untracked** — this
   bit `LICENSE` and the `data/hosted_in_repo` CSVs once already.
2. **Private repo**: no web `net install`; clone-install only (see README
   "Installation"). The raw-URL one-liner only works if the repo goes public.
3. **Empty directories need `.gitkeep`** — the fixture library's `Doc/`,
   `Programs/`, and empty `Data/*` dirs are kept alive that way; a fixture dir
   without one vanishes from fresh clones and breaks conformance.
4. **Registry byte-sync**: the R/Python copies of `collections.yml` must stay
   byte-identical to `config/collections.yml` (suites assert it), and the Stata
   mirror in `_dlw.ado` must be edited in the same change.
5. **Provenance columns**: every load adds `ctrycode` and `year` when absent
   (never overwrites). Conformance pins this in all three languages — don't
   "clean up" the `cap gen` lines in `_dlw.ado`.
6. **Real-data caveat**: production `ZWE 2019 MICS` HLT `hhmembers` has
   `hh_line_number` 100% missing — unkeyable, so merges including it error **by
   design** (see `tests/DIVERGENCES.md`). The fixtures pin the intended
   behavior with valid keys; don't weaken key validation to make real trees pass.
7. **Loaders never mutate data** — the old `recode windex5 8=.` was removed in
   v0.5.0; collection-specific recodes belong in harmonization code.
8. **Stata CI gap**: green CI ≠ releasable; run the Stata harness locally
   before any release merge.

## Branch & PR conventions

- Base branch is **`dev`**; `main` is the release trunk (the future public
  `net install` URL serves from `main/stata`). Branch off `dev`, PR into `dev`;
  releases merge `dev` → `main`.
- Conventional Commits (`feat:`, `fix:`, `feat!:`/`BREAKING CHANGE:`) + SemVer.
- Update [CHANGELOG.md](../CHANGELOG.md) with user-visible changes
  (see CHANGELOG.md for the current version and history).
- Full contributor rules: [CONTRIBUTING.md](../CONTRIBUTING.md).

### PR protocol: review Copilot's comments before merging

**A green check is not a review.** Copilot's automated review posts *inline comments*
that report no status of their own — CI can be entirely green while unread findings sit
on the diff. Merging without reading them is not a judgement that they were wrong; it is
not having looked.

Before merging any PR, in this order:

1. **Fetch the comments.** They are not in `gh pr view`:

   ```bash
   gh api "repos/<owner>/<repo>/pulls/<n>/comments" \
     -q '.[]|"--- \(.user.login)  \(.path):\(.line//.original_line)\n\(.body)\n"'
   ```

   Check the *base* PR and the release PR separately — `dev` → `main` gets its own
   review, and it has caught things the feature PR did not.

2. **Disposition every comment**, one of three ways, in the CHANGELOG entry or a PR
   reply: **accepted** (fixed), **accepted with a correction to the finding** (the defect
   is real, the diagnosis is not — say what actually broke), or **rejected with the
   measurement that rejects it**. Never rejected on plausibility: 0.9.29 rejected two
   `max_depth` findings by *running* a four-level tree, and 0.9.32 upheld one whose named
   PR was wrong but whose defect was real.

3. **Do not merge with unaddressed comments**, including on the release PR.

Why this is written down: the 0.9.31 release merged **nine inline comments across six
PRs, unread**. One of them was the release's most consequential defect — withholding
`test_stamps.py` from the public tree dropped two checks that needed no git history and
guarded what `which datalib` reports to whoever installed it. CI could not catch it, by
construction: the tests were gone, and an absent test reports nothing. The reviewer that
did catch it had said so on the diff, twice, before either PR merged.

The bot is wrong often enough that step 2 has three outcomes rather than two — but
"often wrong" is an argument for reading it, not for skipping it.

## Plans & history

- internal/REORGANIZATION.md — the executed
  reorganization + trilingual-parity record (phases, locked decisions, PR #7–#12).
- IMPROVEMENT_PLAN.md — the pre-v0.5 roadmap. Large
  parts are **superseded** (the shipped contract in `config/` differs from its
  Part 1/6 YAML schema); check its status banner before implementing anything
  from it. Parts 3.1, 3.3, 7, and 8 remain live.
- [CHANGELOG.md](../CHANGELOG.md) — authoritative release history.

---

**Last updated**: 2026-07-25 (documents v0.9.3)

---

[← datalib README](../README.md) · [Documentation hub](../docs/README.md)
