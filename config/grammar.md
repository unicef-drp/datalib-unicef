# datalib contract v1 — folder grammar and shared semantics

[← datalib README](../README.md) · [Documentation hub](../docs/README.md)

The language-neutral contract implemented by `stata/`, `r/`, and `python/`.
Contract version: **1** (see [collections.yml](collections.yml)).

## Folder-name grammar

```
<root>/<CCC>/                                            1 token
<root>/<CCC>/<CCC>_<YYYY>_<SSSS>/                        3 tokens ("_"-separated)
  master vintage:     <CCC>_<YYYY>_<SSSS>_v<MM>_M        5 tokens
  adaptation vintage: <CCC>_<YYYY>_<SSSS>_v<MM>_M_v<AA>_A_<HHHH>   8 tokens
inside a vintage:     Data/{Original,Stata,R,Other}  Doc/  Programs/
data files:           <vintage-folder-name>_<module>.dta   under Data/Stata/
```

Token positions when splitting on `_`: 1 country, 2 year, 3 survey,
4 master vintage (`v01`), 6 adaptation vintage, 8 collection.

**Token 3 carries sub-national identity; token 1 never does.** International assessments
admit participants that are not countries — IEA benchmarking entities (`BFL`/`BFR` for the
Belgian language communities, `CAB`/`CQU` for Alberta and Quebec) and PISA sub-national
economies. These are filed under the **parent country's ISO3** in token 1, with the entity
appended to token 3 after a **non-underscore separator**:

```
BEL/BEL_2016_PIRLS-BFL/BEL_2016_PIRLS-BFL_v01_M/Data/Stata/
    BEL_2016_PIRLS-BFL_v01_M_acg.dta
BEL/BEL_2016_PIRLS-BFR/BEL_2016_PIRLS-BFR_v01_M/...
```

Three constraints force this, each independently:

- **The token count is fixed** at 3/5/8. `BEL_2016_PIRLS_BFL` is four tokens, so every
  position after it shifts and `BFL` is read as a master vintage. The separator may be
  anything except `_`; the convention is `-`.
- **`_dl_islib` requires a `<CCC>_*` grandchild** (literally `dir "<child>_*"`). A survey
  folder named `BFL_2016_PIRLS` under `BEL/` does not match `BEL_*`, so putting the entity
  in token 1 defeats the structural library test.
- **`ctrycode` provenance must be a real ISO3.** Rule 4 adds `ctrycode` from the resolved
  country token. `BFL` is not an ISO3 and joins to no country reference table — region,
  income group, population all fail silently. `BEL` joins; the language community stays in
  the survey's identity, which is where it belongs.

Consequence for matching, by design: survey matching is exact-suffix (rule 1), so `PIRLS`
matches `BEL_2016_PIRLS` and **does not** match `BEL_2016_PIRLS-BFL`. They are distinct
surveys, and a caller asking for one does not silently receive the other.

## Shared semantics (all implementations)

