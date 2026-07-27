# DATALIB Programs Documentation

[← datalib README](../../README.md) · [Documentation hub](../../docs/README.md)

## Contents

- [File Organization and Naming Convention](#file-organization-and-naming-convention)
- [HLT (Health) Collection](#hlt-health-collection)
- [MICS/IPUMS Collection](#micsipums-collection)
- [Utility and Benchmarking](#utility-and-benchmarking)
- [Supporting Files](#supporting-files)
- [Workflow Execution Order](#workflow-execution-order)
- [Key Conventions](#key-conventions)
- [Global Variables Used](#global-variables-used)
- [Dependencies](#dependencies)
- [Configuration Requirements](#configuration-requirements)
- [Error Handling](#error-handling)
- [Version History](#version-history)
- [Related Resources](#related-resources)
- [Author & Support](#author--support)

This directory contains Stata do-files that orchestrate the data import, organization, and processing workflow for the DATALIB system. The programs handle multiple survey types and countries with a consistent naming and organization convention.

## File Organization and Naming Convention

Files are organized by a 4-digit prefix system:

- **02XX** - Collection data processing (HLT and MICS/IPUMS)
- **99XX** - Utility and benchmarking scripts

Project initialization lives at the repository root (`profile_datalib.do`,
run via `run_datalib.do`), not in this directory.

## HLT (Health) Collection

### **0210_hlt_import_data.do** - HLT Data Import

**Purpose:** Imports health collection microdata

**Tasks:**

- Sets up HLT collection folder structure
- Creates country-specific health data folders
- Follows CCC_YYYY_SSSS naming convention
- Organizes multiple health surveys

**Collection:** HLT (Health)
**Data Organization:**

- Master file structure: vNN_M
- Adaptation structure: vNN_A_HLT
- Multi-country support

---

### **0219_hlt_documentation.do** - HLT Documentation

**Purpose:** Generates documentation for health collection datasets

**Tasks:**

- Creates health data dictionaries
- Documents survey metadata
- Produces variable documentation

---

## MICS/IPUMS Collection

### **0220_mics-ipmus_import_data-v2.do** - MICS/IPUMS Import v2

**Purpose:** Imports MICS and IPUMS harmonized data (version 2)

**Status:** Legacy version - see v3 for latest

---

### **0221_mics-ipmus_import_data-v3.do** - MICS/IPUMS Import v3

**Purpose:** Imports MICS and IPUMS harmonized data (current version)

**Tasks:**

- Processes MICS microdata files
- Integrates IPUMS harmonization
- Creates standardized variable structure
- Handles multiple countries

**Collection:** MICS/IPUMS

---

### **0223_mics-ipmus_import_data-v1.do** - MICS/IPUMS Import v1

**Purpose:** Original version of MICS/IPUMS import (deprecated)

**Status:** Archived - retained for reference

---

### **0229_mics-ipmus_documentation.do** - MICS/IPUMS Documentation

**Purpose:** Generates documentation for MICS/IPUMS datasets

**Tasks:**

- Creates variable documentation
- Generates data dictionaries
- Documents harmonization approach

---

## Utility and Benchmarking

### **9999_performance_benchmark.do** - Performance Benchmarking

**Purpose:** Benchmarks datalib performance and generates performance reports

**Tasks:**

- Measures query execution time
- Benchmarks data loading performance
- Tests folder navigation speed
- Generates performance statistics
- Country-specific or full-root analysis

**Parameters:**

- Optional country parameter for focused testing
- Can test full datalib repository

**Output:** Performance metrics and timing reports

---

### **datalib.do** - Demo/Manual Example

**Purpose:** Demonstrates `datalib` command usage (v0.5 demo)

**Content:**

- Interactive navigation (bare `datalib`, country-only survey picker)
- Fully specified loads (country + year + survey + vintages + collection)
- Per-module HLT loads in a loop (`adult children hhmembers household`)
- Graceful-failure example (informative error on an unavailable selection)

**Usage:** Reference code for understanding datalib mechanics

---

## Supporting Files

### **placeholderfile.md**

Placeholder file - no functional purpose

---

## Workflow Execution Order

### Performance Analysis

1. Run data import and organization workflows above
2. Execute **9999_performance_benchmark.do** to measure performance
3. Review generated metrics

---

## Key Conventions

### Naming Convention

- **CCC_YYYY_SSSS** - Country code, Year, Survey acronym
- Example: `ZWE_2019_MICS` (Zimbabwe, 2019, MICS survey)

### File Structure

```text
datalib/
├── ZWE/
│   ├── ZWE_2019_MICS/
│   │   └── ZWE_2019_MICS_v01_M_v01_A_MICS/
│   │       ├── Data/
│   │       │   ├── Original/
│   │       │   └── Stata/
│   │       ├── Doc/
│   │       │   ├── Questionnaires/
│   │       │   ├── Reports/
│   │       │   └── Technical/
│   │       └── Programs/
│   └── [other years]
├── HLT/
│   └── [Health surveys]
└── [Other collections]
```

### Version Naming

- **vNN_M** - Master file version (original data)
- **vNN_A_CLCT** - Adaptation file for collection CLCT
  - Example: `v01_A_MICS` (MICS adaptation version 01)

### Collections

Registered collections (module lists and merge keys in
`config/collections.yml`, used by the loader):

- **HLT** - Health outcomes data
- **IPUMS** - MICS/IPUMS harmonized data

Folder-convention labels only (used as the CCC token for multi-country
deposits; not in the merge registry):

- **WLD** - Multi-country datasets
- **ECA** - Europe/Central Asia region

---

## Global Variables Used

Set by the repo-root `profile_datalib.do` (except `${datalib}`, which the
profile only defaults when unset):

| Variable | Purpose | Example |
| -------- | ------- | ------- |
| `${datalib}` | Root datalib path | `Z:/datalib/` (profile default) |
| `${datalib_hlt}` | HLT collection library root (used by 0219) | `Z:/datalib-hlt` |
| `${inputdata_hlt}` | Harmonized HLT input CSVs (used by 0210); set per user in the profile | `C:/Users/<user>/UNICEF/Health-HIV Data & Analytics - Harmonized Micro Data` |
| `${github}` | Local GitHub folder (from `whereis github`) | `C:/GitHub` |
| `${clone}` | Repository clone path | `${github}/datalib-unicef` |
| `${rawdata}` | Raw data path | `${clone}/data/` |
| `${hosted_in_repo}` | Repo-hosted inputs (IPUMS ISO3 mapping CSV) | `${rawdata}/hosted_in_repo` |

Note: the overwrite switch is a do-file **local** (`local overwrite = 0/1`
inside `0221_...v3.do` and `0223_...v1.do`), not a global.

---

## Dependencies

### Stata Packages Required

- `datalib` - Main package from this repository

### Utilities

- `_mkdir` - Directory creation and management
- `_dlw` - Data loading and merging
- `_foldernav` - Folder navigation

### Python Support (Pre-processing)

- Python utilities in `scripts/py/` (repository only; since v0.5.0 they are
  not distributed with the installed ado package)

---

## Configuration Requirements

1. **Profile Setup**: Must execute the repo-root `profile_datalib.do` (via `run_datalib.do`) before running
2. **Path Configuration**: Set global variables for datalib, rawdata, clone paths
3. **Permissions**: Write access to datalib and output directories

---

## Error Handling

- `profile_datalib.do` sets `${datalib_profile_is_loaded}` on success; the
  workflow do-files assume the profile has been run (they do not re-check the flag)
- Directory creation uses `cap` (capture) to handle existing folders
- Task execution controlled via commented/uncommented do file calls
- Survey availability validation before processing

---

## Version History

See [CHANGELOG.md](../../CHANGELOG.md) for the repository version history
(current release: **v0.5.0**, 2026-07-10).

---

## Related Resources

- See `scripts/py/README.md` for Python utility documentation
- See `../src/d/datalib.sthlp` for command documentation
- See main repository README for overall project information

---

## Author & Support

**Author:** Joao Pedro Azevedo (jpazevedo@unicef.org)

For issues, feature requests, or questions, refer to the main DATALIB repository.

---

[← datalib README](../../README.md) · [Documentation hub](../../docs/README.md)
