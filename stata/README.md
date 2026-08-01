# DATALIB Package Source Files

[← datalib README](../README.md) · [Documentation hub](../docs/README.md)

This directory is the Stata package root for DATALIB: the install manifests sit here, the code under `src/`, the guides under `doc/`, and the Stata leg of the conformance suite under `tests/`.

## Quick Reference

**Main Package Files:**

- `datalib.pkg` - Package metadata (its `f` entries reference `src/...`; must stay at this root for `net install`)
- `stata.toc` - Table of Contents for the Stata package system (same root requirement)
- `doc/INSTALLATION.md` - Installation and setup guide
- `doc/FILE_ORGANIZATION.md` - Detailed guide to the file organization structure

## Directory Organization

- `src/d/` - The `datalib` command and the thirteen `datalib_*` contract wrappers (`help datalib_api`)
- `src/g/` - `getuserconfig` user-config loader
- `src/m/` - `mapzdrive` network drive mapper
- `src/_/` - Utility functions starting with underscore (`_dlw`, `_foldernav`, `_mkdir`, `_dl_islib`, the `_*check` verifiers)
- `doc/` - Markdown guides (installation, file organization, the 2024 migration record)
- `tests/` - The Stata conformance harness (`do stata/tests/run_conformance.do` from the repo root)
- `workflows/` - Data import/documentation do-files (not part of the installed package; see `workflows/README.md`)

## Command surface

`datalib` takes two forms. The legacy surface is options-only (navigation and
loading); in addition, a first-token **subcommand** dispatches to the matching
contract wrapper, so the scriptable API is reachable through the same command:

```stata
datalib, country(ZWE) year(2019) survey(MICS) collection(HLT)   // load + merge
datalib                                                         // navigate
datalib, library(Z:/datalib-hlt) country(ZWE)                   // name the library
datalib countries                                               // -> datalib_countries
datalib resolve, country(ZWE) year(2019) survey(MICS) kind(master)
```

`library()` belongs to the legacy surface and may name the library *or* the
folder holding it; it publishes the resolved library to `${datalib}`, since the
clickable navigation links carry no options. The subcommand form and the wrappers
take `root()` per call instead, and do not touch the global. Resolution rules
live in [`config/grammar.md`](../config/grammar.md) §7.

## First run on a machine

```stata
datalib config, init profile
```

Writes a prepopulated `~/.config/user_config.yml` — username, `githubFolder`,
`zDrive`/`zDriveUNC` and the library, all detected — plus a startup `profile.do`
in `c(sysdir_personal)` that loads it at launch. Values that cannot be determined
unambiguously are left as commented `TODO`s with the candidates listed, and the
file is opened for editing. Nothing is overwritten: an existing block is kept, an
existing `profile.do` is left alone, and a shared file is only appended to.
`profile_datalib.do` runs this automatically when no configuration exists.

The writer is `_dl_islib`'s neighbour [`_uc_init`](src/_/_uc_init.sthlp); it is
generic, so `getuserconfig, init` works outside datalib too — the library value is
passed in rather than looked up. The config *read* never writes.

## Installation

The repository is currently **private**, so `net install` from the raw GitHub
URL cannot work — Stata sends no authentication, so the request is answered with
HTTP 404. The URL itself is correctly formed and would work unchanged if the
repository were made public; only visibility prevents it from resolving.

```stata
* correct, but resolves only for a public repository
net install datalib, from("https://raw.githubusercontent.com/unicef-drp/datalib-unicef/main/stata") replace
```

Install from a local clone instead:

```stata
global datalib_clone "C:/path/to/datalib-unicef"
net install datalib, from("${datalib_clone}/stata") replace
```

UNICEF colleagues on the CSO share can install from the LAN net site, which is
rebuilt from the tagged release each time:

```stata
net install datalib, from("Z:/_pkg/datalib/stata") replace
```

Verify with `datalib root, find` (reports the library and where it resolved from)
and `datalib countries`.

## Tests

The Stata leg has no CI licence, so it is a **manual pre-release gate** — run it
from the repository root before any release:

```stata
do "stata/tests/run_conformance.do"        // exits 9 on any failure
```

The harness prints its own pass/fail/skip total on the last line; this README
deliberately does not repeat the number, because a hardcoded count silently goes
stale every time a part grows. Its ten parts:

| part | what it pins | cases |
|---|---|---|
| 1 | cross-language resolve cases, read from `tests/cases_resolve.csv` | 12 |
| 2 | cross-language load cases (row count + `windex5==8` preservation) | 6 |
| 3 | `datalib <sub>` dispatch ≡ calling `datalib_<sub>` directly | derived from part 1 |
| 4 | library resolution: contract default *and* `find` mode | c01–c14 |
| 5 | config bootstrap / the generic writer (`getuserconfig, init`) | i01–i11 |
| 6 | config resolution: the two-file key-presence search + `source_stage` | CFG-01–CFG-10 |
| 7 | shared enumerator cases, normalised per grammar.md rule 9 | e01–e10 |
| 8 | the error taxonomy: one trigger per contract error | 6 |
| 9 | every option declared in `config/surface.yml` is really accepted | one call per declared option |
| 10 | `datalib , update`: precedence, forwarding, and which record says what is installed | u01–u16 |

Parts 1–2 and 7–8 are shared: R and Python assert the same rows from
`tests/cases_*.csv` and `tests/error_taxonomy.csv`. Parts 3–6 cover surfaces
Stata has and the other two ports do not yet — tracked in the
[Alignment status table](../config/grammar.md#alignment-status).

> **Closed in v0.9.6:** the CFG golden cases used to live in a separate
> `test_config_resolution.do` that nothing invoked — it ran only when hand-typed,
> which is how it came to be cited as passing while nothing had executed it. They
> are now Part 6, so the single entry point above covers them, and their bare
> `assert`s (which abort instead of tallying) were rewritten in the harness idiom.
> There is one gate, and it counts.

## Version

**v0.9.30** (2026-08-01) — see [CHANGELOG.md](../CHANGELOG.md) for the full version history.

## See Also

- See FILE_ORGANIZATION.md for detailed structure information
- See INSTALLATION.md for comprehensive installation instructions
- Run `help datalib` after installation for command documentation

---

[← datalib README](../README.md) · [Documentation hub](../docs/README.md)
