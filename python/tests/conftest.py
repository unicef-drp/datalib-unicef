"""Shared test fixtures: locate the repo tests/ dir and the fixture library.

The package is imported from the src/ layout without installation, and the
golden case CSVs are the SHARED files in the repository tests/ directory,
located by walking up from this file.
"""

from __future__ import annotations

import csv
import sys
from pathlib import Path

import pytest

_HERE = Path(__file__).resolve().parent
_SRC = _HERE.parent / "src"
if str(_SRC) not in sys.path:
    sys.path.insert(0, str(_SRC))


def find_repo_tests_dir(start: Path = _HERE) -> Path:
    """Walk up from ``start`` to the repo tests/ dir holding the golden CSVs."""
    for candidate in (start, *start.parents):
        shared = candidate / "tests" / "cases_resolve.csv"
        if shared.is_file():
            return candidate / "tests"
    raise RuntimeError(
        "could not locate the shared repo tests/ directory (cases_resolve.csv)"
    )


def read_cases(name: str) -> list[dict[str, str]]:
    """Read one shared golden-case CSV as a list of row dicts."""
    path = find_repo_tests_dir() / name
    with open(path, "r", encoding="utf-8", newline="") as fh:
        return list(csv.DictReader(fh))


@pytest.fixture(scope="session")
def repo_tests_dir() -> Path:
    return find_repo_tests_dir()


@pytest.fixture(scope="session")
def repo_root(repo_tests_dir: Path) -> Path:
    return repo_tests_dir.parent


@pytest.fixture(scope="session")
def fixture_root(repo_tests_dir: Path) -> Path:
    root = repo_tests_dir / "fixtures" / "library"
    assert root.is_dir(), f"fixture library missing: {root}"
    return root
