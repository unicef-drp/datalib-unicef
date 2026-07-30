# Known divergences

[← datalib README](../README.md) · [Documentation hub](../docs/README.md) · [fixtures & dialect](README.md)

Two kinds of entry live here, kept apart on purpose:

1. **Legacy debt paid down** — pre-0.5 Stata behavior that contract v1 replaced.
   A closed ledger; the table below.
2. **Language-specific extensions** — behaviour one language offers that the
   others do not have *yet*. The normative statement lives in the contract
   itself ([config/grammar.md](../config/grammar.md)); this file only points at
   it. As of v0.9.5 the one entry of this kind is **withdrawn**: `find`-mode
   resolution is being promoted into contract v2 rather than sanctioned as a
   permanent divergence. Current per-language status is the
   [Alignment status table](../config/grammar.md#alignment-status).

## 1. Contract v1 vs pre-0.5 Stata behavior

The golden cases in this directory encode **contract v1** behavior
([config/grammar.md](../config/grammar.md)). Pre-0.5 Stata deliberately fails
several of them; do NOT "fix" a conformance failure by reintroducing the old
behavior. Fixed in Stata as of v0.5.0-dev (PR #7).

| # | Pre-0.5 Stata behavior | Contract v1 behavior | Cases |
|---|---|---|---|
| 1 | Multi-module merge computed sort keys, then blanked them → **unkeyed old-syntax `merge using`** (row-order alignment) | Explicit registry keys, validated per module (`isid`); person 1:1 then hh m:1; hard error naming the module when keys are missing/duplicated | l01–l03 |
| 2 | Loader silently ran `recode windex5 8=.` | Loaders never mutate values | `expect_windex8` in l01/l04–l06 |
| 3 | No vintage defaulting existed at all, and survey/year defaults took the *last folder in directory-listing order* (`word(list,-1)`), not a numeric maximum | Vintages and years default to the numeric maximum on disk | r03, r04, r07 |
| 4 | Country matched by **substring** with accidental case behavior (`ZW` could match ZWE; `zwe` failed on some paths) | Exact match, uppercase-once at the boundary | r05, r06 |
| 5 | `vm()`/`va()` unvalidated and defaultless (omitting them built a broken folder name) | Accept `1`/`01`/`v01`/`V01`; default to numeric latest on disk; resolved folder verified to exist | r02–r04, r07 |
| 6 | `master` option hard-blocked (`exit 198 "not supported"`) | Master vintages are first-class (resolve/files/load with `module()`/`filename()`) | r01, r04, r11, l05, l06 |
| 7 | `_mkdir` check mode created directories as a side effect | `datalib_create` without `create` is pure (reports paths, touches nothing) | wrapper test |
| 8 | `_svycheck` returned hardcoded counts and `"0"` sentinels | Enumerators return real lists and counts; empty list when none | wrapper tests |

## 2. WITHDRAWN in v0.9.5: `find` resolution as a "sanctioned divergence"

> **This entry has been withdrawn, not deleted.** It argued that `find`-mode
> resolution was a permanent Stata-only extension which R and Python were "not
> expected to reproduce". That is no longer the project's position: `find` and
> the structural library test are being **promoted into the contract** in
> v0.10.0, and R and Python gain both. The text is kept so a reader who
> remembers the old rule can see it retired rather than silently vanish.

What it said, and what is true now:

| the withdrawn claim | the position as of v0.9.5 |
|---|---|
| R and Python are *not expected* to reproduce `find` | They **will** reproduce it; tracked for v0.10.0 |
| `find` is a divergence, not a contract change | It is a **contract v2 feature**; `contract_version` 1 -> 2 lands with it |
| `datalib_root`'s default is "pure string selection" and *returns the path as given* | The first half holds (the default still does not touch the disk). The second half was **false in two of three languages** and is corrected in [`config/grammar.md`](../config/grammar.md) section 7: R normalises, Python returns a `Path`, only Stata is literal. The contract pins the resolved **identity, not its spelling**. |

What remains true and is *not* withdrawn:

- The `datalib:` config key still means **the library root**, so the shared
  `user_config.yml` needs no change for any of this.
- The other 12 wrappers are still strict: they take an exact `root()` and never
  descend or discover.
- `datalib`'s `library()` option still outranks every other source.

Until v0.10.0 the asymmetry is real, so it stays listed here rather than being
treated as done. The live status table is
[`config/grammar.md` "Alignment status"](../config/grammar.md#alignment-status);
the normative rules are section 7 ("Stata-only `find` mode").

Stata-side coverage is `run_conformance.do` Part 4 (**c01-c14**), which pins both
the contract default (c01-c04, including that a nonexistent `root()` still
resolves, as in R and Python) and the `find` behaviour (c05-c14).

**Coverage gap — CLOSED in v0.9.6.** The CFG golden cases used to live in
`stata/tests/test_config_resolution.do`, which `run_conformance.do` never called;
it ran only when hand-typed, and during v0.9.x it was cited as passing while
nothing had executed it. They are now **Part 6** of the single entry point, and
their bare `assert`s — which abort the run instead of tallying a failure — were
rewritten in the harness idiom. Coverage went up rather than across: the six
two-file search cases, plus `datalib_root` erroring when no key exists anywhere
(guarded against an ambient `DATALIB_ROOT`, like c04), `config()` pinning one
file, and the `global`/`argument` precedence stages.

## Real-data caveat (not a contract divergence)

In the production HLT tree, `ZWE 2019 MICS` `hhmembers` has `hh_line_number`
100% missing — its rows cannot be keyed, so any merge including it errors by
design (use `nomerge` or drop the module). The fixture library's `hhmembers`
carries valid keys and pins the **intended** behavior.

---

[← datalib README](../README.md) · [Documentation hub](../docs/README.md)

## explorer and index: ported, with one half that cannot port

`datalib_explorer` and `datalib_index` were Stata-only from 0.9.21 and 0.9.24. As of
**0.9.27 both exist in all three legs**, so they are no longer a divergence in
*capability*. What remains is a divergence in *product*, and it is not closeable:

| | Stata | R | Python |
|---|---|---|---|
| `index` | dataset | data.frame | DataFrame |
| `explorer` data | `r()` | list | `ExplorerNode` |
| `explorer` **display** | clickable SMCL | — | — |

Stata's `explorer` prints a listing whose folder and file names are hyperlinks: a folder
re-runs the command one level down, a `.dta` runs `describe using`, a text companion opens
in the viewer, anything else is handed to the OS. There is no console hyperlink in R or
Python, so that half has no equivalent and no shim is offered — pretending otherwise would
mean printing text that looks clickable and is not.

What ports is the data, which was always the substantive half; the Stata help has always
described its `r()` surface as "as much the point as the display". Where a Stata user clicks
a folder, an R or Python caller passes a longer `path`, which the returned `dirs` supports
directly. The file-type dispatch behind the hyperlinks is reported as `open_with` (R,
Python) so a caller can act on it without reimplementing it, and that classification is
pinned across all three legs by `tests/cases_filekind.csv` — one corpus, read by every
suite, rather than three hand-typed copies free to drift.

Neither function is in `config/surface.yml`'s `commands:` block, and deliberately: that
block is asserted to be exactly the 13 canonical contract commands, and both
`test_subcommands_are_exactly_the_canonical_commands` and the R export test take their
meaning from its membership. They are declared alongside `maintenance` instead, and both
the R and Python surface tests now accept any such block generically, so the next
non-contract function needs no test edit.

