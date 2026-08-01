"""Navigate folder trees that do **not** follow the datalib naming grammar.

Every other navigation path in this package reconstructs a folder's ancestry from
its own *name* -- the grammar encodes a survey's parents in the folder name, so
``MWI/MWI_2019_MICS6/`` can be rebuilt by counting underscores. That is correct
inside the grammar and useless outside it: a folder called ``raw datasets`` says
nothing about which survey it belongs to.

These two functions apply no library test and no name parsing. The only
precondition is that the directory exists.

**What differs from the Stata implementation.** Stata's ``datalib_explorer``
prints a *clickable* SMCL listing, and that half does not port -- there is no
console hyperlink in Python. What ports is the data, which was always the
substantive half; the Stata version's own help calls its ``r()`` surface "as much
the point as the display". Where a Stata user clicks a folder, a Python caller
passes a longer ``path``, which the returned ``dirs`` supports directly. The
file-type dispatch behind Stata's hyperlinks is reported as ``open_with`` so a
caller can act on it without reimplementing it.

``datalib_index`` has no such gap: both legs return a table, with the same
columns and the same meanings, which is what makes the shared conformance cases
possible.
"""

from __future__ import annotations

import os
import re
import time
from collections import deque
from dataclasses import dataclass, field
from pathlib import Path

import pandas as pd

from .errors import InvalidArgumentError, NotFoundError

__all__ = ["ExplorerNode", "datalib_explorer", "datalib_index", "file_kind"]

# Text formats a caller can read directly. The unobvious entries are the DHS and
# SPSS metadata companions -- dct frq frw map as var ivd sts inf -- which are
# plain text and are about a fifth of the archive this package indexes. Being
# able to read a codebook beside the data it describes is most of the value.
_VIEW_EXT = frozenset(
    """txt csv tsv dct frq frw map as var ivd sts inf sps sas do ado mata log md
    json yml yaml xml html htm dat asc raw sthlp lst nfo r rmd qmd py ipynb""".split()
)

_GRAMMAR = re.compile(r"^[A-Za-z]{3}_[0-9]{4}_[A-Za-z0-9-]+")


def _norm_root(p: str) -> str:
    """Forward-slash, and drop a trailing separator without eating a drive root.

    ``Z:/`` must stay ``Z:/``: stripped to ``Z:`` it would join as ``Z:name``,
    which Windows reads as "relative to the current directory on drive Z" rather
    than as an absolute path.
    """
    p = p.replace("\\", "/")
    while len(p) > 1 and p.endswith("/") and p[-2] != ":":
        p = p[:-1]
    return p


def _norm_rel(path: str | os.PathLike[str] | None) -> str:
    if path is None:
        return ""
    rel = str(path).replace("\\", "/")
    return rel.strip("/")


def file_ext(name: str) -> str:
    """Lowercased, dot-free extension of a basename; ``"none"`` when there is none.

    ``"none"`` rather than ``""`` so a caller branching on this can tell a file
    with no extension from a *directory* row, which gets ``""``. Collapsing both
    to the empty string is how that distinction gets lost.
    """
    base = os.path.basename(name)
    if "." not in base:
        return "none"
    return base.rsplit(".", 1)[1].lower()


def file_kind(ext: str) -> str:
    """What a caller can do with this file: ``describe``, ``view`` or ``open``.

    Mirrors Stata's ``_dl_fileaction`` so both legs classify identically. The
    buckets come from the real archive rather than from taste -- across its
    tens of thousands of files ``.dta`` is 31.5%, text companions about 22%, and formats
    neither language reads about 36%.

    An extensionless file is ``view`` *deliberately*, not by omission: in this
    archive those are fixed-width text extracts, so text is the correct guess.

    Parameters
    ----------
    ext : str
        Lowercased, dot-free extension, as returned by :func:`file_ext`.
        ``""`` and ``"none"`` are both treated as "no extension".

    Returns
    -------
    str
        ``"describe"`` for ``.dta``, ``"view"`` for text formats, ``"open"``
        for anything neither language reads.
    """
    if ext in ("", "none"):
        return "view"
    if ext == "dta":
        return "describe"
    if ext in _VIEW_EXT:
        return "view"
    return "open"


def looks_grammar(name: str) -> bool:
    """Does this name already parse as ``CCC_YYYY_SURVEY``?

    The useful test in a mixed tree: it separates branches someone has
    restructured from ones nobody has touched, without a second pass.
    """
    return bool(name) and _GRAMMAR.match(name) is not None