1. **Normalise case once at the boundary — and not all in the same direction.**
   `country`, `survey`, `collection` inputs are trimmed and **uppercased** before any
   matching. Matching is **exact** (country) or **exact-suffix** (`*_<SURVEY>` for survey
   folders) — never substring.

   `module` is the exception. Module tokens are **lowercase on disk and in
   `config/collections.yml`** — a deposit convention. Only the **registry** half is enforced
   (a test asserts every module token in `collections.yml` is lowercase); nothing scans a
   deposit, so a mixed-case file on disk is caught only when a load fails to find it. The
   real archive currently contains such files — IEA deposits use `_ACG` — so this is a live
   gap, not a hypothetical one.
   `HLT` declares `household hhmembers adult children`; `IPUMS` declares
   `hh bh ch fs hl mn wm`; so an IEA-style module is `acg`, never `ACG`.

   A caller is **expected** to supply lowercase, but that expectation is not uniformly
   enforced, and this document is descriptive rather than aspirational:

   | leg | file | behaviour on a module argument |
   |---|---|---|
   | Python | `python/src/datalib/load.py` | lowercases — `str(m).strip().lower()` |
   | R | `r/R/datalib_load.R` | trims only — `trimws(as.character(module))` |
   | Stata | `stata/src/_/_dlw.ado` | passes the token through as given |

   So a caller who supplies `ACG` resolves the module in Python and gets a not-found error in
   R and Stata. See the Alignment status table; closing in v0.10.0.

   Cited by path and by a greppable literal, deliberately, not by line number: line numbers
   drift on every edit above them and a stale citation in the contract is worse than none.

   The asymmetry is not cosmetic. A collection is an identifier the operator types
   (`HLT`), whereas a module is part of a **file name**, and file names are where case
   becomes a portability bug: `python/src/datalib/load.py` builds `f"{rp.stem}_{module}.dta"`, so a lowercase
   registry token against an uppercase file on disk resolves on Windows and **fails on
   Linux and macOS**. Stata makes it worse — `: dir` lowercases names on Windows, so the
   Stata leg cannot observe the true case even where the filesystem would forgive it. A
   deposit with `..._ACG.dta` is therefore unreadable from Stata and unreadable on CI.

   Normalisation applies to the **request**, never to the lookup. A wrongly-cased file on
   disk must fail loudly rather than be found by a case-insensitive search: silently
   accepting it would hide a deposit error on the one platform that tolerates it and
   surface it later on someone else's.
2. **Vintages are integers.** Inputs accept `1`, `01`, `v01`, `V01`; internal/display
   form is `v%02d`. **"Latest" is the numeric maximum**, never directory-listing or
   alphabetical order (`v10` > `v09`).
3. **Defaults.** `year` omitted → numerically latest year among the country's matching
   survey folders. `master_version` omitted → latest master on disk.
   `adaptation_version` omitted → latest adaptation of the requested collection under
   the chosen master. The resolved vintage folder must exist (verified pre-load).
4. **Loaders never mutate data.** No recodes, no drops. Two documented schema
   additions only: (a) a person module whose registry `linevar` ≠ `line_number`
   has that variable renamed to `line_number` on load (normalization for
   merging), and (b) provenance columns `ctrycode` (country code) and `year`
   are added when absent — never overwritten — on every load, master and
   adaptation alike.
5. **Merge.** Person modules chain `1:1` on `keys_person`; hh modules attach `m:1` on
   `keys_hh` (`1:1` on `keys_hh` if only hh modules). Keys validated per module
   (`isid`-equivalent); failure → typed error naming the module. Unmatched rows are
   kept (outer join); the merge indicator is not retained.
