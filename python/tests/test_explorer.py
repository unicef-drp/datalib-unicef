"""``datalib_explorer`` and ``datalib_index`` -- the arbitrary-tree functions.

Hermetic: a throwaway tree under ``tmp_path`` carrying the properties that actually
broke the Stata implementation -- a folder name with a SPACE, mixed casing, and a
file with no extension. Nothing here touches the network share.

The assertions deliberately mirror Stata's conformance cases x01-x18 and ix01-ix11,
because the whole point of porting is that the three legs agree. The one claim that
must hold identically in every leg -- the file-type dispatch -- is read from the
shared ``tests/cases_filekind.csv`` rather than typed out a third time.
"""

from __future__ import annotations

import csv
from pathlib import Path

import pytest

from datalib import datalib_explorer, datalib_index, file_kind
from datalib.errors import InvalidArgumentError, NotFoundError


@pytest.fixture()
def tree(tmp_path: Path) -> Path:
    (tmp_path / "Alpha Land" / "Deep One").mkdir(parents=True)
    (tmp_path / "SLV" / "SLV_2014_MICS").mkdir(parents=True)
    (tmp_path / "notes.txt").write_text("x", encoding="utf-8")
    (tmp_path / "table.DTA").write_text("x", encoding="utf-8")
    (tmp_path / "Alpha Land" / "NOEXT").write_text("x", encoding="utf-8")
    (tmp_path / "Alpha Land" / "Deep One" / "leaf.csv").write_text("x", encoding="utf-8")
    return tmp_path


def test_an_arbitrary_tree_opens_and_so_does_a_non_library_directory(tree: Path) -> None:
    node = datalib_explorer(root=tree)
    assert node.n_dirs == 2
    assert node.depth == 0
    assert node.parent == ""

    # "Alpha Land" holds no CCC/CCC_* pair, so it is emphatically not a library --
    # and must still open. The root itself DOES satisfy the library test, because
    # SLV/SLV_2014_MICS is exactly that pair; the Stata suite learned this the hard
    # way when a case asserted the opposite and failed.
    inner = datalib_explorer("Alpha Land", root=tree)
    assert inner.depth == 1
    assert inner.parent == "."


def test_casing_and_spaces_survive_and_depth_counts_separators(tree: Path) -> None:
    node = datalib_explorer(root=tree)
    assert "Alpha Land" in node.dirs  # not "alpha land"

    deep = datalib_explorer("Alpha Land/Deep One", root=tree)
    assert deep.path == "Alpha Land/Deep One"
    assert deep.parent == "Alpha Land"
    # Three words, two components. Stata's first implementation reported 4 here
    # because it counted words; the space is in the fixture for that reason.
    assert deep.depth == 2


def test_bytes_is_none_until_measured_because_zero_is_a_real_size(tree: Path) -> None:
    assert datalib_explorer(root=tree).bytes is None
    measured = datalib_explorer(root=tree, sizes=True)
    assert measured.bytes > 0
    assert measured.largest is not None


def test_max_items_caps_the_lists_but_never_the_counts(tree: Path) -> None:
    capped = datalib_explorer(root=tree, max_items=1)
    assert capped.truncated
    assert len(capped.files) == 1
    # The true totals must survive. A capped list beside an uncapped total with no
    # flag is how a caller comes to trust a partial answer -- the Stata leg shipped
    # exactly that in 0.9.21, where r(bytes) was a silent partial sum.
    assert capped.n_files == 2
    assert capped.n_dirs == 2


def test_looks_grammar_separates_renamed_branches(tree: Path) -> None:
    assert datalib_explorer("SLV/SLV_2014_MICS", root=tree).looks_grammar
    assert not datalib_explorer("Alpha Land", root=tree).looks_grammar


def test_a_missing_node_raises_rather_than_listing_nothing(tree: Path) -> None:
    # An empty listing is indistinguishable from an empty folder, so this must raise.
    with pytest.raises(NotFoundError):
        datalib_explorer("no/such/node", root=tree)


