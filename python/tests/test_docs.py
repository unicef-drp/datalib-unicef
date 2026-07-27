"""Documentation conformance tests (contract v1, config/grammar.md).

Mechanically verifies that the package stays self-documenting, so the
docs cannot drift from the code:

* every public callable/class reachable from ``datalib`` (top-level
  namespace plus every public submodule) has a docstring of at least
  three non-empty lines;
* the parameter names in each public function's numpy-style Parameters
  section exactly equal the live signature (excluding ``self``), parsed
  with a small regex — no numpydoc dependency;
* the exported surface equals the contract list: the 13 canonical
  ``datalib_*`` names plus the verbatim ``getuserconfig`` / ``mapzdrive``
  aliases, present in both the namespace and ``__all__``, and each
  canonical alias is the very same object as its idiomatic counterpart;
* ``datalib.CONTRACT_VERSION == "1"``.
"""

from __future__ import annotations

import importlib
import inspect
import pkgutil
import re

import pytest

import yaml

import datalib

from conftest import find_repo_tests_dir

# ---------------------------------------------------------------------------
# the contract surface (config/grammar.md "Shared public surface")
# ---------------------------------------------------------------------------

# Read from config/surface.yml rather than hand-typed here. This list used to be
# a literal citing grammar.md in a comment while nothing read it -- one of three
# copies (with grammar.md's prose and R's own literal), each free to drift from
# the others. surface.yml is now the single declaration, and test_surface.py
# asserts the code against it in all three languages.
CONTRACT_ALIASES = sorted(
    yaml.safe_load(
        (find_repo_tests_dir().parent / "config" / "surface.yml").read_text(
            encoding="utf-8"
        )
    )["commands"]
)
VERBATIM_ALIASES = ["getuserconfig", "mapzdrive"]

# canonical alias -> idiomatic name it must be the same object as
ALIAS_TARGETS = {
    "datalib_config": "getuserconfig",
    "datalib_root": "resolve_root",
    "datalib_countries": "countries",
    "datalib_surveys": "surveys",
    "datalib_vintages": "vintages",
    "datalib_adaptations": "adaptations",
    "datalib_resolve": "resolve",
    "datalib_files": "files",
    "datalib_catalog": "catalog",
    "datalib_load": "load",
    "datalib_browse": "browse",
    "datalib_create": "create",
    "datalib_map_drive": "mapzdrive",
}


# ---------------------------------------------------------------------------
# walk the package: public callables/classes reachable from datalib
# ---------------------------------------------------------------------------


def _iter_public_modules():
    """The datalib package itself plus every public (non-_) submodule."""
    yield datalib
    for info in pkgutil.iter_modules(datalib.__path__):
        if not info.name.startswith("_"):
            yield importlib.import_module(f"datalib.{info.name}")


def _collect():
    """(qualified name, object) for every public callable/class, deduped."""
    objects: dict[int, tuple[str, object]] = {}
    for mod in _iter_public_modules():
        names = getattr(mod, "__all__", None)
        if names is None:  # pragma: no cover - all modules define __all__
            names = [n for n in vars(mod) if not n.startswith("_")]
        for name in names:
            if name.startswith("_"):
                continue
            obj = getattr(mod, name)
            if inspect.ismodule(obj) or not callable(obj):
                continue
            objects.setdefault(id(obj), (f"{mod.__name__}.{name}", obj))
    return list(objects.values())


_PUBLIC = _collect()
_CLASSES = [(n, o) for n, o in _PUBLIC if inspect.isclass(o)]
_FUNCTIONS = [(n, o) for n, o in _PUBLIC if not inspect.isclass(o)]

# public methods and properties defined on the public classes
_METHODS: list[tuple[str, object]] = []
_PROPERTIES: list[tuple[str, object]] = []
for _cname, _cls in _CLASSES:
    for _mname, _member in vars(_cls).items():
        if _mname.startswith("_"):
            continue
        if inspect.isfunction(_member):
            _METHODS.append((f"{_cname}.{_mname}", _member))
        elif isinstance(_member, property):
            _PROPERTIES.append((f"{_cname}.{_mname}", _member))

_DOC_TARGETS = _PUBLIC + _METHODS
_PARAM_TARGETS = _FUNCTIONS + _METHODS


def _ids(pairs):
    return [name for name, _ in pairs]


# ---------------------------------------------------------------------------
# numpy-style docstring parsing (regex only, no numpydoc)
# ---------------------------------------------------------------------------