6. **Error taxonomy.** A contract error is identified by its **name**, not by any
   one language's mechanism. Each language maps the names onto its own idiom, and
   **the mapping is not injective in every language** — stating otherwise is what
   let this table drift for four releases. The machine-readable form is
   [`tests/error_taxonomy.csv`](../tests/error_taxonomy.csv); this table must
   equal it row for row, and a test now enforces that.

   | contract error | Stata rc | R condition classes | Python exception |
   |---|---|---|---|
   | `input_invalid` | 198 | `datalib_error_input` | `InvalidArgumentError` |
   | `not_found` | 198 601 | `datalib_error_not_found` `datalib_error_input` | `NotFoundError` |
   | `config_file_missing` | 601 | `datalib_error_config_missing` | `ConfigFileNotFound` |
   | `user_block_missing` | 459 | `datalib_error_user_missing` | `UserBlockNotFound` |
   | `root_unset` | 198 | `datalib_error_root_unset` `datalib_error_input` | `DatalibRootNotSet` |

   How to read it, per language:

   - **Stata** has three usable codes for five errors, so the mapping *collides by
     construction*: `input_invalid`, `not_found` and `root_unset` all reach 198 in
     the ordinary case, and `not_found` and `config_file_missing` both reach 601.
     A caller cannot fully discriminate on `_rc` alone, and the contract does not
     pretend otherwise. Within `not_found` the two codes split by *what* is
     missing: **198** when the requested country / survey / vintage / file is
     absent from a library that exists, **601** when the library root or the
     directory being listed does not exist at all. Before v0.9.7 the 601 half was
     only reachable as an *unguarded leak* from a `: dir` extended function, which
     surfaced Stata's own message rather than a datalib one — the table documented
     an accident as if it were the design.
   - **R** returns a **class vector**, most specific first, and every specific
     class keeps the general one after it. So `datalib_error_not_found` also
     carries `datalib_error_input`, and a handler written against
     `datalib_error_input` before v0.9.7 keeps firing unchanged. Adding a subclass
     is therefore never a breaking change in R.
   - **Python** raises the listed class or a subclass of it: `NotFoundError` has
     `CountryNotFound`, `SurveyNotFound`, `VintageNotFound` and
     `FileNotFoundInLibrary` beneath it, and catching the parent catches all four.
     Python is the only leg whose mapping is injective.

   A caller wanting portable behaviour should therefore branch on the **contract
   error name** as expressed in its own language's idiom — the R class or the
   Python exception — and treat a Stata `_rc` as a hint rather than an identity.
