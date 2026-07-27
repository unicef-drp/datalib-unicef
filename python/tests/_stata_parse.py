"""Parse the Stata sources as text, so CI can enforce Stata's surface.

The Stata leg has no CI licence, but `.ado` and `.sthlp` are plain text: the
implemented option set can be read straight out of each `syntax` declaration and
compared against ``config/surface.yml`` from Python, on every push. This is the
only reason Stata's surface can be guarded at all today.

Not a test module -- imported by ``test_surface.py``. Named with a leading
underscore so pytest does not collect it.

Six bugs were found while writing this against the real tree, each of which had
made the parse silently WRONG rather than failing:

1. ``syntax [, opt]`` hides the comma that separates positional from options
   INSIDE a bracket, so a bracket-counting depth tracker never cuts and the whole
   option block was read as positional. Only parens may meaningfully hide a comma.
2. An `.ado` may define several programs -- ``getuserconfig.ado`` defines the
   private ``_dl_parse_cfg`` *before* the public ``getuserconfig`` -- so "the
   first syntax line in the file" is the wrong one. Each ``syntax`` is bound to
   its enclosing ``program define`` and the program named like the file wins.
3. ``///`` means "discard the rest of THIS line and continue on the next", so an
   inline comment (``_ctrycheck.ado``: ``path(string) /// Required: Path to ...``)
   leaked its prose in as options. Stripping only a *trailing* ``///`` is not
   enough.
4. A dangling ``///`` before a blank line (``_vcheck.ado``) made a naive joiner
   swallow the following comment line; worse, a bare ``path`` from that comment
   overwrote the real ``path(string)``, corrupting the parse instead of failing.
   Continuations now stop at a blank or comment line, so the parser fails
   CLOSED: under-joining drops an option and the guard goes red, rather than
   inventing one. (Stata itself handles both files correctly -- verified by
   loading and running them -- so these were parser defects, not source defects.)
5. ``{opt lib:rary(string)}``, Stata's minimum-abbreviation form, was rejected by
   a regex that excluded ``:`` from the name.
6. Help files differ in convention: some carry a formal ``{synopthdr:Options}``
   table, others (``_adaptcheck``) name options only in the Syntax section. Every
   file has a Syntax section, so that is the uniform source; scoping to it also
   stops a prose ``{opt find}`` that refers to some *other* command from counting
   as documentation.
"""

from __future__ import annotations

import re
from pathlib import Path

_PROGDEF = re.compile(r"^\s*program\s+define\s+([A-Za-z_][A-Za-z0-9_]*)")
_TOKEN = re.compile(r"([A-Za-z_][A-Za-z0-9_]*)(\([^)]*\))?")
_DOCTOK = re.compile(r"\{(?:cmd|opt|opth)\s*:?\s*([A-Za-z_][A-Za-z0-9_:]*)(\([^)]*\))?\}")


def logical_lines(text: str):
    """Yield logical lines, joining ``///`` continuations conservatively."""
    lines = text.split("\n")
    i = 0
    while i < len(lines):
        cur = lines[i]
        while "///" in cur:
            cur = cur.split("///", 1)[0]          # rest of the line is a comment
            nxt_i = i + 1
            if nxt_i >= len(lines):
                break
            nxt = lines[nxt_i]
            if nxt.strip() == "" or nxt.strip().startswith("*"):
                break                              # continuation ends here
            cur = cur + " " + nxt
            i = nxt_i
        yield cur
        i += 1


def syntax_by_program(path: Path) -> dict[str, str]:
    """Map each program defined in the file to its first ``syntax`` line."""
    out: dict[str, str] = {}
    current: str | None = None
    for line in logical_lines(path.read_text(encoding="utf-8")):
        m = _PROGDEF.match(line)
        if m:
            current = m.group(1)
            continue
        s = line.strip()
        if s.startswith("syntax") and current and current not in out:
            out[current] = s
    return out


def _split_positional_options(syntax_line: str) -> tuple[str, str]:
    body = syntax_line[len("syntax"):].strip()
    depth = 0
    cut = None
    for i, ch in enumerate(body):
        if ch == "(":
            depth += 1
        elif ch == ")":
            depth -= 1
        elif ch == "," and depth == 0:
            cut = i
            break
    if cut is None:
        return body, ""
    return body[:cut], body[cut + 1:]


def parse_options(syntax_line: str) -> dict[str, bool]:
    """{canonical_option_name: takes_an_argument} from one ``syntax`` line.

    The UPPERCASE prefix in the source (``DRYrun``) marks only the minimum
    abbreviation Stata will accept; the canonical name is the whole token,
    lowercased.
    """
    _positional, raw = _split_positional_options(syntax_line)
    raw = raw.replace("[", " ").replace("]", " ")
    return {m.group(1).lower(): bool(m.group(2)) for m in _TOKEN.finditer(raw)}


def ado_options(ado_path: Path) -> dict[str, bool] | None:
    """Options of the public program in ``ado_path``, or None if args-based."""
    progs = syntax_by_program(ado_path)
    line = progs.get(ado_path.stem)
    if line is None:
        return None                                # e.g. _dl_islib uses `args`
    return parse_options(line)


def sthlp_syntax_section(sthlp_path: Path) -> str:
    """Text of the Syntax section: ``{title:Syntax}`` to the next ``{title:``."""
    text = sthlp_path.read_text(encoding="utf-8")
    m = re.search(r"\{title:Syntax\}", text)
    if not m:
        return ""
    rest = text[m.end():]
    nxt = re.search(r"\{title:", rest)
    return rest[:nxt.start()] if nxt else rest


def sthlp_tokens(sthlp_path: Path) -> set[str]:
    """Lowercased ``{cmd:}``/``{opt:}`` names appearing in the Syntax section."""
    return {
        m.group(1).replace(":", "").lower()
        for m in _DOCTOK.finditer(sthlp_syntax_section(sthlp_path))
    }


def dispatcher_subcommands(datalib_ado: Path) -> list[str]:
    """The ``local subcmds`` list from datalib.ado, in declared order."""
    for line in logical_lines(datalib_ado.read_text(encoding="utf-8")):
        m = re.match(r"\s*local\s+subcmds\s+(.*)$", line)
        if m:
            return m.group(1).split()
    return []
