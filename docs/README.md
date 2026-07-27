# datalib documentation

[← datalib README](../README.md)

The navigation hub for all `datalib` documentation — guides, architecture and
governance, the reference library, the design paper, and generated inventories.

## Guides

- [Installation](../stata/doc/INSTALLATION.md) — install the ado package
- **First run on a machine:** `datalib config, init profile` writes a prepopulated `~/.config/user_config.yml` and a startup `profile.do`, filling in everything Stata can detect. `profile_datalib.do` does it for you when no configuration exists ([`help _uc_init`](../stata/src/_/_uc_init.sthlp))
- [Programs & workflows](../stata/workflows/README.md) — every Stata workflow (import, organize, harmonize)
- [Python utilities](../scripts/py/README.md) — generic file-management utilities
- [PowerShell utilities](../scripts/ps/README.md) — the Z:-sync toolbox (robocopy + scheduler)
- Package source layout: [stata package readme](../stata/README.md) · [file organization](../stata/doc/FILE_ORGANIZATION.md) · [organization summary](../stata/doc/ORGANIZATION_SUMMARY.md)
- [Developer guide](../.github/copilot-instructions.md) — architecture, patterns, conventions
- [R package](../r/README.md) (`r/`) and [Python package](../python/README.md) (`python/`) — the same `datalib_*` API in R and Python; per-language parity is tracked in the [Alignment status table](../config/grammar.md#alignment-status)
- [Changelog](../CHANGELOG.md) — release history · [Contributing](../CONTRIBUTING.md) — workflow, repo shape, verification rules

## Command reference (Stata)

Every command ships a help file; `help <name>` after install. The `datalib_*`
family is the language-neutral contract, implemented identically in R and Python.

**Front door** — one command reaches the whole API:

| command | what it does | help |
|---|---|---|
| `datalib` | interactive navigation and loading; `library()` names the library for a call | [`datalib.sthlp`](../stata/src/d/datalib.sthlp) |
| `datalib <subcommand>` | dispatches to the matching `datalib_*` wrapper, e.g. `datalib countries` | [`datalib_api.sthlp`](../stata/src/d/datalib_api.sthlp) |

**Contract v1 wrappers** (13) — `resolve` · `load` · `catalog` · `countries` ·
`surveys` · `vintages` · `adaptations` · `files` · `create` · `config` · `root` ·
`browse` · `map_drive`. One page documents them all:
[`datalib_api.sthlp`](../stata/src/d/datalib_api.sthlp).

**Configuration and environment:**

| command | what it does | help |
|---|---|---|
| `getuserconfig` / `datalib config` | read per-operator paths from the user config file(s); `init` bootstraps one, `profile` adds a startup `profile.do` | [`getuserconfig.sthlp`](../stata/src/g/getuserconfig.sthlp) |
| `datalib_root` | resolve the library root; `find` adds on-disk resolution (library-or-container, refuses a non-library, discovers when nothing is set) | [`datalib_api.sthlp`](../stata/src/d/datalib_api.sthlp) |
| `mapzdrive` / `datalib map_drive` | map the configured network drive; `discover` reports the current mapping | [`mapzdrive.sthlp`](../stata/src/m/mapzdrive.sthlp) |

**Internals** (not called directly, but documented):
[`_dlw`](../stata/src/_/_dlw.sthlp) the load/merge engine ·
[`_foldernav`](../stata/src/_/_foldernav.sthlp) interactive navigation ·
[`_mkdir`](../stata/src/_/_mkdir.sthlp) deposit skeletons ·
[`_dl_islib`](../stata/src/_/_dl_islib.sthlp) the structural library test ·
[`_uc_init`](../stata/src/_/_uc_init.sthlp) the config bootstrap ·
[`_ctrycheck`](../stata/src/_/_ctrycheck.sthlp) ·
[`_svycheck`](../stata/src/_/_svycheck.sthlp) ·
[`_vcheck`](../stata/src/_/_vcheck.sthlp) ·
[`_adaptcheck`](../stata/src/_/_adaptcheck.sthlp).

## Contract & conformance (trilingual API)

- [Contract v1 — grammar & shared semantics](../config/grammar.md) · [collection registry](../config/collections.yml)
- [Conformance kit](../tests/DIVERGENCES.md) — golden cases (`tests/cases_*.csv`), the committed fixture library, and known divergences from pre-0.5 behavior
- Stata harness: `do stata/tests/run_conformance.do` from the repo root; `help datalib_api` after install
- CI: [`.github/workflows/conformance.yml`](../.github/workflows/conformance.yml) *declares* the R + Python legs on every push/PR, but Actions is billing-blocked org-wide and no run has executed a step since v0.9.2, so **all three legs, Stata included, are local gates today**

## Architecture & governance

- **[Deposit quickstart](DEPOSIT_QUICKSTART.md)** — one page for unit focals: what to deposit, where, how (start here if you were told "deposit your stock")
- [Governance proposal](GOVERNANCE_microdata_deposit.md) — the UNICEF microdata **archive** model: archive / catalogue / tool layers, stock vs flow, thematic domains, the review gate, access tiers
- Suggested reading order for DB-Managers participants: quickstart → governance → [ps toolbox](../scripts/ps/README.md) → [convention](../README.md#data-organization-convention)
- [Data organization convention](../README.md#data-organization-convention) — the folder / naming architecture
- [Provenance](../README.md#provenance) — the lineage: `jpazvd/datalib-dev` is the canonical generic package and paper home that this UNICEF adaptation is built **from**; [jpazvd/datalib](https://github.com/jpazvd/datalib) is its public release. Also where the Azevedo & Nguyen design draft sits
- Improvement plan / roadmap — roadmap; parts superseded by v0.5, see its status banner
- v0.10.0 alignment plan — the live plan for aligning the three ports, with what is deliberately **not** being ported and why

## Reference library

- Reference documentation library — external standards behind datalib's collections (ECAPOV, GLAD, the LAC handbook, and the ECATSD microdata workflows)

## Design paper (working draft)

- Azevedo, J. P. & Nguyen, M. C. *Harmonized Microdata Access with datalib: A Framework for Survey Data Management in Stata.* Unpublished working draft (not submitted anywhere). See [Citation](../README.md#citation).

## Generated inventories

Auto-generated by datalib's `map_folders` / survey commands (**regenerated — do not hand-edit**):

- Full library: folder map · surveys · paths · file sizes
- Health (HLT): folder map · surveys · paths · file sizes

---

[← datalib README](../README.md)
