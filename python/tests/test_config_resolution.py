"""CFG golden cases -- the two-file config-root resolution contract.

Mirrors r/tests/testthat/test-config-resolution.R; the source_stage strings
are identical across languages (config/grammar.md section 7).
"""

from __future__ import annotations

import pytest

from datalib.config import resolve_root
from datalib.errors import DatalibRootNotSet

U = "testuser"
GEN = "user_config.yml"
PKG = "datalib_config.yml"


def _p(root) -> str:
    """Forward-slash string of a resolved root (portable across OSes)."""
    return str(root).replace("\\", "/")


def _block(datalib=None, extra=None) -> str:
    lines = [f"{U}:"]
    if extra is not None:
        lines.append(f"  {extra}")
    if datalib is not None:
        lines.append(f'  datalib: "{datalib}"')
    return "\n".join(lines) + "\n"


def _write(d, name, body):
    (d / name).write_text(body, encoding="utf-8")


@pytest.fixture
def cfg_dir(tmp_path, monkeypatch):
    monkeypatch.setenv("DATALIB_CONFIG_DIR", str(tmp_path))
    monkeypatch.delenv("DATALIB_ROOT", raising=False)
    monkeypatch.delenv("DATALIB_CONFIG", raising=False)
    return tmp_path


def test_cfg01_generic_only(cfg_dir):
    _write(cfg_dir, GEN, _block("Z:/from_generic"))
    r = resolve_root(user=U, report=True)
    assert _p(r.root) == "Z:/from_generic"
    assert r.source_stage == "config_generic"
    assert r.source_file.replace("\\", "/").endswith(GEN)


def test_cfg02_package_only(cfg_dir):
    _write(cfg_dir, PKG, _block("Z:/from_package"))
    r = resolve_root(user=U, report=True)
    assert _p(r.root) == "Z:/from_package"
    assert r.source_stage == "config_package"


def test_cfg03_both_generic_wins(cfg_dir):
    _write(cfg_dir, GEN, _block("Z:/from_generic"))
    _write(cfg_dir, PKG, _block("Z:/from_package"))
    r = resolve_root(user=U, report=True)
    assert _p(r.root) == "Z:/from_generic"
    assert r.source_stage == "config_generic"


def test_cfg04_generic_without_key_falls_through(cfg_dir):
    # key-presence: generic has the user block but no datalib key
    _write(cfg_dir, GEN, _block(extra='githubFolder: "C:/GitHub"'))
    _write(cfg_dir, PKG, _block("Z:/from_package"))
    r = resolve_root(user=U, report=True)
    assert _p(r.root) == "Z:/from_package"
    assert r.source_stage == "config_package"


def test_cfg05_no_key_anywhere_raises(cfg_dir):
    _write(cfg_dir, GEN, _block(extra='githubFolder: "C:/GitHub"'))
    with pytest.raises(DatalibRootNotSet):
        resolve_root(user=U)


def test_cfg06_env_beats_files(cfg_dir, monkeypatch):
    _write(cfg_dir, GEN, _block("Z:/from_generic"))
    monkeypatch.setenv("DATALIB_ROOT", "Z:/from_env")
    r = resolve_root(user=U, report=True)
    assert _p(r.root) == "Z:/from_env"
    assert r.source_stage == "env"


def test_cfg07_datalib_config_pins_one_file(cfg_dir, monkeypatch):
    _write(cfg_dir, GEN, _block("Z:/from_generic"))
    _write(cfg_dir, PKG, _block("Z:/pinned"))
    monkeypatch.setenv("DATALIB_CONFIG", str(cfg_dir / PKG))
    r = resolve_root(user=U, report=True)
    assert _p(r.root) == "Z:/pinned"
    assert r.source_stage == "config_package"


def test_cfg08_parser_floor_multiple_blocks(cfg_dir):
    _write(
        cfg_dir,
        GEN,
        "# shared operator config\n"
        "otheruser:\n"
        '  datalib: "Z:/WRONG"\n'
        f"{U}:\n"
        '  githubFolder: "C:/GitHub"\n'
        '  datalib: "Z:/correct"\n',
    )
    r = resolve_root(user=U, report=True)
    assert _p(r.root) == "Z:/correct"
    assert r.source_stage == "config_generic"


def test_cfg09_empty_value_falls_through(cfg_dir):
    _write(cfg_dir, GEN, _block(""))  # datalib: "" -> treated as absent
    _write(cfg_dir, PKG, _block("Z:/from_package"))
    r = resolve_root(user=U, report=True)
    assert _p(r.root) == "Z:/from_package"
    assert r.source_stage == "config_package"


def test_argument_stage(cfg_dir):
    r = resolve_root("Z:/explicit", user=U, report=True)
    assert _p(r.root) == "Z:/explicit"
    assert r.source_stage == "argument"


def test_resolve_root_default_returns_path(cfg_dir):
    _write(cfg_dir, GEN, _block("Z:/from_generic"))
    r = resolve_root(user=U)  # report=False -> bare path
    assert _p(r) == "Z:/from_generic"