_SECTION_RE = re.compile(r"^(\w[\w ]*?)\n-{3,}[ \t]*$", re.MULTILINE)
_PARAM_LINE_RE = re.compile(r"^([A-Za-z_]\w*)\s*(?::|$)")


def _clean_doc(obj) -> str:
    """The object's own docstring, dedented ('' when absent/inherited)."""
    return inspect.cleandoc(obj.__doc__ or "")


def _sections(doc: str) -> dict[str, str]:
    """Split a cleaned numpy-style docstring into named sections."""
    headers = list(_SECTION_RE.finditer(doc))
    out: dict[str, str] = {}
    for i, match in enumerate(headers):
        end = headers[i + 1].start() if i + 1 < len(headers) else len(doc)
        out[match.group(1).strip()] = doc[match.end():end]
    return out


def _documented_params(doc: str) -> list[str]:
    """Parameter names listed in the docstring's Parameters section."""
    body = _sections(doc).get("Parameters", "")
    names: list[str] = []
    for line in body.splitlines():
        if not line or line.startswith((" ", "\t")):
            continue  # descriptions are indented; blank lines separate
        hit = _PARAM_LINE_RE.match(line)
        if hit:
            names.append(hit.group(1))
    return names


def _signature_params(func) -> list[str]:
    """Real parameter names of ``func``, excluding self."""
    sig = inspect.signature(func)
    return [p.name for p in sig.parameters.values() if p.name != "self"]


# ---------------------------------------------------------------------------
# (a) every public callable/class has a substantial docstring
# ---------------------------------------------------------------------------


@pytest.mark.parametrize("name,obj", _DOC_TARGETS, ids=_ids(_DOC_TARGETS))
def test_public_object_has_docstring(name, obj):
    doc = _clean_doc(obj)
    non_empty = [ln for ln in doc.splitlines() if ln.strip()]
    assert len(non_empty) >= 3, (
        f"{name} needs a docstring of >= 3 non-empty lines "
        f"(has {len(non_empty)})."
    )


@pytest.mark.parametrize("name,prop", _PROPERTIES, ids=_ids(_PROPERTIES))
def test_public_property_has_docstring(name, prop):
    assert (prop.__doc__ or "").strip(), f"{name} needs a docstring."


def test_every_public_module_has_docstring():
    for mod in _iter_public_modules():
        doc = (mod.__doc__ or "").strip()
        assert doc, f"module {mod.__name__} needs a module docstring."


def test_walk_found_the_expected_surface():
    """Guard the walker itself: the contract functions must be among the
    collected objects (an empty walk must fail loudly, not pass silently)."""
    found = {name.rsplit(".", 1)[-1] for name, _ in _PUBLIC}
    for required in VERBATIM_ALIASES + ["resolve", "load", "browse", "create"]:
        assert required in found, f"package walk did not find {required}()"
    assert len(_FUNCTIONS) >= 13
    assert len(_CLASSES) >= 10


# ---------------------------------------------------------------------------
# (b) documented parameters exactly match the live signatures
# ---------------------------------------------------------------------------


@pytest.mark.parametrize("name,func", _PARAM_TARGETS, ids=_ids(_PARAM_TARGETS))
def test_documented_params_match_signature(name, func):
    documented = _documented_params(_clean_doc(func))
    actual = _signature_params(func)
    assert documented == actual, (
        f"{name}: Parameters section {documented} != signature {actual}."
    )


# ---------------------------------------------------------------------------
# (c) the exported surface equals the contract list
# ---------------------------------------------------------------------------


@pytest.mark.parametrize("name", CONTRACT_ALIASES + VERBATIM_ALIASES)
def test_contract_name_in_namespace_and_all(name):
    assert hasattr(datalib, name), f"datalib.{name} is missing."
    assert name in datalib.__all__, f"{name!r} is not exported in __all__."


@pytest.mark.parametrize("alias,target", sorted(ALIAS_TARGETS.items()))
def test_contract_alias_is_verbatim(alias, target):
    assert getattr(datalib, alias) is getattr(datalib, target), (
        f"datalib.{alias} must be the same object as datalib.{target}."
    )


def test_all_names_resolve_and_are_public():
    for name in datalib.__all__:
        assert hasattr(datalib, name), f"__all__ lists missing name {name!r}."


# ---------------------------------------------------------------------------
# (d) contract version pin
# ---------------------------------------------------------------------------


def test_contract_version_is_1():
    assert datalib.CONTRACT_VERSION == "1"
