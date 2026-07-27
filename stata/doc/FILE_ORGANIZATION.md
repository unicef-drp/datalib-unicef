# DATALIB File Organization Guide

[← datalib README](../../README.md) · [Documentation hub](../../docs/README.md)

## Contents

- [Directory Structure](#directory-structure)
- [Command Grouping](#command-grouping)
- [Rationale](#rationale)
- [Installation Impact](#installation-impact)
- [Migration Notes](#migration-notes)

## Directory Structure

The `stata/` directory is the Stata package root: install manifests at the
root, code under `src/` (organized alphabetically by initial letter), guides
under `doc/`, and the Stata conformance harness under `tests/`:

```text
stata/
├── datalib.pkg                 # Package metadata — must stay at this root
│                               #   (net install from(".../stata"); f entries
│                               #   reference src/...)
├── stata.toc                   # Table of Contents — same root requirement
├── README.md                   # Quick reference for this directory
│
├── src/
│   ├── d/                      # Main 'd' commands
│   │   ├── datalib.ado        # Main dispatcher (navigation + loading)
│   │   ├── datalib.sthlp      # Help file for datalib
│   │   ├── datalib_*.ado      # The 13 contract-v1 wrapper commands
│   │   └── datalib_api.sthlp  # Help file for the datalib_* API
│   │
│   ├── g/                      # 'g' commands
│   │   ├── getuserconfig.ado  # Per-operator config loader
│   │   └── getuserconfig.sthlp
│   │
│   ├── m/                      # 'm' commands
│   │   ├── mapzdrive.ado      # Network drive mapper (Windows-only)
│   │   └── mapzdrive.sthlp
│   │
│   └── _/                      # Internal utility functions (underscore prefix)
│       ├── _dlw.ado           # Data loading and processing engine (+ .sthlp)
│       ├── _foldernav.ado     # Interactive folder navigation (+ .sthlp)
│       ├── _mkdir.ado         # Directory structure creation (+ .sthlp)
│       ├── _ctrycheck.ado     # Country existence verification (+ .sthlp)
│       ├── _svycheck.ado      # Survey availability checking (+ .sthlp)
│       ├── _vcheck.ado        # Vintage number verification (+ .sthlp)
│       └── _adaptcheck.ado    # Adaptation file verification (+ .sthlp)
│
├── doc/
│   ├── INSTALLATION.md         # Installation guide
│   ├── FILE_ORGANIZATION.md    # This guide
│   └── ORGANIZATION_SUMMARY.md # Historical record of the 2024 migration
│
├── tests/
│   └── run_conformance.do      # Stata leg of the shared conformance suite
│                               #   (run from the REPO root: do stata/tests/run_conformance.do)
│
└── workflows/                  # Data import/documentation do-files
    └── ...                     # (not part of the installed package; see workflows/README.md)
```

Help files (`.sthlp`) stay **adjacent to their `.ado`** inside `src/` — the
Stata convention, and both install together via the `.pkg` manifest.

## Command Grouping

### Main User Commands

- **datalib**: Primary entry point for interactive data loading and navigation
- **datalib_***: The thirteen contract-v1 API commands shared with the R and
  Python implementations (`help datalib_api`)
- **getuserconfig** / **mapzdrive**: Per-operator configuration and drive
  mapping (canonical aliases `datalib_config` / `datalib_map_drive`)

### Internal Utility Functions

- **_foldernav**: Interactive folder browser within datalib repository
- **_dlw**: Core data loading and merging engine
- **_mkdir**: Directory creation and management
- **_ctrycheck**: Verify country existence
- **_svycheck**: Identify available surveys
- **_vcheck**: Verify vintage numbers
- **_adaptcheck**: Verify adaptation files availability

## Rationale

1. **Alphabetical Organization**: Easier to locate files in large repositories
2. **Semantic Grouping**: Related utilities grouped by function
3. **Clear Hierarchy**: Main commands separate from internal utilities
4. **Scalability**: Easy to add new commands or utilities
5. **Maintainability**: Reduces file clutter in the `stata/` package root

## Installation Impact

The .pkg file references files in subdirectories relative to the package root (e.g., `f src/d/datalib.ado`), so the Stata `net install` command correctly handles the organized structure: the `f` paths resolve against whatever `from()` points at, whether that is a clone, a network share, or a URL. Users experience no difference in functionality.

## Migration Notes

- The original flat structure had all .ado/.sthlp files in one directory
  (`02_programs/src` before v0.5.0, when the package root moved to `stata/`)
- The organized structure maintains the same file names and functionality
- Help system works identically across both structures
- Command execution unaffected by file organization

---

[← datalib README](../../README.md) · [Documentation hub](../../docs/README.md)
