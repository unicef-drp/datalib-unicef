"""The repo carries one version, in VERSION.

Until v0.9.4 ``pyproject.toml`` and ``__init__.py`` both said ``0.1.0`` while
the repo shipped 0.9.3 -- nothing pinned them, unlike ``CONTRACT_VERSION``,
which :mod:`test_registry_sync` and :mod:`test_docs` both pin.
"""

from __future__ import annotations

import re

import pytest

import datalib


def _repo_version(repo_root) -> str:
    vfile = repo_root / "VERSION"
    if not vfile.is_file():
        pytest.skip("VERSION not found (running outside the repo)")
    return vfile.read_text(encoding="utf-8").strip()


def test_dunder_version_matches_repo(repo_root) -> None:
    assert datalib.__version__ == _repo_version(repo_root)


def test_pyproject_version_matches_repo(repo_root) -> None:
    text = (repo_root / "python" / "pyproject.toml").read_text(encoding="utf-8")
    m = re.search(r'^version\s*=\s*"([^"]+)"', text, re.MULTILINE)
    assert m, "no version key in pyproject.toml"
    assert m.group(1) == _repo_version(repo_root)