7. **Library root resolution.** R and Python, in precedence order: explicit
   argument → environment variable `DATALIB_ROOT` → language option
   (R `options(datalib.root=)`) → **config resolution** → error. **Stata**, in
   precedence order: `root()` option → `${datalib}` session global (which
   `getuserconfig` / `datalib_config` fills from config resolution when unset —
   so a config-derived global outranks the env var once loaded) →
   `DATALIB_ROOT` → error.

   In all three languages this default resolution is **pure candidate
   selection**: the first candidate present wins, and the path is **not**
   checked on disk. A nonexistent root resolves successfully and is reported
   with the stage it came from; the failure surfaces later, when the library is
   read.

   **The contract pins the resolved identity, not its spelling.** The three
   implementations return the same *location* in different notations, and this
   is not a divergence to fix — it is each language's own path type showing
   through. Given `Z:/a/../b`, Stata returns the literal string, R returns
   `Z:/b` (`fs::path_norm` collapses `..`, expands `~`, strips a trailing
   separator), and Python returns a `Path` whose string form on Windows is
   `Z:\a\..\b`. Callers must therefore not compare a returned root
   byte-for-byte against a literal, and conformance cases compare **normalised**
   paths. What is pinned: the same input resolves to the same directory, with the
   same `source_stage`.

   **Config resolution is a two-file, key-presence search.** The current
   user's block is looked up first in `~/.config/user_config.yml` (the file
   shared with the CSO Toolkit) and then in `~/.config/datalib_config.yml`;
   the **first file whose user block carries a non-empty `datalib:` key wins**
   (block-level — keys are never merged across files, and an empty value counts
   as absent). A generic file that exists but lacks the key falls through to
   the package file. Where the root resolved from is reported: R via the
   `source_stage` / `source_file` attributes on the returned path, Python via
   `resolve_root(..., report=True)`, Stata via `r(source_stage)` /
   `r(source_file)` on `getuserconfig`. **The `source_stage` strings are drawn
   from one vocabulary, but not every stage exists in every language**, because
   the mechanisms genuinely differ — a Stata session global and an R option are
   not the same thing. The full vocabulary, and where each value can occur:

   | mechanism | stage string | Stata | R | Python |
   |---|---|---|---|---|
   | explicit argument | `argument` | yes | yes | yes |
   | env `DATALIB_ROOT` | `env` | yes | yes | yes |
   | session global `${datalib}` | `global` | yes | — | — |
   | R option `datalib.root` | `option` | — | yes | — |
   | `user_config.yml` | `config_generic` | yes | yes | yes |
   | `datalib_config.yml` | `config_package` | yes | yes | yes |
   | no `datalib:` key found | `unset` | yes | yes | — |
   | `find` discovery | `discovered` | yes | — | — |

   A caller must treat `source_stage` as a value from this table, never as a
   closed set of four. (Earlier text called the strings "byte-identical across
   languages" and then listed three exceptions; both halves could not be true.)

   **Stata-only `find` mode (opt in; the `datalib` front door uses it).** The
   default above is the contract and is what the CFG conformance cases pin.
   `datalib_root, find` additionally resolves the candidate *against the disk*,
   so that an operator's configuration may name the place the library is stored
   in rather than the library itself:

   - each candidate is tested in the same precedence order, and the **first**
     set candidate that is not a library **aborts** the resolution — it never
     falls through to a later candidate (`datalib_root.ado` sets `badcand` and
     exits 198). This is the same rule as the last bullet below, stated from the
     other end;
   - a candidate may name the library **or** its container — `<cand>/datalib` is
     tried first (`r(descended)`=1), then `<cand>` itself;
   - "is a library" is a structural test (`_dl_islib`): the directory is named
     `datalib`, or carries a `.datalib` marker, or holds a
     `<CCC>/<CCC>_<YYYY>_<SURVEY>` pair. An existing directory that is *not* a
     library is refused, so a missing library cannot silently resolve to its
     parent — whose subfolders would otherwise be read as country codes;
   - a candidate that **is** set but is not a library is an **error** naming it.
     The root an operator configured is never silently replaced, because the
     substitution would be invisible in `source_stage` on the next call;
   - only when **nothing** is configured is a library named `datalib` discovered
     under `${zDrive}` then `Z:/` (`source_stage`=`discovered`).

   R and Python are **not** expected to reproduce `find`; it is a convenience of
   the Stata `datalib` command, not part of the contract. The golden cases pass
   an explicit `root()` and are unaffected. See
   [`tests/DIVERGENCES.md`](../tests/DIVERGENCES.md).

   **Isolation hooks** (used by the CFG conformance cases, and available to
   callers): `DATALIB_CONFIG=<file>` consults exactly one file and disables the
   fallback; `DATALIB_CONFIG_DIR=<dir>` searches the two-file list in `<dir>`
   instead of `~/.config` (fallback preserved). Stata, which cannot set
   environment variables in-session, additionally accepts a `configdir()`
   option. The config directory is `~/.config` under `USERPROFILE` on Windows /
   `HOME` otherwise.

8. **A missing section directory is an empty listing, not an error.** When a
   resolved vintage exists but one of its section directories (`Doc/`,
   `Programs/`, `Data/Other/`, …) does not, `datalib_files` returns an empty
   list with count 0. Only the *vintage* resolution can raise not-found. Both the
   Stata and R implementations already cite this as contract behaviour in their
   source; it had never been written down here. Numbered 8 rather than inserted
   mid-list because `section 7` is cited by name from
   `r/R/datalib_config.R`, `python/src/datalib/config.py` and
   `.github/copilot-instructions.md` — renumbering it would silently
   redirect those citations.

9. **Enumerators pin the value set, not the container.** `datalib_countries`,
   `datalib_surveys`, `datalib_vintages` and `datalib_adaptations` each return
   their language's idiomatic type — Stata space-separated lists in `r()`, R data
   frames, Python tuples and dataclasses — and the contract **does not require
   those types to converge**. What it pins is the *set of values* each query
   yields.

   Conformance therefore compares a **normalised list**: the values, sorted, joined
   by single spaces. Which values, and in what order, is fixed per enumerator —
   "sorted" alone is not enough, because sorting the integers 9 and 10 as *text*
   yields `10 9`:

   | enumerator | the value set | order |
   |---|---|---|
   | `datalib_countries` | country codes | ASCII ascending |
   | `datalib_surveys` | survey folder names | ASCII ascending |
   | `datalib_vintages` | master version numbers | **numeric** ascending |
   | `datalib_adaptations` | collection names | ASCII ascending |

   All three languages reach the same string from their own return type in one
   expression, which is what makes a shared corpus possible at all — `BRA 2015
   PNAD` masters normalise to `9 10` in every leg, and `ZWE 2019 MICS` adaptations
   to `HLT IPUMS`. An empty value set is the empty string. Cases live in
   [`tests/cases_enumerate.csv`](../tests/cases_enumerate.csv).

   The corpus carries **no error rows**: whether an enumerator raises on an absent
   parent still differs by language (see the Alignment status table), so error
   behaviour is asserted per language instead, and the shared corpus stays green
   in all three.

   This is the same move rule 7 makes for paths (identity, not spelling), applied
   to return types. It is stated because its absence had a cost: a shared
   enumerator corpus was first attempted by matching the *container*, which cannot
   match more than one language, and was abandoned as impossible.

## Alignment status

**This document describes contract v1 as the three implementations behave
today.** It is deliberately *descriptive*, not aspirational: where the legs
differ, the difference is stated and attributed, never smoothed over into a
claim that is true of none of them. Two earlier passages did exactly that and
were withdrawn in v0.9.5 (see the notes in section 8).

Stata moved ahead of R and Python in v0.9.0-v0.9.3. The gap is being closed in
**v0.10.0**, which is also when `contract_version` becomes **2**. Until then:

| surface | Stata | R | Python | closing in |
|---|---|---|---|---|
| the 13 canonical commands | yes | yes | yes | shipped |
| two-file key-presence config search | yes | yes | yes | shipped (R: v0.9.4) |
| `DATALIB_CONFIG` / `DATALIB_CONFIG_DIR` hooks | yes | yes | yes | shipped |
| `source_stage` / `source_file` reporting | yes | yes | yes | shipped |
| subcommand front door (`datalib <sub>`) | yes | - | - | not planned (see below) |
| `find`-mode root resolution | yes | - | - | v0.10.0 |
| structural library test (`_dl_islib`) | yes | - | - | v0.10.0 |
| `.datalib` marker file | - | - | - | v0.10.1 |
| update check (`datalib , update` / `datalib_update()`) | yes | yes | yes | shipped (v0.9.11) |
| config bootstrap / writer | yes | - | - | v0.10.0 |
| startup-file writer | `profile.do` | `.Rprofile` planned | none by design | v0.10.0 |
| create proposes latest+1 vintage | - (`v01`) | - (`v01`) | yes | v0.10.0 |
| enumerators error on an absent parent | yes | yes | - | v0.10.0 |
| distinct error classes per contract error | no, and inherently | yes | yes | shipped (v0.9.7) |
| module request lowercased at the boundary | - (as given) | - (trim only) | yes | v0.10.0 |

The update check is present in all three, but note what it is **not**: it is
declared in [`surface.yml`](surface.yml) under `maintenance:`, not under
`commands:`, so it is **not** a fourteenth contract command. Which version you are
running, and where a newer one would come from, is a question about deployment
rather than about the folder grammar. Its shape also differs by necessity — a Stata
option that can reinstall in place, versus R and Python functions that report and
print the command, because installing over a loaded namespace or an imported module
is unsafe in those languages.

Three entries are **not** convergence targets. The `datalib <sub>` front door is
a Stata console affordance; R and Python callers already have namespaces
(`datalib::`, `dl.`) that serve the purpose. Python gets no startup-file writer
because every Python mechanism for one is interpreter-wide, which is a worse
trade than telling the operator to set `DATALIB_ROOT`. And **Stata cannot have
one error code per contract error** — it has three usable codes for five errors,
so the collisions listed in section 6 are permanent, not a gap awaiting work.

## Shared public surface

The machine-readable declaration of this surface -- every parameter of every
command, in all three languages, plus the `datalib` subcommand list and the
`source_stage` vocabulary -- is [`surface.yml`](surface.yml), and it is enforced:
the prose list below must name exactly the commands declared there, and each
language's parameters must match its column. The three columns differ today, and
that is deliberate: the file doubles as the work-list for the v0.10.0 argument
alignment.


`datalib_config` · `datalib_root` · `datalib_countries` · `datalib_surveys` ·
`datalib_vintages` · `datalib_adaptations` · `datalib_resolve` · `datalib_files`
(sections `data` · `data-original` · `data-r` · `data-other` · `doc` ·
`programs`, identical in all three languages) · `datalib_catalog` ·
`datalib_load` · `datalib_browse` · `datalib_create` · `datalib_map_drive`.
All 13 exist in Stata and Python; Python additionally exports the verbatim
aliases `getuserconfig` / `mapzdrive` (Stata keeps those as the original
commands; R exports the 13 canonical names only).

## Deployment topologies

The contract is written for a **single library root** (countries directly under
`<root>`, harmonization collections as adaptation folders inside the tree). The
UNICEF estate today also uses a **multi-root** deployment: one tree per thematic
domain (`Z:/datalib`, `Z:/datalib-hlt`, `Z:/datalib-edu`, `Z:/datalib-nut`,
`Z:/datalib-chp`). Both are valid:

- **Single root** — point `datalib:` (or `${datalib}` / `DATALIB_ROOT`) at the
  one tree; collections distinguish harmonizations inside it.
- **Multi-root (per-domain)** — each domain tree is its own conforming library;
  point the root at the domain tree you are working with, per call
  (`datalib, library(Z:/datalib-hlt) …`, `datalib_load, … root(Z:/datalib-hlt)`,
  `dl.load(..., root="Z:/datalib-hlt")`) or once per session.
  `datalib_catalog` inventories one root per call.

  **There is no per-domain config *key*.** A user block carries exactly one
  `datalib:` key. `getuserconfig` publishes a fixed set of globals
  (`githubFolder`, `teamsRoot`, `zDrive`, `zDriveUNC`, `datalib`) and silently
  discards every other key it parses, so a `datalib_hlt:` line in a config file
  reaches nothing. Those keys were shown in both templates as commented
  examples; they are **withdrawn**.

  Note the trap this hid: `${datalib_hlt}` *does* work in the HLT workflows —
  but because [`profile_datalib.do`](../profile_datalib.do) sets that global
  directly, not because any config key feeds it. An operator who adds
  `datalib_hlt:` to `user_config.yml` and expects `${datalib_hlt}` to appear gets
  silence. Per-domain trees are named **per call**, and per-domain *globals*, if
  wanted, are set in the profile.

Note for the Stata `find` mode above: discovery looks for a library named
literally `datalib`, so on a multi-root machine it selects the generic tree. A
per-domain tree is not discovered — name it explicitly, e.g.
`datalib, library(Z:/datalib-hlt) …` or `datalib_load, … root(Z:/datalib-hlt)`.
Because the structural test does not require the `datalib` name, a per-domain
tree passed explicitly resolves to itself.

Whether UNICEF consolidates to a single canonical root or keeps per-domain
roots is an open Standards-Board decision (see
[docs/GOVERNANCE_microdata_deposit.md](../docs/GOVERNANCE_microdata_deposit.md));
the contract supports both.

## Conformance

Golden cases live in [`tests/`](../tests/): every implemented language must pass
`cases_resolve.csv` and `cases_load.csv` against the committed fixture tree
unmodified. Known deliberate divergences from pre-contract Stata behavior are
recorded in [`tests/DIVERGENCES.md`](../tests/DIVERGENCES.md).

---

[← datalib README](../README.md) · [Documentation hub](../docs/README.md)
