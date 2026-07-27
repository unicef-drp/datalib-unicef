# DATALIB Python Utilities

[← datalib README](../../README.md) · [Documentation hub](../../docs/README.md)

## Contents

- [Overview](#overview)
- [Scripts by Category](#scripts-by-category)
- [Common Workflows](#common-workflows)
- [Dependencies](#dependencies)
- [Installation](#installation)
- [Configuration](#configuration)
- [Error Handling](#error-handling)
- [Best Practices](#best-practices)
- [Version History](#version-history)
- [Integration with DATALIB](#integration-with-datalib)
- [Contact & Support](#contact--support)
- [Author](#author)
- [License](#license)

This directory contains Python scripts for automating data management tasks related to DATALIB, including extracting, processing, and organizing microdata files.

## Overview

These utilities streamline the workflow for:
- Extracting and organizing compressed files
- File and folder management with parallel processing
- Cleanup and maintenance operations

## Scripts by Category

### 📦 File Extraction Utilities

#### **unzip_files_in_folder.py**
Recursively extracts all ZIP files from a folder hierarchy.

**Features:**
- Recursive directory traversal
- Skips specified folders (e.g., "Data")
- Duplicate file detection and skipping
- Automatic cleanup (deletes ZIP after extraction)
- Error handling for corrupted files

**Usage:**
```python
python unzip_files_in_folder.py
```

**Configuration:**
```python
root_folder = "d:/datalib/BRA"
```

---

### 📂 File Management Utilities

#### **copy_or_move_files_and_folders.py** (v1)
Script for copying or moving files and folders with parallel processing.

**Features:**
- Recursive file/folder copying or moving
- Parallel processing with ThreadPoolExecutor
- Overwrite option for existing items
- Toggle between copy and move operations
- Preserves folder hierarchy
- Efficient handling of large directory structures

**Functions:**
- `process_file()` - Handle individual file operations
- `process_directory()` - Handle directory operations
- `copy_or_move_files_and_folders()` - Main orchestration function

**Usage:**
```python
from copy_or_move_files_and_folders import copy_or_move_files_and_folders

copy_or_move_files_and_folders(
    source_dir="C:/source",
    destination_dir="C:/destination",
    overwrite=False,
    move=False,  # True to move, False to copy
    max_threads=4
)
```

---

#### **copy_or_move_files_and_folders-v2.py** (v2 - Latest)
Improved version. Same core signature as v1 plus two additions:

- `report_only=False` — when `True`, only compares source and destination
  (files missing from the destination, newer in the source, identical) without
  performing any file operations
- `report_file="operation_report.md"` — path of the markdown report it
  generates (kept out of the public distribution: the reports enumerate an internal tree)

The hyphen in the filename prevents a plain `import`; edit the configuration in
its `if __name__ == "__main__":` block and run it directly:

```bash
python copy_or_move_files_and_folders-v2.py
```

---

### 🗑️ Cleanup Utilities

#### **delete-folders.py**
Recursively deletes specified folders.

**Features:**
- Folder deletion with recursion
- Confirmation prompts
- Error handling

**Usage:**
```python
python delete-folders.py
```

---

#### **delete-temporary-files.py**
Removes temporary files from the file system.

**Features:**
- Targets common temporary file patterns
- Recursive cleanup
- Logging of deleted files

---

### 🔍 File Discovery Utilities

#### **recursive_file_finder.py**
Recursively searches a directory tree for files whose names contain a stub,
printing each match; can optionally delete the matches.

**Features:**
- Include/exclude filename-stub filtering
- Recursive traversal (prints each match as found)
- **List-only by default** — deletion is strictly opt-in (`delete_files=True` /
  `--delete`)
- Safety note: an earlier revision ran a delete on Z: **at import time**; the
  script is now guarded under `if __name__ == "__main__":` and no code runs on
  import. Keep all calls under that guard.

**Usage (Python):**
```python
from recursive_file_finder import find_files_with_stub

find_files_with_stub(
    root_path="C:/datalib",
    include_stub="june",
    exclude_stub="WLD",   # optional
    delete_files=False    # default: list only
)
```

**Usage (command line, argparse):**
```bash
python recursive_file_finder.py C:/datalib june --exclude_stub WLD
# add --delete to actually delete the matches
```

---

#### **zip_files_in_folder.py**
Recursively compresses files into ZIP archives.

**Features:**
- Folder-by-folder compression
- Maintains directory structure
- Compression level options

**Usage:**
```python
python zip_files_in_folder.py
```

---

## Common Workflows

### 1. Cleanup and Archive

```bash
# Delete temporary files
python delete-temporary-files.py

# Archive organized data
python zip_files_in_folder.py
```

## Dependencies

### Core Libraries (Python Standard Library)
- `os` - File and directory operations
- `logging` - Logging operations
- `shutil` - File operations (copy, move, remove)
- `zipfile` - ZIP file handling
- `concurrent.futures` - Parallel processing (ThreadPoolExecutor)

### System Requirements
- Python 3.6+
- Sufficient disk space for data storage
- Write permissions to target directories

## Installation

1. Ensure Python 3.6+ is installed
2. These scripts use only Python standard library - no external packages required
3. Copy scripts to desired location
4. Update configuration paths as needed

## Configuration

Each script has configurable parameters at the top or in function arguments:

- **Local directories**: Modify `local_base_dir` paths
- **Thread count**: Adjust `max_threads` for file operations

## Error Handling

All scripts include:
- Try-except blocks for exception handling
- Logging of errors and operations
- Graceful failure messages
- Cleanup on interruption (where applicable)

## Best Practices

1. **Testing**: Test with small datasets first
2. **Backups**: Keep backups before running move operations
3. **Monitoring**: Check logs for warnings/errors
4. **Parallel Processing**: Adjust `max_threads` based on system resources

## Version History

- **2026-07-10**: Safety fix — `recursive_file_finder.py` no longer executes at
  import time (an earlier revision ran a delete on Z: the moment the module was
  imported); all calls are now guarded under `if __name__ == "__main__":` and
  deletion is opt-in (`--delete` / `delete_files=True`, list-only by default)
- **2024-12-21**: Added copy_or_move_files_and_folders-v2.py with enhanced features
- **2024-08-22**: Initial release of Python utilities

## Integration with DATALIB

These Python utilities complement the Stata-based DATALIB system by:
- Organizing files for datalib ingestion
- Automating repetitive extraction and file-management tasks

## Contact & Support

For issues or feature requests, refer to the main DATALIB repository.

## Author

Joao Pedro Azevedo (jpazevedo@unicef.org)

## License

See LICENSE file in the repository for details.

---

[← datalib README](../../README.md) · [Documentation hub](../../docs/README.md)
