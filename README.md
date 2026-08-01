# datalib
UNICEF Microdata Library · repo: `unicef-drp/datalib-unicef` · command: `datalib`

> **This is the UNICEF adaptation of `datalib`.** It is prepared and adapted for
> UNICEF, and builds on joint work by João Pedro Azevedo and Minh Cong Nguyen.
> It is built **from** the canonical generic package and paper at
> **`jpazvd/datalib-dev`**, whose public release is
> **[jpazvd/datalib](https://github.com/jpazvd/datalib)** — see
> [Provenance](#provenance).

Standardized survey-microdata library manager with versioned master and harmonized datasets, featuring interactive SMCL-based folder navigation.

**Why datalib?** Survey microdata is expensive to collect but cheap to reanalyze, yet it is usually managed far less rigorously than code — parked on a shared drive in an ad-hoc folder, with its citation and version living only in a colleague's memory. `datalib` treats microdata as a versioned, first-class asset: it encodes an [IHSN](https://www.ihsn.org/)-aligned folder and naming convention (`CCC_YYYY_SSSS_vNN_M` for master files, `..._vNN_A_HHHH` for harmonized adaptations) as executable Stata, so any dataset resolves from a country, year, and survey acronym — and the data loaded today is provably the same data a colleague's paper used last year. A draft design paper (Azevedo & Nguyen, working draft) gives the full rationale; see [Documentation](#documentation).

📖 **Documentation hub:** [docs/README.md](docs/README.md) — all guides, the design paper, the reference library, and the governance proposal.

## Contents

- [Installation](#installation)
- [Dependencies](#dependencies)
- [Quick Start](#quick-start)
- [Key Features](#key-features)
- [Data Organization Convention](#data-organization-convention)
- [Documentation](#documentation)
- [Project Structure](#project-structure)
- [Troubleshooting](#troubleshooting)
- [Contributing & Issues](#contributing--issues)
- [Related Projects](#related-projects)
- [Provenance](#provenance)
- [Version History](#version-history)
- [License](#license)
- [Citation](#citation)
- [Contact & Support](#contact--support)

---

## Installation

### Stata — install from a clone (Recommended)

This repository is currently **private**, so `net install` from the raw GitHub URL
cannot work (Stata sends no authentication). Clone the repo, then:

```stata
global datalib_clone "C:/path/to/datalib-unicef"
net install datalib, from("${datalib_clone}/stata") replace
```

UNICEF colleagues on the CSO share can install from the LAN net site instead,
which is rebuilt from the tagged release each time:

```stata
net install datalib, from("Z:/_pkg/datalib/stata") replace
```

If/when the repository is made public, the web one-liner becomes available
unchanged. The path below is already correct — `stata.toc` and `datalib.pkg` sit
at `stata/`, and the manifest's `f` entries resolve beneath it — so only the
repository's visibility stops it resolving (an anonymous request currently gets
HTTP 404, not a bad path):

```stata
net install datalib, from("https://raw.githubusercontent.com/unicef-drp/datalib-unicef/main/stata") replace
```

> **Upgrading from ≤ 0.4:** the package root moved from `02_programs/src` to `stata/`, so
> `adoupdate datalib` against any old location will fail. `ado uninstall datalib`, then
> reinstall once from your clone; updates track the new location from then on.

### R package

```r
# from a clone:
install.packages(c("yaml", "haven", "fs"))
# load without installing (or use remotes::install_github(..., subdir = "r")):
lapply(list.files("r/R", full.names = TRUE), source)
datalib_resolve("ZWE", 2019, "MICS", collection = "HLT", root = "Z:/datalib")
```

Full usage, configuration and parity notes: [`r/README.md`](r/README.md).

### Python package

```bash
pip install ./python          # or, once published: pip install unicef-datalib
python -m datalib ls --root Z:/datalib
```

(Same functions, same semantics — see [config/grammar.md](config/grammar.md).)

### Verify Installation

```stata
* Check that datalib is installed
help datalib

* Confirm the package resolves a library and answers
datalib root, find        // reports the library it resolved, and from where
datalib countries         // lists the country folders it can see
```

---

## Dependencies

The Stata package is **self-contained** — the `datalib` command and every `datalib_*` wrapper run with no user-written dependencies. Point them at a library root via `${datalib}`, the `DATALIB_ROOT` environment variable, or the `datalib:` key in `~/.config/user_config.yml` (read by [`getuserconfig`](stata/src/g/getuserconfig.ado) / `datalib_config`, which fills `${datalib}` when unset).

`profile_datalib.do` is the **project profile for this repository's own workflows**, not part of the installed package: it expects your username in its per-user block (it stops for unknown users), installs the analysis packages the workflow do-files use, and sets the project globals. Package users do not need it.

---

## Quick Start

### Basic Usage

After installation, configure the data root and start using datalib:

```stata
* Step 1: point datalib at your microdata tree. Any of these work:
global datalib "Z:/datalib"        // the library itself
global datalib "Z:/"              // the place holding it — datalib finds it
*                                  // or set a datalib: key in your user config,
*                                  // or nothing at all and let discovery try Z:/

* Step 2: load data
datalib, country(ZWE) year(2019) survey(MICS) collection(HLT)

* Step 3: explore
describe
datalib                            // interactive folder navigation (no arguments)

* Work in another library for one call — this wins over everything above
datalib, library(Z:/datalib-hlt) country(ZWE) year(2019) survey(MICS) collection(HLT)

* Or call the scriptable API through the same command
datalib countries
datalib resolve, country(ZWE) year(2019) survey(MICS) kind(master)
datalib load, country(ZWE) year(2019) survey(MICS) collection(HLT) modules(household) clear
```

If no library can be found, `datalib` stops with an actionable error naming
`library()` — it does not fail later with a bare `directory not found`. A path
that exists but is not a library is refused rather than accepted, so a missing
library cannot quietly resolve to its parent.

### First-Time Setup Checklist

1. ✅ **Bootstrap your configuration:** `datalib config, init profile`

   Writes `~/.config/user_config.yml` prepopulated with everything Stata can
   detect — your username, `githubFolder` from `whereis github`, the Z: drive and
   its UNC from `mapzdrive, discover`, and the library itself — plus a startup
   `profile.do` so every session loads it. Anything it cannot determine
   unambiguously is left as a commented `TODO` with the candidates listed, and the
   file is opened so you can finish it. Nothing is ever overwritten: an existing
   block is kept, an existing `profile.do` is left alone, and a file holding other
   operators' blocks is only appended to. Running `profile_datalib.do` from the
   clone does this for you when no configuration exists. See `help _uc_init`.
2. ✅ Verify installation: `help datalib`, then `datalib root, find`
3. ✅ Browse interactively: `datalib`
4. ✅ Load your first dataset: `datalib, country(ZWE) year(2019) survey(MICS) collection(HLT)`

If you would rather not keep a config file, set the root per session instead:
`global datalib "Z:/datalib"` (or the folder holding it), or pass
`library(<path>)` on any `datalib` call.

---

## Key Features

✅ **Standardized Naming Convention** - Consistent organization: `CCC_YYYY_SSSS_vNN_M_vMM_A_COLLECTION`

✅ **Interactive Folder Navigation** - SMCL-based navigation provides GUI-like browsing within Stata

✅ **Master & Adaptation Versioning** - Track both original (Master) and harmonized (Adaptation) datasets

✅ **Multi-Collection Support** - registry-backed module definitions and merge keys for the **HLT** and **IPUMS** collections ([config/collections.yml](config/collections.yml)); other harmonization families (ECAPOV, GLAD, …) follow the folder convention and load per-module/per-file

✅ **One Front Door** - `datalib <subcommand>` dispatches to the whole contract API (`datalib countries`, `datalib resolve, …`, `datalib load, …`) — the same 13 functions available in R and Python

✅ **Say Which Library** - `library()` names the library for a call, and may name either the library or the folder holding it; a path that is not a library is refused, never silently accepted

✅ **Self-Configuring** - `datalib config, init profile` writes a prepopulated user config and a startup `profile.do`, detecting what it can and flagging only what it cannot; nothing is ever overwritten

✅ **Programmatic Access** - Return macros enable scripted workflows and integration with other packages

✅ **Automatic Module Merging** - Intelligent merging of household, individual, and demographic modules by collection

✅ **Ingestion-Agnostic** - No assumption about the data source; works with MICS, DHS, LSMS, IPUMS, and any survey that follows the IHSN identifier

---

## Data Organization Convention

DATALIB uses a rigorous convention organized by country (ISO-3166 alpha-3 code), year, and survey type.

### Folder Structure

```
datalib/
├── CCC/                                          # Country folder (ISO-3 code)
│   └── CCC_YYYY_SSSS/                            # Survey folder
│       ├── CCC_YYYY_SSSS_vNN_M/                  # Master (data as received)
│       │   ├── Data/
│       │   │   ├── Original/                     # Raw, as-received (native format)
│       │   │   ├── Stata/                        # Converted .dta
│       │   │   ├── R/                            # Converted .rds / .RData
│       │   │   └── Other/                        # Any other machine-readable formats
│       │   ├── Doc/                              # Questionnaire, report, manuals, technical notes
│       │   └── Programs/                         # Data-preparation scripts
│       │
│       └── CCC_YYYY_SSSS_vNN_M_vMM_A_HHHH/       # Adaptation (harmonized)
│           ├── Data/{Original,Stata,R,Other}/
│           ├── Doc/
│           └── Programs/
```

### Naming Components

**Survey Folder:** `CCC_YYYY_SSSS`
- **CCC** = ISO-3166 alpha-3 country code (e.g., ZWE, ALB, TJK; or WLD / a regional code)
- **YYYY** = Survey year (4 digits)
- **SSSS** = Survey acronym (MICS, DHS, LSMS, …)

**Master File:** `CCC_YYYY_SSSS_v01_M`
- **v01_M** = Version 01, Master file
- Subsequent versions: v02_M, v03_M, etc.

**Adaptation File:** `CCC_YYYY_SSSS_v01_M_v01_A_HLT`
- **v01_A_HLT** = Adaptation version 01 for the HLT collection
- Other collections: IPUMS, ECAPOV, GLAD, …

**Example:** `TJK_2009_TLSS_v01_M_v01_A_HLT` = Tajikistan 2009 Living Standards Survey, master v01, HLT adaptation v01

### File naming inside the folders

Files inside each vintage folder fall into three groups:

**1. Harmonised microdata — `Data/Stata/` and `Data/R/`.** Converted/harmonised data files, named to match the folder plus the module: `CCC_YYYY_SSSS_<vintage>_<module>.dta` (Stata) or `.rds` / `.RData` (R).
- Example: `ZWE_2019_MICS_v01_M_v01_A_HLT_household.dta`
- Modules are **collection-specific** (see [config/collections.yml](config/collections.yml)) — HLT: `household`, `hhmembers`, `adult`, `children`; IPUMS: `hh`, `bh`, `ch`, `fs`, `hl`, `mn`, `wm`.
- `Data/Other/` holds any additional machine-readable formats that are neither the untouched original nor the harmonised Stata/R files.

**2. Original data — `Data/Original/`.** Raw microdata **exactly as received** from the producer, in its native format (SPSS `.sav`, Stata `.dta`, CSV, …). **Keep the producer's original filenames** — do not rename or convert. This is the untouched source of truth.

**3. Non-microdata files — `Doc/` and `Programs/`.** Everything that is not survey microdata: the core survey report, questionnaire, interviewer manual, interview instructions and technical notes (`Doc/`), and any data-preparation scripts (`Programs/`). Use descriptive names, e.g. `CCC_YYYY_SSSS_questionnaire.pdf`, `CCC_YYYY_SSSS_report.pdf`.

---

## Documentation

### datalib itself

- **`help datalib`** — full command documentation (after installation)
- **[stata/workflows/README.md](stata/workflows/README.md)** — comprehensive guide to the Stata workflows (organization, harmonization)
- **[.github/copilot-instructions.md](.github/copilot-instructions.md)** — developer guide with architecture, patterns, and improvement plans
- **IMPROVEMENT_PLAN.md** — technical roadmap for v2.0+ (YAML configuration, catalog frame, optimization)
- **[config/grammar.md](config/grammar.md)** — contract v1: the shared `datalib_*` API semantics (Stata/R/Python), with the collection registry in [config/collections.yml](config/collections.yml) and golden conformance cases in [tests/](tests/DIVERGENCES.md) (`help datalib_api` after install)

### Design paper — working draft (motivation & framework)

- **Azevedo, J. P. & Nguyen, M. C. _Harmonized Microdata Access with datalib: A Framework for Survey Data Management in Stata._ Working draft — unpublished, not yet submitted anywhere.** The authoritative deep dive on datalib's design principles, the IHSN/DDI-aligned naming convention, the frame-backed catalog, and the planned access-control/audit layer. Maintained in `paper/` in [jpazvd/datalib-dev](https://github.com/jpazvd/datalib-dev), which is also the canonical generic package this repository is built from; see [Provenance](#provenance) and [Citation](#citation).

### Reference documentation library

The external standards and workflow designs that datalib's conventions and collections build on — cited below but not redistributed with this package (see LICENSE):

- **ECAPOV Harmonization Guideline** (World Bank ECATSD, 2014) — source standard for the ECAPOV collection.
- **GLAD Harmonization Guideline** (World Bank EduAnalytics, 2022) — source standard for the GLAD collection.
- **Handbook: Poverty & Inequality Measures in Practice** (World Bank LAC TSD) — the LAC precursor of the "Data Library" folder structure and the `-datalib-` command.
- **ECATSD Microdata Workflow (V1)** and **Workflow — Light Design** — the upstream deposit → review → promote lifecycle behind the governance model.

### Architecture & governance

- **Architecture** — the folder/naming convention is summarized in [Data Organization Convention](#data-organization-convention) above; the design paper is the full treatment (IHSN alignment, catalog frame, master-vs-adaptation versioning). Its lineage traces to the LAC "Data Library" handbook and the ECATSD microdata workflow (see the reference library).
- **Governance** — **[docs/GOVERNANCE_microdata_deposit.md](docs/GOVERNANCE_microdata_deposit.md)**: the microdata-deposit governance proposal, built around the **stock vs flow** split (deposit the flow following this repo's structure; deposit the stock as-is into the Z: staging area), with an additive, non-breaking review gate — the Chief Statistician accountable, delegating day-to-day process guidance to a Unit Chief.

---

## Project Structure

Mirrors the unicefData-dev trilingual house layout (`stata/ r/ python/ scripts/ config/ docs/ tests/`):

```
datalib-unicef/
├── stata/                   # The ado package (net-install root: datalib.pkg, stata.toc)
│   ├── src/{d,g,m,_}/       # Commands + help: datalib, 13 datalib_* wrappers, config/drive, internals
│   ├── doc/                 # Installation + file-organization guides
│   ├── tests/               # Stata leg of the conformance suite (run from repo root)
│   └── workflows/           # Project do-files (HLT / MICS-IPUMS imports, benchmark)
├── r/                       # R package "datalib" (shared datalib_* API, README.md)
│   ├── DESCRIPTION, NAMESPACE, LICENSE
│   ├── R/                   # One file per exported datalib_* function + internal utils
│   ├── man/                 # Roxygen-generated help pages (?datalib_resolve, …)
│   ├── inst/                # collections.yml — byte-synced copy of config/collections.yml
│   └── tests/testthat/      # Conformance (shared golden cases) + doc-truth + unit tests
├── python/                  # Python package "unicef-datalib" (same API; import datalib)
│   ├── pyproject.toml, README.md
│   ├── src/datalib/         # errors, config, grammar, registry, catalog, io, load, create,
│   │                        #   drive, CLI (python -m datalib) + byte-synced collections.yml
│   └── tests/               # Conformance (same golden cases) + doc-truth + package tests
├── scripts/
│   ├── py/                  # Generic Python file-management utilities
│   └── ps/                  # PowerShell Z:-sync toolbox (robocopy + scheduler)
├── config/                  # The contract: grammar.md + collections.yml + user_config.yml template
├── docs/                    # Guides, reference library, governance, inventories
├── tests/                   # Conformance kit: fixture library + golden cases + Stata harness
├── data/                    # Local data root (hosted_in_repo inputs; demo tree untracked)
├── internal/                # Plans and generated operator reports
├── .github/
│   ├── workflows/conformance.yml   # CI: R + Python legs of the shared conformance suite
│   └── copilot-instructions.md
├── CHANGELOG.md  CONTRIBUTING.md  IMPROVEMENT_PLAN.md
├── profile_datalib.do  run_datalib.do
├── README.md                # This file
└── LICENSE
```

---

## Troubleshooting

### `command datalib not recognized` / helper command not found

**Cause:** The package (or a required helper) is not installed.

**Solution:** Run `profile_datalib.do` from the clone root — it installs the required user-written packages and sets `${datalib}`. Or reinstall: `net install datalib, from("…/stata") replace`.

### `No datalib library at: …` / `No datalib library found` (rc 198)

**Cause:** the library could not be resolved — nothing is configured, or what is
configured does not exist or is not a library. Since v0.9.0 this is reported up
front instead of surfacing later as `directory … not found`.

**Solution:** name the library, for one call or for the session:
```stata
datalib, library(Z:/datalib) country(ZWE)   // one call; may also name the folder holding it
datalib root, root(Z:/datalib) find set     // for the rest of the session
datalib config                              // or read a datalib: key from your user config
```
A directory that exists but is not a library is refused on purpose: accepting it
would make the library's parent resolve, and its sibling folders would then be
read as country codes.

### Data not loading correctly

**Cause:** May be missing collection-specific modules or an incorrect path.

**Solution:**
```stata
datalib          // browse the structure interactively
datalib vintages, country(ZWE) year(2019) survey(MICS)   // what is actually on disk
help datalib
```

For detailed troubleshooting, see [.github/copilot-instructions.md](.github/copilot-instructions.md).

---

## Contributing & Issues

This is an active development project. For issues, feature requests, or questions:

1. Check IMPROVEMENT_PLAN.md to see if your feature is already planned
2. Review [.github/copilot-instructions.md](.github/copilot-instructions.md) for development patterns and conventions
3. See [stata/workflows/README.md](stata/workflows/README.md) for workflow documentation

---

## Related Projects

Part of the UNICEF Chief Statistician Office (CSO) data ecosystem:

- **CSO Toolkit** — the CSO's Stata toolkit; `datalib`'s onboarding tooling (`getuserconfig`, `mapzdrive`) and loader are slated to migrate here (with the `dw_*` prefix).
- **CSO Handbook** — the CSO's methods / estimation handbook (the UNICEF counterpart to the LAC handbook `datalib` descends from).
- **unicefData** — UNICEF data-access package for indicators and survey outputs.

Lineage and related World Bank projects (see also the reference library):

- **`jpazvd/datalib-dev`** — the canonical generic package and the home of the design paper; **this repository is built from it**. See [Provenance](#provenance).
- **[jpazvd/datalib](https://github.com/jpazvd/datalib)** — the public release of that generic package; a three-language `dl_*` verb API, **not** this repository's `datalib_*` contract surface. Start here if you are not at UNICEF.
- **[datalibweb](https://github.com/worldbank/datalibweb)** — the World Bank's Stata frontend for its harmonized-microdata API; `datalib`'s closest architectural sibling.
- **[GLAD](https://github.com/worldbank/GLAD)** — Global Learning Assessment Database: harmonized learning-assessment datasets (the standard behind the GLAD lineage documented in the reference library).
- **[SARMD](https://github.com/worldbank/SARMD)** — South Asia Regional Micro Database: harmonization do-files for the SARMD collection.
- **[SARMD guidelines](https://github.com/worldbank/SARMD_guidelines)** — technical guidelines for the SAR microdata base.
- **[SARMD Harmonized Household Surveys](https://github.com/worldbank/SARMD_Harmonized_Households_Surveys)** — harmonization of household surveys (HIES) for the South Asia Region.
- **[SAR Labor Force Surveys](https://github.com/worldbank/SAR_LaborForceSurveys)** — harmonization codes for Labor Force Surveys in the South Asia Region.

---

## Version History

See **[CHANGELOG.md](CHANGELOG.md)** for the full history. Current: **v0.9.29** —
the R package passes `R CMD check --as-cran` and the Python package carries full
PyPI metadata, so both are submittable; the public distribution repository
([unicef-drp/datalib-unicef](https://github.com/unicef-drp/datalib-unicef)) is live
and the documented web `net install` works. Earlier, v0.9.19 —
the net site is now `Z:/_pkg/datalib` and is the only supported install path,
`datalib , update` reports the copy actually on the adopath, and every `*!` stamp
is pinned to the release that last changed the file. Earlier, v0.9.3 —
`datalib` becomes the front door: subcommand dispatch to the contract API, a
`library()` option, and library resolution that accepts either the library or the
folder holding it while refusing anything that is not a library. Built on v0.8.0's
two-file config seam and v0.7.0's package-first multi-language layout with the
shared `datalib_*` API in Stata, R, and Python (one conformance suite).

---

## License

MIT — see the [LICENSE](LICENSE) file for the full terms.

---

## Provenance

`datalib` began as joint work by **João Pedro Azevedo** and **Minh Cong Nguyen** on
treating survey microdata as a versioned, citable asset — the folder and naming
grammar, the resolver, and the harmonized-adaptation model that this package still
rests on. That design is written up in the working draft cited under
[Citation](#citation).

### Lineage

```
jpazvd/datalib-dev                 canonical generic package + the paper
        |                          (upstream of everything below)
        |
        +--> jpazvd/datalib        public release of the generic package
        |
        +--> unicef-drp/datalib-unicef      <-- this repository
                                   the UNICEF adaptation
```

Three repositories carry this work. They are **not** interchangeable, and the
direction of descent matters:

| repository | role |
|---|---|
| **`jpazvd/datalib-dev`** | The **canonical** repository: the generic package **and** the home of the design paper (`paper/`). Everything below is built **from** here, so this is where a change to the generic resolver, grammar or contract belongs. Private. |
| **[jpazvd/datalib](https://github.com/jpazvd/datalib)** | The **public release** of the generic package — a three-language (Stata, R, Python) `dl_*` verb API. It does **not** carry contract v1, the `config/` registry, or this repository's `datalib_*` surface. Start here if you are not at UNICEF. |
| **`unicef-drp/datalib-unicef`** (this repository) | The **UNICEF adaptation**, built from `datalib-dev`: the UNICEF collection registry (`HLT`, `IPUMS`), the CSO configuration and drive-mapping conventions, the deposit governance, and the UNICEF fixture and conformance suite. |

Two consequences worth stating, because getting them wrong wastes work:

- **Generic changes belong upstream.** A fix to the folder grammar, the resolver or
  the language-neutral contract should land in `datalib-dev` and flow down; making
  it here first means it has to be re-made upstream, and the two can silently
  diverge in between. UNICEF-specific configuration is the opposite: it belongs
  here and should never be pushed up.
- **`-dev` is the editable one.** Per the workspace convention, `<repo>-dev` is
  where work happens and the un-suffixed repository is the published release, not
  a place to commit into.

What "adapted for UNICEF" means concretely: the language-neutral contract in
[`config/grammar.md`](config/grammar.md) is deliberately organisation-neutral, and
everything UNICEF-specific is isolated in configuration rather than in the
resolver — the collection registry
([`config/collections.yml`](config/collections.yml)), the per-operator config
([`config/user_config.yml`](config/user_config.yml)), and the deposit governance
([`docs/GOVERNANCE_microdata_deposit.md`](docs/GOVERNANCE_microdata_deposit.md)).
That separation is what keeps the two packages able to converge.

## Citation

If you use DATALIB in your research, please cite the design paper — note it is an
**unpublished working draft** (not submitted or forthcoming anywhere), so cite it
as a draft:

```bibtex
@unpublished{azevedo2026datalib,
  author = {Azevedo, Jo{\~a}o Pedro and Nguyen, Minh Cong},
  title  = {Harmonized Microdata Access with {datalib}: A Framework for
            Survey Data Management in {Stata}},
  year   = {2026},
  note   = {Unpublished working draft.
            Package: \url{https://github.com/unicef-drp/datalib-unicef}}
}
```

To cite the software directly:

```bibtex
@misc{azevedo2024datalib,
  author = {Azevedo, João Pedro},
  title = {DATALIB: Standardized Survey Microdata Library Manager},
  year = {2024},
  publisher = {UNICEF},
  howpublished = {GitHub Repository},
  url = {https://github.com/unicef-drp/datalib-unicef}
}
```

---

## Contact & Support

**Author:** Joao Pedro Azevedo (jpazevedo@unicef.org)

**Documentation:**
- Help: `help datalib` (after installation)
- Detailed guides: See [Documentation](#documentation) section
- Developer info: See [.github/copilot-instructions.md](.github/copilot-instructions.md)

**Last Updated:** 2026-08-01  
**Current Version:** 0.9.29  
**Repository:** https://github.com/unicef-drp/datalib-unicef

---

[↑ Contents](#contents) · [Documentation hub](docs/README.md)