def _resolve_root(root: str | os.PathLike[str] | None) -> str:
    if root is not None:
        return _norm_root(str(root))
    # Deliberately not the library-validating resolver: that applies the
    # structural test these functions exist to bypass.
    from .config import datalib_config

    try:
        cfg = datalib_config()
        candidate = cfg.datalib
    except Exception:  # pragma: no cover - config absent is a normal state here
        candidate = None
    candidate = candidate or os.environ.get("DATALIB_ROOT") or ""
    if not candidate:
        raise InvalidArgumentError(
            "No tree to walk: pass root=, or set the datalib root. Unlike the "
            "other navigation functions this one does not require a datalib "
            "library -- any directory will do."
        )
    return _norm_root(str(candidate))


def _list_node(full: Path) -> tuple[list[str], list[str]]:
    """Child directory and file names, original casing, sorted."""
    dirs: list[str] = []
    files: list[str] = []
    with os.scandir(full) as it:
        for entry in it:
            if entry.is_dir():
                dirs.append(entry.name)
            else:
                files.append(entry.name)
    return sorted(dirs), sorted(files)


@dataclass
class ExplorerNode:
    """One node of an arbitrary tree.

    ``n_dirs``/``n_files`` are the **true** totals; ``dirs``/``files`` are capped
    at ``max_items``; and ``bytes``/``exts``/``largest`` describe the files
    actually returned, so they always agree with ``files``. ``truncated`` says
    when the two differ. Reporting a capped list alongside an uncapped total with
    no flag is how a caller comes to trust a partial answer.
    """

    root: str
    path: str
    fullpath: str
    parent: str
    depth: int
    dirs: list[str]
    n_dirs: int
    files: list[str]
    n_files: int
    exts: list[str]
    n_exts: int
    bytes: int | None
    largest: str | None
    largest_bytes: int | None
    is_empty: bool
    truncated: bool
    looks_grammar: bool
    open_with: pd.DataFrame = field(repr=False)


def datalib_explorer(
    path: str | os.PathLike[str] | None = None,
    *,
    root: str | os.PathLike[str] | None = None,
    sizes: bool = False,
    max_items: int = 400,
) -> ExplorerNode:
    """Inspect one node of any folder tree.

    Parameters
    ----------
    path : str or PathLike or None, optional
        Node relative to ``root``, used **exactly** as given -- no case
        folding, no separator guessing. ``None`` inspects the root itself.
    root : str or PathLike or None, keyword-only, optional
        Tree to walk; defaults to the configured datalib root. Unlike every
        other navigation function, no library test is applied to it.
    sizes : bool, keyword-only, default False
        Measure each file. Off by default: a size needs a ``stat`` per file,
        about 1.4 s each over the SMB share this package targets. When off,
        ``bytes`` is ``None`` rather than 0, because 0 is a real size and a
        caller must be able to tell *empty* from *not measured*.
    max_items : int, keyword-only, default 400
        Cap on how many folders and how many files are returned. ``n_dirs``
        and ``n_files`` still report the true totals, and ``truncated`` says
        when the cap bit.

    Returns
    -------
    ExplorerNode

    Raises
    ------
    NotFoundError
        The node is not a directory. An error rather than an empty listing,
        which on screen is indistinguishable from an empty folder.
    InvalidArgumentError
        ``max_items`` is not positive, or no root could be resolved.
    """
    if max_items < 1:
        raise InvalidArgumentError("max_items must be positive.")

    r = _resolve_root(root)
    rel = _norm_rel(path)
    full = Path(f"{r}/{rel}") if rel else Path(r)

    if not full.is_dir():
        extra = (
            " (path is relative to root and is used exactly as given)" if rel else ""
        )
        raise NotFoundError(f"Not a directory: {full.as_posix()}{extra}")

    dirs_all, files_all = _list_node(full)
    n_dirs, n_files = len(dirs_all), len(files_all)
    truncated = n_dirs > max_items or n_files > max_items
    dirs, files = dirs_all[:max_items], files_all[:max_items]

    exts = [file_ext(f) for f in files]
    total: int | None = None
    largest: str | None = None
    largest_bytes: int | None = None
    if sizes:
        sizes_list = []
        for f in files:
            try:
                sizes_list.append((full / f).stat().st_size)
            except OSError:
                sizes_list.append(0)
        total = sum(sizes_list)
        if sizes_list:
            i = max(range(len(sizes_list)), key=sizes_list.__getitem__)
            largest, largest_bytes = files[i], sizes_list[i]
        else:
            largest_bytes = 0

    depth = len(rel.split("/")) if rel else 0
    if depth == 1:
        parent = "."
    elif depth > 1:
        parent = rel.rsplit("/", 1)[0]
    else:
        parent = ""
    leaf = os.path.basename(rel) if rel else os.path.basename(r)

    return ExplorerNode(
        root=r,
        path=rel,
        fullpath=full.as_posix(),
        parent=parent,
        depth=depth,
        dirs=dirs,
        n_dirs=n_dirs,
        files=files,
        n_files=n_files,
        exts=sorted(set(exts)),
        n_exts=len(set(exts)),
        bytes=total,
        largest=largest,
        largest_bytes=largest_bytes,
        is_empty=n_dirs == 0 and n_files == 0,
        truncated=truncated,
        looks_grammar=looks_grammar(leaf),
        open_with=pd.DataFrame(
            {"file": files, "ext": exts, "kind": [file_kind(e) for e in exts]}
        ),
    )


