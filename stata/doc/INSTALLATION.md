# DATALIB Installation Guide

[← datalib README](../../README.md) · [Documentation hub](../../docs/README.md)

## Contents

- [Installation (from a clone)](#installation-from-a-clone)
- [Package Contents](#package-contents)
- [Version History](#version-history)
- [Setup Requirements](#setup-requirements)
- [Quick Start](#quick-start)
- [Help Files](#help-files)
- [Author](#author)
- [License](#license)
- [Repository](#repository)

## Installation (from a clone)

This repository is currently **private**, so `net install` from the raw GitHub
URL cannot work (Stata sends no authentication). Clone the repository, then
install from your local clone:

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
unchanged — the path below is already correct, and only the repository's
visibility prevents it from resolving:

```stata
net install datalib, from("https://raw.githubusercontent.com/unicef-drp/datalib-unicef/main/stata") replace
```

> **Upgrading from ≤ 0.4:** the package root moved from `02_programs/src` to
> `stata/`, so `adoupdate datalib` against any old location will fail.
> `ado uninstall datalib`, then reinstall once from your clone.

## First run: configure the library

```stata
datalib config, init profile
```

This writes a prepopulated `~/.config/user_config.yml` — your username, the
`githubFolder` from `whereis github`, the `zDrive`/`zDriveUNC` from
`mapzdrive, discover`, and the library root itself, all detected — plus a startup
`profile.do` in `c(sysdir_personal)`, which is on the adopath, so Stata runs it at
launch. One caveat: Stata looks for `profile.do` in the **current directory first**,
so a project folder carrying its own `profile.do` wins and this one does not run
there — add a `getuserconfig` call to that project's profile if you need it. Anything
that cannot be determined unambiguously is written as a commented `TODO` with the
candidates listed, and the file is opened so you can finish it.

Nothing is ever overwritten: an existing block for you is kept, an existing
`profile.do` is left untouched, and a file holding other operators' blocks is only
appended to. Running `profile_datalib.do` from the clone does this for you when no
configuration exists. See `help _uc_init` and `help getuserconfig`.

If you would rather not keep a config file, set the root per session with
`global datalib "Z:/datalib"` (or the folder holding it), or pass
`library(<path>)` on any `datalib` call.

After installation, load the package help:

```stata
help datalib
```

## Package Contents

### Entry points

- `datalib` - Interactive navigation and data loading dispatcher
- `datalib_*` - Contract v1 API shared with the R and Python implementations
  (`help datalib_api`), thirteen commands:
  `datalib_config`, `datalib_root`, `datalib_countries`, `datalib_surveys`,
  `datalib_vintages`, `datalib_adaptations`, `datalib_resolve`,
  `datalib_files`, `datalib_catalog`, `datalib_load`, `datalib_browse`,
  `datalib_create`, `datalib_map_drive`

### Configuration utilities

- `getuserconfig` - Load per-operator paths from `~/.config/user_config.yml`
  (canonical alias: `datalib_config`)
- `mapzdrive` - Map the configured network drive, Windows-only
  (canonical alias: `datalib_map_drive`)

### Engine and legacy subroutines

- `_dlw` - Data loading and merging engine
- `_foldernav` - Interactive folder navigation utility
- `_mkdir` - Directory structure creation and management
- `_ctrycheck` - Country existence verification
- `_svycheck` - Survey availability checking
- `_vcheck` - Vintage number verification
- `_adaptcheck` - Adaptation file verification

## Version History

For the installed package version and history, see
[CHANGELOG.md](../../CHANGELOG.md) (kept current across releases).

## Setup Requirements

`datalib` needs to know where the microdata library root is. Any one of the
following works (see `help datalib_api` for the precedence order):

### Global macro

```stata
global datalib "C:/path/to/datalib"
```

Or for network paths:

```stata
global datalib "//server/share/datalib"
```

### Environment variable

Set `DATALIB_ROOT` in the operating system; the `datalib_*` wrappers fall back
to it when `${datalib}` is unset.

### Per-operator config file

Add an optional `datalib:` key to your user block in
`~/.config/user_config.yml`; running `getuserconfig` (or `datalib_config`)
fills `${datalib}` from it when the global is unset.

## Quick Start

### 1. Basic interactive navigation

Start with no parameters to browse available data:

```stata
datalib
```

### 2. Browse a country's surveys interactively

A country without both year and survey opens clickable navigation (nothing is
loaded yet):

```stata
datalib, country(ZWE)
```

### 3. Load and merge survey data

A full country + year + survey request plus a collection loads (and merges)
the registry modules:

```stata
datalib, country(ZWE) year(2019) survey(MICS) collection(HLT) clear
```

### 4. Load master (original) files

Master loads need `module()` or `filename()`:

```stata
datalib, country(ZWE) year(2019) survey(MICS) master module(household) clear
```

### 5. Scriptable API

The same operations, non-interactively:

```stata
datalib_countries
datalib_resolve, country(ZWE) year(2019) survey(MICS) collection(HLT)
datalib_load, country(ZWE) year(2019) survey(MICS) collection(HLT) clear
datalib_catalog, clear
```

## Help Files

All commands include help files accessible via:

```stata
help datalib
help datalib_api
help getuserconfig
help mapzdrive
help _dlw
help _foldernav
help _mkdir
help _ctrycheck
help _svycheck
help _vcheck
help _adaptcheck
```

## Author

Joao Pedro Azevedo (jpazevedo@unicef.org)

## License

See LICENSE file in the repository for details.

## Repository

<https://github.com/unicef-drp/datalib-unicef>

---

[← datalib README](../../README.md) · [Documentation hub](../../docs/README.md)