def test_max_items_must_be_positive(tree: Path) -> None:
    with pytest.raises(InvalidArgumentError):
        datalib_explorer(root=tree, max_items=0)


def test_open_with_reports_the_dispatch(tree: Path) -> None:
    node = datalib_explorer(root=tree)
    kinds = dict(zip(node.open_with["file"], node.open_with["kind"]))
    assert kinds["table.DTA"] == "describe"
    assert kinds["notes.txt"] == "view"


def test_the_file_kind_dispatch_matches_the_shared_corpus(repo_root: Path) -> None:
    """One corpus, read by every leg, rather than three hand-typed copies.

    It lives at the repo root deliberately: a copy inside the package would be a
    second copy free to drift, which is how the Stata help came to sit five
    releases behind the code it documented.
    """
    cases_path = repo_root / "tests" / "cases_filekind.csv"
    if not cases_path.is_file():
        pytest.skip("tests/cases_filekind.csv not found")
    with cases_path.open(encoding="utf-8", newline="") as fh:
        rows = list(csv.DictReader(fh))
    assert len(rows) > 10, "an empty corpus would pass silently"
    for row in rows:
        got = file_kind(row["ext"].lower())
        assert got == row["kind"], (
            f"{row['ext']}: {got} != {row['kind']} ({row['why']})"
        )


def test_index_walks_the_whole_subtree_in_one_call(tree: Path) -> None:
    idx = datalib_index(root=tree)
    assert len(idx) == 4  # every file, at every depth
    assert idx.attrs["n_files"] == 4
    assert idx.attrs["truncated"] is False
    assert "Alpha Land/Deep One/leaf.csv" in set(idx["relpath"])
    assert idx.loc[idx["name"] == "leaf.csv", "depth"].iloc[0] == 3
    assert idx.loc[idx["name"] == "notes.txt", "parent"].iloc[0] == "."


def test_index_no_extension_is_none_for_a_file_and_empty_for_a_folder(tree: Path) -> None:
    idx = datalib_index(root=tree, dirs=True)
    assert idx.loc[idx["name"] == "NOEXT", "ext"].iloc[0] == "none"
    assert (idx.loc[idx["is_dir"], "ext"] == "").all()


def test_index_flags_the_node_cap_and_warns(tree: Path) -> None:
    with pytest.warns(UserWarning, match="prefix"):
        capped = datalib_index(root=tree, max_nodes=1)
    assert capped.attrs["truncated"] is True
    assert capped.attrs["n_files"] < 4


def test_index_bytes_is_missing_until_measured(tree: Path) -> None:
    plain = datalib_index(root=tree)
    assert plain["bytes"].isna().all()
    measured = datalib_index(root=tree, sizes=True)
    assert (measured["bytes"] >= 0).all()


def test_index_max_depth_caps_the_descent(tree: Path) -> None:
    shallow = datalib_index(root=tree, max_depth=2)
    assert shallow["depth"].max() <= 2


def test_index_pattern_filters_files_not_traversal(tree: Path) -> None:
    # The trap: filtering the TRAVERSAL as well would return nothing here, because
    # the only .csv sits three levels down.
    only_csv = datalib_index(root=tree, pattern=r"\.csv$")
    assert len(only_csv) == 1
    assert only_csv["relpath"].iloc[0] == "Alpha Land/Deep One/leaf.csv"


def test_index_rejects_nonsense_limits(tree: Path) -> None:
    with pytest.raises(InvalidArgumentError):
        datalib_index(root=tree, max_nodes=0)
    with pytest.raises(InvalidArgumentError):
        datalib_index(root=tree, max_depth=-1)


def test_the_two_legs_agree_on_the_same_tree(tree: Path) -> None:
    """explorer's counts must match what index finds at depth 1.

    Cheap, and it catches the class of drift where one function's listing quietly
    diverges from the other's -- they read the same directories and must agree.
    """
    node = datalib_explorer(root=tree)
    idx = datalib_index(root=tree, max_depth=1, dirs=True)
    assert int((~idx["is_dir"]).sum()) == node.n_files
    assert int(idx["is_dir"].sum()) == node.n_dirs