def datalib_index(
    path: str | os.PathLike[str] | None = None,
    *,
    root: str | os.PathLike[str] | None = None,
    max_nodes: int = 400,
    max_depth: int = 0,
    dirs: bool = False,
    sizes: bool = False,
    pattern: str | None = None,
    verbose: bool = False,
) -> pd.DataFrame:
    """Walk a subtree recursively into a DataFrame -- one row per file.

    Where :func:`datalib_explorer` answers "what is in *this* folder", this
    answers "what is in this whole branch", which is the form you can group,
    merge or export.

    **The cost is real, and it is not this code.** Measured on the share this
    package targets, a walk costs about **0.35 s per folder**, near-constant
    across subtrees of very different size (a large branch in about nine minutes; a mid-sized branch faster still;
    a small branch faster again). That is SMB round-trip latency per directory open, and a single
    bulk enumeration is no faster -- PowerShell's ``Get-ChildItem -Recurse`` took
    538 s on the same subtree and found the same folders and files. So
    ``max_nodes`` defaults to 400 rather than infinity, and hitting it warns
    rather than passing silently: the result is a *prefix* of the subtree.
    Whole-archive work belongs in the scheduled catalogue, which pays the same
    per-folder cost in parallel and off-hours and stores checksums this function
    deliberately does not compute.

    Parameters
    ----------
    path : str or PathLike or None, optional
        Subtree to start from, relative to ``root``, used exactly as given.
        ``None`` walks from the root -- read the cost note above first.
    root : str or PathLike or None, keyword-only, optional
        Tree to walk; defaults to the configured datalib root. No library test
        is applied.
    max_nodes : int, keyword-only, default 400
        Stop after this many folders.
    max_depth : int, keyword-only, default 0
        Stop descending past this depth; the children of the starting node are
        depth 1. ``0`` means no limit.
    dirs : bool, keyword-only, default False
        Also emit a row per folder. Folders are traversed and counted either
        way.
    sizes : bool, keyword-only, default False
        Measure each file; see the cost note above.
    pattern : str or None, keyword-only, optional
        Regular expression matched against file **names**. Folders are always
        traversed regardless, or the walk could not reach a nested match --
        filtering the traversal too would silently return nothing for a deep
        pattern.
    verbose : bool, keyword-only, default False
        Report progress every 25 folders.

    Returns
    -------
    pandas.DataFrame
        Columns ``relpath parent name ext depth is_dir bytes looks_grammar``,
        with ``nodes n_files n_dirs truncated unreadable seconds root path`` in
        ``df.attrs``.

        ``truncated`` means the result is INCOMPLETE, for either reason: the node
        cap stopped the walk, or a directory could not be read. ``unreadable``
        counts the latter, so the two remain distinguishable. One flag to check
        beats two, and a partial index that announces nothing is the failure this
        function has already been corrected for once.

        There are deliberately **no** country or survey columns. The reason
        these functions exist is that these trees do *not* follow the naming
        grammar, so a built-in "component 1 is a country" would smuggle back
        the assumption they were written to avoid. Splitting ``relpath`` is one
        line and the caller's to name.

    Raises
    ------
    NotFoundError
        The starting node is not a directory.
    InvalidArgumentError
        ``max_nodes`` is not positive, or ``max_depth`` is negative.
    """
    if max_nodes < 1:
        raise InvalidArgumentError("max_nodes must be positive.")
    if max_depth < 0:
        raise InvalidArgumentError("max_depth must be non-negative; 0 means no limit.")

    r = _resolve_root(root)
    rel = _norm_rel(path)
    start = Path(f"{r}/{rel}") if rel else Path(r)
    if not start.is_dir():
        raise NotFoundError(f"Not a directory: {start.as_posix()}")

    started = time.monotonic()
    rx = re.compile(pattern) if pattern else None

    # A worklist, not recursion: recursion depth is finite and a whole-archive tree is
    # not, and a queue makes the node cap exact.
    #
    # deque, not list. list.pop(0) is O(n), so a wide tree -- exactly the target workload
    # -- turns the walk quadratic in queue length. Irrelevant beside 0.35 s of I/O per
    # folder, but free to avoid.
    queue: deque[tuple[str, int]] = deque([(rel, 0)])
    rows: list[dict[str, object]] = []
    nodes = n_files = n_dirs = 0
    truncated = False
    unreadable: list[str] = []

    while queue:
        if nodes >= max_nodes:
            truncated = True
            break
        cur, cur_depth = queue.popleft()
        nodes += 1

        here = Path(f"{r}/{cur}") if cur else Path(r)
        try:
            kids, files = _list_node(here)
        except OSError:
            # A directory that exists but cannot be read is not an empty directory, and
            # must not be reported as one -- so it is RECORDED. An earlier version
            # `continue`d here, which did precisely what the comment forbade: it returned
            # a partial index with nothing set for a caller to test.
            unreadable.append(cur or ".")
            continue

        if rx is not None:
            files = [f for f in files if rx.search(f)]

        n_files += len(files)
        n_dirs += len(kids)
        parent_lab = cur if cur else "."

        for f in files:
            size: float | None = None
            if sizes:
                try:
                    size = (here / f).stat().st_size
                except OSError:
                    size = 0
            rows.append(
                {
                    "relpath": f"{cur}/{f}" if cur else f,
                    "parent": parent_lab,
                    "name": f,
                    "ext": file_ext(f),
                    "depth": cur_depth + 1,
                    "is_dir": False,
                    "bytes": size,
                    "looks_grammar": looks_grammar(f),
                }
            )

        for k in kids:
            if dirs:
                rows.append(
                    {
                        "relpath": f"{cur}/{k}" if cur else k,
                        "parent": parent_lab,
                        "name": k,
                        "ext": "",
                        "depth": cur_depth + 1,
                        "is_dir": True,
                        "bytes": None,
                        "looks_grammar": looks_grammar(k),
                    }
                )
            if max_depth == 0 or cur_depth + 1 < max_depth:
                queue.append((f"{cur}/{k}" if cur else k, cur_depth + 1))

        if verbose and nodes % 25 == 0:
            print(
                f"  {nodes:6d} folders visited, {n_files:7d} files, "
                f"{len(queue):6d} queued"
            )

    columns = [
        "relpath",
        "parent",
        "name",
        "ext",
        "depth",
        "is_dir",
        "bytes",
        "looks_grammar",
    ]
    df = pd.DataFrame(rows, columns=columns)
    # `truncated` means INCOMPLETE, from either cause -- the node cap or a directory that
    # could not be read. One flag to check is better than two, and `unreadable` says which
    # applied.
    truncated = truncated or bool(unreadable)
    df.attrs.update(
        nodes=nodes,
        n_files=n_files,
        n_dirs=n_dirs,
        truncated=truncated,
        unreadable=len(unreadable),
        seconds=time.monotonic() - started,
        root=r,
        path=rel,
    )

    if unreadable:
        import warnings

        shown = ", ".join(unreadable[:3])
        more = f" (and {len(unreadable) - 3} more)" if len(unreadable) > 3 else ""
        warnings.warn(
            f"{len(unreadable)} director"
            f"{'y' if len(unreadable) == 1 else 'ies'} could not be read and "
            f"{'its' if len(unreadable) == 1 else 'their'} contents are missing from this "
            f"index: {shown}{more}. Marked truncated; see df.attrs['unreadable'].",
            stacklevel=2,
        )

    if truncated and nodes >= max_nodes:
        import warnings

        # Say what the number IS. The walk is breadth-first, so the queue holds
        # only the frontier already discovered; the children of folders never
        # visited were never enumerated, so the true remainder is larger and
        # unknowable until the walk finishes.
        warnings.warn(
            f"stopped at the max_nodes cap of {max_nodes} folders. At least "
            f"{len(queue)} more were already queued, and the children of "
            f"unvisited folders were never listed, so the true remainder is "
            f"larger. This result is a prefix of the subtree.",
            stacklevel=2,
        )

    return df
