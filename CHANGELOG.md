# Changelog

All notable changes to **datalib-unicef**. Versioning follows [SemVer](https://semver.org/);
commits follow Conventional Commits.

## [0.9.31] — 2026-08-01

The public distribution's CI was red, and its PRs had been merging without a green check.
Two unrelated causes, found by looking at the closed PRs rather than at the code.

### Why no PR on the public repo ever showed a check

**#1 and #2 merged while Actions was billing-blocked org-wide.** Zero runs fired, so there
was no status to display — not a failing check, an absent one.

**#3 and #4 ran CI and it failed** on one test, `test_stamps.py`.

**And all four merged regardless, because `required_status_checks` is `NONE` on both
repositories.** Protection blocks direct pushes and enforces admins, but does not gate on
CI. That was rational while Actions was dead for months — requiring checks that could never
pass would have blocked all work — and is worth revisiting now that CI runs.

### Why the stamp test cannot pass in a generated repository

It polices release discipline: a file's `*!` stamp must be at least the `VERSION` in effect
at the commit that last changed that file. That question is unanswerable in the public tree,
where **each sync is one commit touching hundreds of files** — so every file appears to have
changed at that release, and every stamp below it is reported stale.

`datalib_resolve.ado` stamps 0.9.3 and genuinely has not changed since; its only appearance
in public history is the 0.9.19 sync commit, so the test called it stale.

Not the shallow-clone problem fixed in 0.9.30. The commits it named were real; the *history
shape* was wrong for the question.

So the test is now **withheld from the public tree**, alongside the sanitiser itself, which
is excluded for the same reason: it is a `-dev` concern. Withheld rather than made skippable,
because "is this history synthetic?" has no reliable test, and a guard that cannot answer
should not ship somewhere it will only ever produce false failures. It stays in force where
it means something.

This is the **fourth** distinct failure mode in that one guard: it did not exist while
`datalib.sthlp` drifted five releases; it compared against the wrong commit for uncommitted
files (0.9.23); it produced false failures under a shallow checkout (0.9.30); and it cannot
answer at all in a squashed distribution. Each time the fix has been to narrow what it
claims to know.

## [0.9.30] — 2026-08-01

**CI ran for the first time since v0.9.4**, the monthly Actions quota having reset, and it
immediately found a test that produces FALSE FAILURES under the standard CI checkout.

R passed on both platforms. All four Python jobs failed, claiming files like
`datalib_resolve.ado` — stamped 0.9.3 and untouched for months — had "changed in 0.9.29".

`actions/checkout@v4` defaults to `fetch-depth: 1`. `test_stamps.py` asks git which
release last changed each file, and with a single commit available `git log -1 -- <file>`
returns the tip for **every** file, so every stamp below the current VERSION is reported
stale. Reproduced locally with `git clone --depth 1` before changing anything:

```
is-shallow: true    commits available: 1
git log -1 -- stata/src/d/datalib_resolve.ado  ->  3ec686a (VERSION there: 0.9.29)
its actual stamp: *! Version: 0.9.3
```

Two fixes, because either alone leaves the trap armed:

- `fetch-depth: 0` on both workflow jobs, so the test has the history it needs.
- The test now **skips on a shallow clone**, naming the reason. Depth can be reduced again
  by anyone editing the workflow, and a test that then reports confident nonsense is worse
  than one that admits it cannot tell. Verified both ways: 3 passed on a full clone, 1
  skipped on a shallow one.

This is the third distinct failure mode found in this one guard — it previously compared
against the wrong commit for uncommitted files (0.9.23), and before that did not exist at
all while `datalib.sthlp` drifted five releases. The guard is worth keeping; it just keeps
needing to be told what it cannot know.

## [0.9.29] — 2026-08-01

Three findings from the automated review on the public sync PR, and two rejected with
measurements.

### Accepted

**An unreadable directory vanished silently.** `datalib_index` in Python caught `OSError`
and `continue`d — directly contradicting the comment immediately above it, which said a
directory that cannot be read "must not be reported as" empty. It returned a partial index
with nothing a caller could test. That is the same failure this function was already
corrected for once, in 0.9.21, when `r(bytes)` was a silent partial sum.

Unreadable directories are now counted, named in a warning, and exposed as
`df.attrs["unreadable"]`. `truncated` is widened to mean **incomplete for either reason** —
the node cap, or a directory that could not be read — so a caller has one flag to check
rather than two, with `unreadable` distinguishing which applied.

Verified the hard way: the new test was run against the old `continue` and confirmed to
fail, then against the fix and confirmed to pass. A regression test that has never failed
is a guess.

**`queue.pop(0)` was O(n)**, making a wide tree quadratic in queue length — and a wide tree
is precisely the documented workload. Now a `collections.deque`. Immaterial beside 0.35 s of
I/O per folder, but free.

**`config/surface.yml` still called explorer and index "Stata-only"** in the header comment
of blocks that have declared R and Python implementations since 0.9.27. Only the *clickable
display* is Stata-only, and the comment now says so.

### Rejected, with the measurement

The review reported `max_depth`/`maxdepth()` as off by one in both R and Stata: that
`cur_depth + 1 < max_depth` "prevents visiting directories at depth == max_depth", so
`max_depth(1)` would not return the starting node's children.

Measured against a four-level tree instead of reasoned about:

| `max_depth` | file depths returned | dir depths returned |
|---|---|---|
| 0 | 1,2,3,4 | 1,2,3 |
| 1 | 1 | 1 |
| 2 | 1,2 | 1,2 |
| 3 | 1,2,3 | 1,2,3 |

`max_depth = 1` returns exactly the starting node's children, which is what the
documentation promises. The claim conflates **emitting a row** for a child with
**descending into** it: the row is emitted while processing the *parent*, and enqueueing
only controls whether that child's own contents get listed. Refusing to enqueue a depth-1
directory still yields its row — it just produces no depth-2 rows, which is what "stop
descending past this depth" means.

No change made, in either leg.

## [0.9.28] — 2026-07-30

R gains a package overview page and a runnable tour. Nothing in any leg's behaviour
changes: this release is documentation that **ships inside the installed package**, which
is why it needs a version rather than riding along.

### `?datalib` is now a real overview page

CRAN-shaped, because that is what an R user expects to land on: the grammar in one line
and one diagram, all sixteen exported functions in five task-grouped tables (*where is
the library / what is in it / which files and give me the data / trees that ignore the
grammar / housekeeping*), a how-to in three steps, the install-and-upgrade note, and
runnable examples.

Two rules are stated there because they are the ones that surprise people:

- **Enumerators return empty; resolvers raise.** Asking a country for a survey it does
  not have is a legitimate question with the answer "none", so `datalib_surveys()`
  returns zero rows. Asking `datalib_resolve()` for a vintage that does not exist is a
  mistake, so it errors. "No results" and "you asked about something that does not exist"
  must not look the same.
- **Errors are typed.** Match `datalib_error_not_found`, not an English message.

### A guided tour that proves its own completeness

`system.file("examples", "datalib_demo.R", package = "datalib")` — fifteen sections,
every exported function exercised.

Three properties worth keeping if it is ever edited:

- **Self-contained.** It builds a small library under `tempdir()` with
  `haven::write_dta()` rather than pointing at `Z:/datalib`, so it runs on a laptop with
  no share mounted and prints the same thing every time. The real share is used only in
  the last section, where an un-curated tree is the whole point, and skipped when absent.
- **Self-verifying.** Section 14 compares what it called against
  `getNamespaceExports("datalib")` and names anything missed. A demo claiming to show
  "all features" while quietly skipping one is worse than a demo that admits its scope,
  so the claim is checked: **16 exported, 16 exercised**.
- **Side-effect-safe.** The two functions that can change a machine appear in their
  harmless mode, called out where they appear: `datalib_create(create = FALSE)` (the
  default — reports the path, writes nothing) and `datalib_map_drive(dry_run = TRUE)`,
  which is **not** the default and would really map a drive.

### Two bugs in the demo's own data, both instructive

Neither was a datalib bug; both are now comments in the demo, because the errors were
better teachers than prose would have been.

- `datalib_resolve("KEN")` failed with *"No master vintage found under KEN_2014_DHS"*.
  The fixture gave KEN an adaptation and no master. An adaptation derives from a master,
  so a library holding one without the other is malformed — and datalib says so instead
  of guessing. The demo library now carries both, for two surveys, which also makes
  "omit the year and survey" a real demonstration of numeric-latest defaults.
- `datalib_load(module = c("household", "children"))` refused: *"key variable(s) svy_id,
  cluster_id, household_id missing"*. The synthetic modules carried invented column
  names. Merge keys come from the collection registry (`config/collections.yml`), never
  from guessing, and keys must uniquely identify rows or the merge stops rather than
  silently multiplying them. The demo data now satisfies the registry — `household` at
  household level, `hhmembers` reading its line variable from `hh_line_number` — and
  merging 3 households with 6 children correctly yields 6 rows at person grain.

### Local CI: `scripts/verify.ps1`

Actions has been billing-blocked org-wide since v0.9.4 — every job in
`conformance.yml` fails in ~2 seconds with **zero steps**, the signature of a job that
never started. The plan called for *"one `scripts/verify` entry point, results pasted
into each PR"* and it was never built, so three commands were being run by hand each
release. That is how `pyproject.toml` came to be left behind in 0.9.21.

One command, four checks, ordered to fail fastest:

| | checks |
|---|---|
| version manifests | seven patterns across six files, including `datalib.ado` **twice** — the `*!` stamp and the `RUNNING` literal |
| python | `pytest python` |
| R | `testthat::test_local()` |
| `R CMD check --as-cran` | behind `-Full`, because it is slow |

Two properties that matter more than the checks themselves. It **parses pass/fail
counts** rather than trusting exit codes — a summary line is evidence, an exit code is a
claim, and in this toolchain exit codes have lied. And it **states that the Stata leg is
not run**, printing the manual command, rather than silently omitting a third of the
contract.

`pwsh scripts/verify.ps1 -Full` ends by printing a markdown block to paste into the PR.

**Six Windows-specific traps had to be fixed to get it working**, each now recorded in
the script so the next reader does not rediscover them:

1. `R` in PowerShell is an **alias for `Invoke-History`**, so `& R CMD build` never ran R.
2. `Rscript -e` with a multi-line string loses its newlines → *"unexpected end of input"*.
3. `Set-Content -Encoding utf8` writes a **BOM** → R: *`unexpected input in "<U+FEFF>"`*.
   The third time this BOM has bitten in this repo; it also corrupted a published
   `VERSION` manifest on the share.
4. `testthat::test_local(path = ".")` dies inside `path.expand()`; an absolute path works.
5. `Push-Location` does not change what a **child process** inherits, so `pkgload` found
   no `DESCRIPTION`. The package path is embedded now.
6. `R CMD build` ignores `Push-Location`, `[IO.Directory]::SetCurrentDirectory` **and**
   `Start-Process -WorkingDirectory`, dropping its tarball in the shell's own directory
   two levels above the package. The first attempt to locate it afterwards was off by one
   level.

### Docs: the R install line now says `utils::install.packages`

Reported from a real session, and worth documenting rather than fixing, because the bug
is not ours.

Plain `install.packages("Z:/.../datalib_0.9.27.tar.gz", repos = NULL, type = "source")`
**installs correctly** and then, in **RStudio only**, throws:

```text
* DONE (datalib)
Error in file(con, "r") : cannot open the connection
1: In packageDescription(pkgName, lib.loc = dirname(pkgPath)) :
     no package 'datalib_0.9.27.tar.gz' was found
2: cannot open file 'Z:/.../datalib_0.9.27.tar.gz/DESCRIPTION'
```

RStudio hooks `utils::install.packages` to record where each package came from. In the
local-file branch (`resources/app/R/Tools.R:2362`) it passes the **tarball path** to
`.rs.recordPackageSource`, and `recordPackageSourceImpl` (`Tools.R:2078`) assumes that
path is an *installed package directory*:

```r
pkgName <- basename(pkgPath)                                     # "datalib_0.9.27.tar.gz"
pkgDesc <- packageDescription(pkgName, lib.loc = dirname(pkgPath))
```

`basename()` of a tarball is not a package name and `<tarball>/DESCRIPTION` does not
exist, so the bookkeeping fails *after* `eval(call)` has already installed the package.
It fires on any single local-file install, in any package.

`r/README.md` now documents the `utils::` prefix, which calls the real function directly
and skips the hook — the bypass RStudio itself documents on its neighbouring
`remove.packages` hook. `R CMD INSTALL` is given as the shell-side equivalent.

**How it was found, and how it should have been found.** Ten probes went into trying to
reproduce it — none could, because `Rscript` never has RStudio's hooks. Two hypotheses
were wrong and stated too early: the VS Code R extension's task callbacks (the extension
contains no such call, and `removeTaskCallback` returned `FALSE` — nothing was
registered), and a dangling `file/connection` object in the operator's saved workspace
(`rm()`-ing it changed nothing). A single `traceback()` gave the whole answer:

```text
5: file(con, "r")
4: readLines(descPath, warn = FALSE)
3: .rs.recordPackageSourceImpl(pkgPath, db, local)
2: .rs.recordPackageSource(pkgs, local = TRUE)
1: install.packages(...)
```

Ask for the traceback first.

Two other things in the same README section that were wrong or missing:

- It claimed `datalib_update()` "prints the exact command for whatever version the site
  currently holds". It does not — it reports `status` and nothing more. The claim is
  replaced with what the function actually does, plus why it deliberately does not
  install (`install.packages()` over a loaded namespace is unsafe on Windows, where the
  running session locks the package's own files).
- `repos = NULL` resolves no dependencies, unlike Stata's `net install`, which has no
  dependency concept because everything is in the `.pkg`. The three `Imports` are now
  listed so a fresh machine does not meet a bare `there is no package called 'fs'`.

No version bump. The README does ship inside the tarball, so the published 0.9.27
carries the older text — but the install line is read from the repo or a pasted snippet,
never from `system.file("README.md")` of an already-installed package. Unlike 0.9.22,
where behaviour differed and a bump was mandatory, this is documentation lag with no
user-visible consequence.

## [1.0.0] — planned

**Not released.** This entry exists so the criteria live in the repo rather than
in a conversation, and so the question stops being re-litigated each release.
1.0.0 means "the three ports implement one frozen contract, and breaking it now
costs a major version" — not merely "the number after 0.9".

The gate, all of which must be true:

- [ ] The [Alignment status table](config/grammar.md#alignment-status) has no open
      gaps, other than the entries marked as deliberate non-targets.
- [ ] `contract_version` is **2**, frozen, and pinned by all three synced copies.
- [x] The error taxonomy is true of the code, not aspirational, and has an
      enforcer in every leg (v0.9.7).
- [x] Enumerator return semantics are settled in the contract (v0.9.7, rule 9).
- [ ] **CI is actually green.** Actions has been billing-blocked org-wide since
      v0.9.4, so no commit in the 0.9.x line was verified by anything but a local
      run of the three suites. A 1.0.0 that claims stability with the two
      CI-runnable legs unverified is not credible. Needs the org billing fixed;
      `windows-latest` is already in the matrix (v0.9.7) so the platform that
      matters is covered on the first green run.
- [ ] The install path is settled: either the repository is public (which needs
      the third-party-data licence carve-out for the World Bank PDFs under
      `docs/pdf/`), or `Z:/_pkg/datalib` is accepted as canonical and the GitHub
      `net install` URL stops being documented as though it resolves.

Sequencing: **v0.10.0** the three-language alignment and contract v2 (with the
breaking argument renames), **v0.10.1** the `.datalib` marker rollout, then 1.0.0
when the boxes above are ticked. The renames invert polarity in two places
(`merge` → `nomerge`, `dry_run` → `create`), and 0.x is the right regime for that:
after 1.0.0 the same change would require 2.0.0.

## [0.9.27] — 2026-07-29

`explorer` and `index` reach **R and Python**. Both were Stata-only since 0.9.21 and 0.9.24.

### What ported, and the half that cannot

`index` ports whole: all three legs return a table with the same columns and the same
meanings — `relpath parent name ext depth is_dir bytes looks_grammar` — which is what makes
one set of cases able to check all three.

`explorer` ports its **data** and not its **display**. Stata's version prints a listing whose
names are hyperlinks; there is no console hyperlink in R or Python, so that half has no
equivalent and no shim is offered — printing text that looks clickable and is not would be
worse than plainly lacking the feature. What ports is what the Stata help always called "as
much the point as the display": the returned surface. Where a Stata user clicks a folder, an
R or Python caller passes a longer `path`, which the returned `dirs` supports directly, and
the file-type dispatch behind the hyperlinks is reported as `open_with` so callers need not
reimplement it.

```r
node <- datalib_explorer("Afghanistan", root = "<staging-tree>")
idx  <- datalib_index("Afghanistan", root = "<staging-tree>")
table(idx$ext)
```

```python
node = datalib_explorer("Afghanistan", root="<staging-tree>")
idx = datalib_index("Afghanistan", root="<staging-tree>")
idx["ext"].value_counts()
```

Every decision the Stata leg had to be corrected for is carried over rather than
rediscovered: `bytes` is `NA`/`None` until measured because 0 is a real size; `max_items`
caps the lists while the counts stay whole; `max_nodes` **warns** that the result is a prefix;
`pattern` filters files but never the traversal, or a deep match could not be reached; a
missing node raises rather than returning an empty listing.

### One corpus instead of three copies

`tests/cases_filekind.csv` now holds the file-type dispatch — 25 rows of `ext,kind,why` —
and **all three suites read it**. Stata's case x18 previously carried a hand-typed list; it
reads the shared file now. A bucket that moves in one leg and not the others fails everywhere
instead of drifting quietly, which is how `datalib.sthlp` once came to sit five releases
behind the code it documented.

Writing it exposed a trap worth noting: the first version had commas inside the unquoted
`why` column, so R's `read.csv` shifted `kind` to prose and the test failed with a diff full
of explanations. For a corpus three languages must parse, the commas are simply gone.

### Declared, not bolted on

Neither function goes into `surface.yml`'s `commands:` block. That block is asserted to be
exactly the 13 canonical contract commands, and both
`test_subcommands_are_exactly_the_canonical_commands` and the R export test take their
meaning from its membership — two entries there would push the canonical count to 15 and
quietly destroy both guards. They are declared alongside `maintenance`, and both surface
tests now accept any such block **generically**: a test that must be edited to accept
correct code is one people learn to edit rather than to trust.

### A packaging defect the CRAN gate caught

`R CMD check --as-cran` reported 7 `.pytest_cache` entries inside the built R tarball. The
repo `.gitignore` does not catch them either — it is an allowlist whose `!*/` rule re-includes
every directory, so the cache was untracked but not ignored. There was no `r/.Rbuildignore`
at all; there is now, and the tarball is clean. Status: **0 ERRORs, 0 WARNINGs**, and the
remaining NOTEs are environmental (new submission, no pandoc, unverifiable clock).

### Tests

Stata **156/156, 0 skipped**; R gains 37 assertions in `test-explorer.R`; Python gains 17 in
`test_explorer.py`. The R and Python fixtures carry the same properties that broke the Stata
implementation — a folder name with a space, mixed casing, a file with no extension — and the
Python suite adds a cross-check that `explorer`'s counts equal what `index` finds at depth 1,
since the two read the same directories and must agree.

## [0.9.26] — 2026-07-29

File names in `explorer` are now working hyperlinks, and long listings can be read a page at
a time.

### Clickable file names, with an action chosen from what Stata can actually do

A hyperlink that merely looks like one is worse than plain text: it invites a click and does
nothing. So the action dispatches on type, and the buckets come from the archive rather than
from taste — across the tens of thousands of files in the inventory:

| | share | click runs |
|---|---|---|
| `.dta` | 31.5% | `describe using` |
| text companions (`.dct` `.frq` `.frw` `.map` `.as` `.var` `.ivd` `.sps` `.csv` `.do` `.txt` `.dat`) | ~22% | `view` |
| everything Stata cannot read (`.sav` `.zip` `.doc` `.xls` `.pdf` `.sas7bdat` `.xlsx` `.docx`) | ~36% | handed to the OS |

`describe using` rather than `use`, deliberately: clicking a name in a file browser should
not silently replace the data in memory. It answers *what is in this?*, which is the question
someone exploring an archive is asking, and loading it is then one command away and theirs to
type.

Being able to open a `.dct` or `.frq` beside the `.dta` it describes is most of the point —
those DHS and SPSS companions are a fifth of the archive and were previously dead text.

New internal `_dl_fileaction.ado`, as its own packaged file rather than a subroutine, because
the dependency guard added in 0.9.23 now forbids the latter: a program defined inside another
file cannot be autoloaded and raises `r(199)` on a clean install, exactly as `_uc_dirs` did.

### A guard that measurement shrank

The first draft refused to link any name containing a quote, ampersand, pipe, angle bracket,
caret, percent or backtick, on the theory that a `shell` command built around a filesystem
name could be hijacked. Measured against the real archive that cost **a small fraction of the archive**
(0.73%, almost all ampersands) — so the fear was worth testing. It was wrong: the shell
treats those characters as syntax only *outside* quotes, and the path is quoted. Verified by
echoing each through `cmd` and reading it back:

```
Health & Nutrition.xlsx   -> intact
50%25 sample.dta          -> intact
a^b.pdf                   -> intact
```

So only a double quote is refused — the one character that would actually break the quoting,
and one Windows forbids in filenames anyway. Residual: a name with a *pair* of percent signs
around a real environment variable would be expanded, which makes a click fail rather than do
something wrong, so it is left alone rather than paid for with a guard that also rejects
`50% / 75% sample`.

### A no-extension case that was right by accident

Extensionless files reached the viewer through a Stata quirk — `:list "" in x` is TRUE for
any `x` — so the behaviour was correct but would have changed silently the day someone
reordered the conditions. It is now an explicit first branch. In this archive the 17
extensionless files are text data (Spain's `NACIA75` is a 34 MB fixed-width extract), so the
viewer is the right guess.

### Paging, which is not `maxitems()`

`perpage(20)` shows the files a fixed number at a time with clickable **next**/**prev** and a
`files 1-4 of 9   page 1 of 3` line.

The distinction from `maxitems()` is load-bearing. `maxitems()` **truncates**: the files past
it are genuinely absent from `r(files)` and `r(truncated)` is 1 to say the answer is a prefix.
`perpage()` slices only the *display* — `r(n_files)`, `r(files)` and the extension summary all
continue to describe the whole node. A pager that quietly shrank the counts would be the same
silent-partial-answer defect this command shipped with in 0.9.21, and case x16 pins that it
does not.

`perpage()` travels with you as you navigate, because it is a preference. `page()` does not:
descending into a folder starts at that folder's beginning, not at page 7 of an unrelated
listing. A `page()` past the end **clamps** rather than showing nothing, because an empty
listing and a mistyped page number look identical on screen. `page(0)` is refused.

A node with more than 30 files offers a clickable **show 20 at a time**, so the option does
not have to be remembered — the lesson from the `files` hint that could not be clicked.

New: `r(page)`, `r(n_pages)`, `r(perpage)`, `r(shown_first)`, `r(shown_last)`.

### Tests

`run_conformance.do` x16–x18: paging slices the display while counts stay whole, a page past
the end clamps and `page(0)` is refused, and the link dispatch is pinned bucket by bucket —
including that an ampersand *is* still linked.

## [0.9.25] — 2026-07-29

`explorer` lists files **by default** now, and the hint that could not be clicked is gone.

### The report

Eight nodes navigated in one session, every one ending in
`9 file(s) here -- add files to list them`, and no files ever seen. Two things were wrong,
and the second is the embarrassing one.

**The hint was a dead end.** The links `explorer` emits carry the *current* call's options,
so a session begun without `files` propagates `files`-less links forever. "Add `files`" was
correct advice that could not be reached by clicking — the same defect class as `update`
telling an operator to install from a source it could not name.

**Hiding files bought nothing.** `dir(..., "files", ...)` runs unconditionally on every
node, because `r(n_files)` needs it. The names were already in memory; `files` only decided
whether to *print* strings already fetched. Making the caller pay a round trip to see data
already in hand is not a trade-off, it is an oversight.

So files are listed by default. `nofiles` suppresses them. `files` is still accepted and now
does nothing — it is in `surface.yml`, two help pages and case x06, and breaking it to save
one line of parsing would be gratuitous.

`sizes` stays opt-in, because unlike listing it is genuinely expensive (~1.4 s per file over
SMB) — but its hint is now a **link**, and a sticky one: click it once and the propagated
links carry `sizes` as you descend. It also states the cost up front
(`measure these 9 file(s) (about 13 s over SMB)`).

### A Stata trap worth recording

`syntax [, FILES NOFILES ]` — with `FILES` declared **first** — binds *neither* local when
the caller types `nofiles`, and raises **no error**. Stata reads `nofiles` as the negation
of `FILES`, which for a plain flag means "absent". Declaring `NOFILES` first binds it
correctly.

Found by probing rather than reading, after `nofiles` silently did nothing. So declaration
**order** is load-bearing here, and someone tidying the syntax line into alphabetical order
would disable the option with every test still green. Cases x14 and x15 are the tripwire:
x14 pins that `nofiles` is a display switch which still returns every name in `r()`, and x15
pins that a near-miss spelling is *rejected* — proving `syntax` is binding a real option
rather than discarding an unknown one.

## [0.9.24] — 2026-07-29

Adds `datalib_index` / `datalib , index`: walk a subtree recursively and get it back as a
**dataset**.

### Why a second command rather than an option on `explorer`

`explorer` answers "what is in *this* folder" and returns `r()`. Reaching one file in
`Spain/1975 Vital Statistics/Working Datasets/Unzipped/datos partos75` therefore takes five
round trips, and what you have at the end is a display, not something you can `tabulate`,
`merge` or `export`. `r()` could not hold the answer anyway — a macro cannot carry 2,548
rows. So the two commands differ in their *product*, not their options.

One row per file; `dirs` adds a row per folder. Columns: `relpath parent name ext depth
is_dir bytes looks_grammar`.

**Deliberately no country/survey columns.** The reason `explorer` and `index` exist is that
these trees do *not* follow the naming grammar, so a built-in "component 1 is a country"
would smuggle back exactly the assumption they were written to avoid. `split relpath,
parse("/")` is one line and is the caller's to name.

### The cost is measured, and it decided every default

On `<staging-tree>` the walk costs **0.35 s per folder**, near-constant across
subtrees of very different size:

| subtree | folders | files | seconds |
|---|---|---|---|
| Spain | 1,511 | 2,548 | 530 |
| Brazil | 258 | 380 | 90 |
| Afghanistan | 119 | 300 | 42 |

That is SMB round-trip latency per directory open, not overhead in this command — and a
single bulk enumeration is **no faster**: PowerShell's `Get-ChildItem -Recurse`, which walks
the whole subtree in one process, took **538 s** on the same branch and found the same folders
and thousands of files. There is no fast path from one thread.

Consequences, all of them load-bearing:

- The whole 193-country tree is a **6-to-8 hour** walk, so `maxnodes()` defaults to 400
  (about two and a half minutes) rather than infinity.
- Hitting the cap is **announced**, sets `r(truncated)`, and the message is explicit that
  the dataset is a *prefix*. Whole-archive work belongs in the scheduled `<catalogue>`
  catalogue, which pays the same per-folder cost in parallel and off-hours and stores the
  checksums this command deliberately does not compute.
- `sizes` stays opt-in and is now a larger share of the cost: ~1.4 s per file over SMB, so
  Spain with `sizes` is roughly an hour beyond the walk.
- Progress prints every 25 folders and `Break` stops the walk, because 8.8 minutes of
  silence is not acceptable feedback.

### The queue is in Mata, not a macro

A worklist rather than recursion, and the queue lives in a Mata vector. At 400 nodes a macro
queue is comfortable; a user raising `maxnodes()` to 20,000 with long paths would silently
exceed `c(macrolen)` and get a short answer with no error — the silent-wrong-result class
this package keeps having to fix.

### Three defects found in review, before shipping

- **The truncation message said "maxitems"** — copy-paste from `explorer`; the option is
  `maxnodes`.
- **It reported the queue length as the remainder.** The walk is breadth-first, so the queue
  holds only the discovered frontier: with an 8-folder subtree and a cap of 3 it said "2
  folders not indexed" when 5 were missed. It now says "at least N", and states that the
  true remainder is unknowable until the walk finishes.
- **"expect about 0 minutes"** for small caps. Now switches to seconds.

### Tests

`run_conformance.do` Part 12, `ix01`–`ix11`: **150/150 passed, 0 skipped**. The cases that
matter are the ones that could let a caller trust a partial answer — the node cap, the depth
cap, and bytes-missing-vs-zero. Case labels are `ix` rather than `i` because the `_uc_init`
suite already uses `i01`–`i11`, and two sets under one prefix means a failure line cannot
say which suite it came from.

## [0.9.23] — 2026-07-29

Two small corrections on top of 0.9.22, and one process note.

### The `running` line could render half-way

`quietly` suppresses as-txt and as-res output but lets **as-err** through. The stale-session
warning mixed the two, so under `quietly datalib, update` it rendered as

```
  running        :    (in memory - NOT what is on disk)
```

— label and warning intact, version silently dropped. A half-rendered warning is worse
than none: it names a problem and withholds the number the reader needs. The line is now a
single display class, so it appears whole or not at all.

Worth being precise about what was *not* wrong here, because the first reading was that
`r(stale)` had a logic hole. It does not: `running(0.9.21)` gives `r(stale)=1` and
`r(running)=0.9.21`, `running()` gives `r(stale)=0`, and case u19 pins that. The empty
value came from the probe's own `quietly`.

### Why 0.9.23 and not a re-cut of 0.9.22

0.9.22 was published to `Z:/_pkg/datalib` to unblock a user, and the display fix landed
minutes afterwards — so the share's 0.9.22 no longer matched its own source. That is
exactly the v0.9.19 failure this CHANGELOG already records, and the rule is absolute:
never overwrite a published version in place. The real error was publishing before the
work was finished; 0.9.22 remains on the share, functional and superseded.

## [0.9.22] — 2026-07-29

Fixes a defect in 0.9.21 that made `datalib , explorer` fail on **every clean install**.
0.9.21 stays on the share untouched, per the standing rule against overwriting a
published version in place.

### The bug

```
. datalib, library(<staging-tree>) explorer
command _uc_dirs is unrecognized
r(199);
```

`datalib_explorer` called `_uc_dirs`, which is defined **inside `_uc_init.ado`** (line 345)
rather than as `_uc_dirs.ado`. Stata resolves a command name to a **file** of that name on
the adopath, so a secondary program in someone else's file is only callable once that file
has been loaded for its own reasons. Called cold, it does not exist.

### Why every test passed

`run_conformance.do:45` does `run "stata/src/_/_uc_init.ado"`, which loads the whole file
and with it `_uc_dirs`. The harness *manufactures* the loaded state whose absence is the
bug — it structurally cannot catch a missing dependency, because it loads every source
file up front, which is the one condition a real user does not have. The live probes
passed for the same reason: the same session-contamination trap that had already produced
a bogus `u15` failure earlier the same day.

### The fix

The directory listing now goes through Mata's `dir()` directly, exactly as the *file*
listing in the same command already did. The dependency bought nothing — `_uc_dirs` is a
thin wrapper over `dir()` — and verified on the live tree, `dir(p,"dirs","*")` returns 193
**bare** names with casing intact (`Afghanistan`, not `afghanistan`). Both halves of the
listing are now read the same way and the command depends on nothing outside itself.

Two alternatives were rejected: calling `_uc_init` first to force the load (it is a config
**writer**, so listing a folder would write files as a side effect), and extracting
`_uc_dirs` into its own packaged `.ado` (either two definitions free to drift, or surgery
on the config writer — a far larger blast radius than this bug warrants).

`capture` is also gone from both reads. It was hiding failure as an empty listing: a
directory that exists but cannot be read would have reported "0 folders, 0 files" instead
of erroring.

### The guard

New `python/tests/test_ado_dependencies.py`. For every `_`-prefixed program the package
defines, each call site must be either in the file that defines it (a private subroutine)
or a name with its own packaged `.ado` (autoloadable). Only names the package itself
defines are examined, which is what keeps it free of false positives — `_rc`, `_n`, `_N`
are never in the defined set.

It is in Python, not the Stata harness, for the reason above: the check is static (does a
name resolve to a file?) and a dynamic test would be fighting the harness it lives in.
Proven against the real regression, not just a synthetic one — reintroducing the call
produces:

```
datalib_explorer.ado:146 calls _uc_dirs, which is defined only inside _uc_init.ado
and has no _uc_dirs.ado of its own -- Stata cannot autoload it, so this raises
r(199) on a clean install
```

### Verified cold

`which _uc_dirs` → rc 111 (provably absent), `_uc_dirs` and `_uc_init` dropped from
memory, only `datalib_explorer.ado` loaded: the top-level folders, 9 files, rc 0.

## [0.9.21] — 2026-07-29

Stata gains `datalib , explorer` — navigation for trees that do **not** follow the
naming grammar. R and Python are unchanged; only their version manifests moved, since
`test-version.R` and `test_version.py` pin each declared version to `VERSION`.

### The problem

Every existing navigation path in this package reconstructs a folder's ancestry from its
own **name**: `_foldernav` counts underscores to rebuild
`CCC/CCC_YYYY_SURVEY/`, and `datalib_browse` does the same after uppercasing the path.
That is correct inside the grammar, where a name encodes its parents. It is useless
outside it — a folder called `raw datasets` says nothing about which survey it belongs
to — and `_dl_islib` refuses to start at all, which is how a real staging tree with 193
top-level folders came to be unreachable from the package that exists to read it.

Two rejected alternatives, recorded because both look cheaper than they are:

- **Drop a `.datalib` marker into the tree.** It would satisfy `_dl_islib` and let the
  ordinary navigation start — which would then compute wrong parent paths and follow
  them silently. Refusing to start beats navigating to the wrong place.
- **Relax `datalib_browse`.** Its whole method is name-parsing. Making it tolerant of
  non-grammar names does not give it a way to know where it is.

So `datalib_explorer` is a separate command with three different rules: every link
carries the **full** relative path rather than reconstructing it, casing is preserved,
and the only precondition is that the directory exists.

### `r()` is as much the point as the display

Seventeen returned values, enough to walk a tree programmatically rather than by
clicking: `root path fullpath parent depth`, `n_dirs dirs n_files files`,
`bytes n_exts exts largest largest_bytes`, `is_empty truncated looks_grammar`.

`r(looks_grammar)` is the useful one for a migration: in a tree where some branches
have been renamed to the convention and others have not, it separates them in one pass.

Two deliberate choices in that surface:

- **`r(bytes)` is `-1`, not `0`, when `sizes` was not given.** Zero is a real answer for
  a node with no files, so a caller must be able to tell *no bytes* from *not measured*.
- **`r(dirs)` and `r(files)` are quoted element by element.** a fifth of the top-level
  folders in the staging tree contain a space; an unquoted space-delimited macro would
  split them into garbage.

`sizes` is opt-in because **no Mata function reads a file size** — it takes
`file open` + `file seek eof` + `file seek query`, and an open over an SMB share costs
about 1.4 s regardless of the file's size. A node with 200 files would take five
minutes.

### Three bugs the tests caught, and one they caught in the tests

- **Stata's `while` has no single-line form**, unlike `if`. The leading-separator
  stripper was written without braces and raised `{ required` at *run* time, not load
  time — so the file installed clean and failed on first use.
- **`depth` counted words, not separators.** `wordcount()` splits on spaces, so
  `Afghanistan/2010 SDHS/Raw Datasets` reported depth 5 instead of 3. The conformance
  fixture carries a space in a folder name precisely to catch this class.
- **`_stata_filesize` does not exist.** It was written as though it did.
- **Conformance case x01 asserted the fixture root was not a library, and it is.** The
  fixture contains `SLV/SLV_2014_MICS` — exactly the `???/???_*` country pair
  `_dl_islib` looks for — because x07 needs a grammar-shaped branch. The command was
  right; the assertion was wrong, and now it is made against `Afghanistan/`, where it
  actually holds.

### `update` now reports what the session is *running*, not only what is on disk

Found by reading a working session, not a failing one. After a clean
`datalib , update install`, `which datalib` reported `0.9.20`, `update` reported
`installed : 0.9.20`, and `Up to date` -- all three correct, and all three about **disk**.
The session was still executing the previous `datalib.ado` from memory, because Stata
compiles an ado on first use and `net install` does not invalidate that.

Demonstrated with a throwaway package rather than argued: write `zzstale.ado` at
`*! v1.0.0`, run it, overwrite the file at `v2.0.0`, and `which` reports `v2.0.0` while
the program still prints `I am v1.0.0` until `discard`. So nothing in a session reported
what it was actually running.

On 0.9.20 that was harmless -- the Stata leg was byte-identical to 0.9.19 apart from the
stamp. On **this** release it would not be: install 0.9.21, skip `discard`, and
`datalib , explorer` fails with rc 198 (the stale front door's `syntax` has no such
option) while `update` cheerfully reports `installed : 0.9.21`. That is the same defect
class this command was written to remove -- correct advice the operator cannot act on.

So `datalib.ado` now carries its version a second time as a compiled-in literal and
passes it to `_dl_update`:

```
  installed      : 0.9.20   (in <PLUS>)
  running        : 0.9.19   (in memory - NOT what is on disk)
                   Stata compiled datalib into memory before the files
                   were replaced, and keeps using that copy. Run discard.
  ...
  Up to date - installed and net site are both 0.9.20.
  On disk, that is. This session is still running 0.9.19 - run discard.
```

Three design points:

- **The literal cannot be derived from the `*!` stamp.** Reading the stamp at run time
  means reading `datalib.ado` from disk, which is the very thing being compared against.
  So it is a genuine second copy of the version, and
  `test_the_running_literal_tracks_the_package_version` pins it -- a duplicate with no
  enforcer is how `datalib.sthlp` drifted five releases.
- **Comparing the in-memory pair against disk is self-consistent.** After an install
  without `discard`, *both* `datalib.ado` and `_dl_update.ado` in memory are from the
  previous release: they agree with each other and both differ from the disk record, so
  the stale front door passes its own old literal and the stale reporter detects the
  mismatch.
- **An empty `running()` makes no claim.** An older front door, or a direct call, passes
  nothing; reporting a stale session on the strength of a missing argument would be the
  false alarm that gets warnings ignored.

This is a different hazard from the existing `r(shadowed)` check, and the help file now
says so: that one is about **place** (the adopath resolving `datalib` somewhere other
than the copy being reported on), this one about **time** (the right file, loaded before
it was replaced).

New: `r(running)`, `r(stale)`. Cases u17-u19 cover no-false-alarm, detection, and the
no-claim path.

### Not a fourteenth subcommand

`explorer` reaches the legacy surface as an **option**, exactly as `update` does, and is
absent from the dispatcher's `subcmds` list. `stata_subcommands` is the 13 canonical
contract commands and `test_subcommands_are_exactly_the_canonical_commands` takes its
meaning from that count, so a fourteenth entry there would quietly destroy the guard.
Case x11 pins the distinction: `datalib explorer` must fail, `datalib , explorer` must
work.

It dispatches **before** library resolution, for the same reason `update` does:
`datalib_root` would apply `_dl_islib`, which is the gate the option exists to bypass.

### Tests

`run_conformance.do` Part 11, cases x01–x11: **133/133 passed, 0 skipped**. The fixture
is hermetic — built under `c(tmpdir)` with a space in one folder name and mixed casing
in another, the two properties that actually broke things — so it does not need `Z:` to
be mounted.

## [0.9.20] — 2026-07-27

A version bump rather than an overwrite, and the reason is the point.

### Why 0.9.20 exists

v0.9.19 was tagged, released, and published to `Z:/_pkg/datalib`. Work then landed on
`dev` that changed the R and Python packages -- the CRAN fix, the PyPI metadata -- so
the **published 0.9.19 artefacts no longer matched their own source**. Verified rather
than assumed: the released R tarball still contained the `Data/{Original,Stata,R}/`
brace text that `dev` had already fixed.

The tempting move was to rebuild and re-upload under the same version. This
CHANGELOG already forbids it: *"Never overwrite a published version in place with
different contents -- bump instead. A stale in-place overwrite on this exact share once
downgraded a working install."* So: a bump. Nothing about 0.9.19 changes, and anyone
holding it can see exactly what they have.

**The Stata leg is byte-identical to 0.9.19.** No stamped `.ado` or `.sthlp` changed;
only the six version manifests, `datalib.ado`'s front-door stamp, and the help page's
stated version moved. The other stamped files deliberately stay at 0.9.19, which
`test_stamps.py` permits -- it forbids a stamp *older* than the release that last
touched the file, not one that lags an untouched file.

### R: `R CMD check --as-cran` now passes

It had never been run. It failed with **1 ERROR**, and the ERROR was that the entire
suite died before a single test executed: `helper-datalib.R` walked up for
`DESCRIPTION` and hard-stopped when absent, which is exactly the situation under
`R CMD check`.

The underlying tension is legitimate. **9 of 13 test files need the shared conformance
corpus** (`tests/cases_*.csv`, the fixture library), which lives at the repo root and
is deliberately not in the package -- it is one set of cases Stata, R and Python must
all pass, and a copy in `inst/` would be a second copy free to drift. On a CRAN machine
the repo does not exist, so those tests must **skip**, not fail.

Locating now fails soft and the accessors skip, at one choke point rather than a guard
in nine callers. That choice proved itself: fixing only the *corpus* accessor left 7
tests failing with `invalid 'description' argument` from `file()` -- NULL reaching
`file.path()` and yielding `character(0)`. Those tests want the *source tree*
(`NAMESPACE`, `man/`, `inst/`), so the package-root accessor needed the same treatment.

Also cleared the `Rd files` NOTE: `DESCRIPTION` wrote paths as `Data/{Original,Stata,R}/`
and Rd treats braces as markup, so `checkRd` reported "Lost braces". Editing
`DESCRIPTION` alone was **not** enough -- `man/datalib-package.Rd` is roxygen-generated
and kept the stale text until `man/` was regenerated.

```
before:  Status 1 ERROR, 4 NOTEs   (suite dead, 0 tests run)
after:   Status 3 NOTEs, exit 0    (FAIL 0, SKIP 6, PASS 203 under check)
```

Local runs are unchanged at 237 pass / 0 fail / **0 skip** -- the skips engage only
when the corpus is genuinely absent.

### Python: the PyPI metadata was absent, not unpolished

Issue #22 called it "metadata polish". `pyproject.toml` shipped **0 classifiers and 0
project URLs** -- a PyPI page that is unfiltered and unsearchable. Now 12 classifiers,
4 project URLs, keywords, both authors with Minh credited, and a maintainer email.
`Development Status :: 4 - Beta`, honest at 0.9.x. The URLs point at the **public**
distribution repository: a project URL that 404s for everyone is worse than none.

### Documentation

Every version-bearing reference moved: both `README.md` stamps and its
version-history lede, `stata/README.md`, the pinned artefact filenames in
`r/README.md` and `python/README.md`, `internal/BRIEFING_microdata_archive.md`, and
the help page. References that name 0.9.19 as *history* were left alone -- when the
retired roots were removed, when the R helper changed -- because those statements
remain true.

### Also in this release, not code

Two internal documents from investigating issue #21 across the whole HLT collection:

- `internal/FEEDBACK_module_key_registry.md` -- structured feedback proposing that
  `collections.yml`'s `linevar` be keyed by survey programme. DHS carries the roster
  line in `hh_line_number` (78/78 modules); MICS carries it in
  `respondent_line_number` (73/74). The declaration is right for DHS and wrong for
  MICS, so issue #21's 73 "unkeyable" modules are datalib applying a DHS-shaped key to
  MICS data. The MICS modules **are** uniquely keyed -- verified on ZWE 2019 across all
  44,472 rows. If confirmed upstream, that is a schema change unblocking 4.9M rows with
  no data regeneration. Also records that `_dlw.ado:116` hardcodes the value instead of
  reading the registry, that `children` has no established key, and that
  `surface.yml` declares parameters but not returns.
- `internal/DRAFT_email_mics_key_variables.md` -- unsent draft asking the
  harmonization owner which variables are authoritative.

Both record two **false** results produced on the way, because each looked like a
finding. A three-level glob against a five-level tree matched zero of 152 files and
would have reported "no other country-years affected" -- the opposite of 73. And
`household` was reported as having no unique key in 12 of 12 sampled vintages when the
base key is unique in every one, because the probe demanded a line variable a
household-level module has no reason to carry. Had that reached the email it would have
alleged two defects that do not exist. A broken probe and a clean dataset look
identical, so a negative result needs the same scrutiny as a positive one.

## [0.9.19] — 2026-07-26

One install path, one enforced stamp convention, and sixteen documentation claims
that were false.

### Z:/_pkg/datalib is the only install path

Both retired net-site roots are gone. `Z:/_pkg/stata` no longer exists;
`Z:/_statapkg` was found reduced to a stray **file** where the directory used to
be -- created by this session's own publish loop, which ran
`Copy-Item <file> Z:\_statapkg -Force` without first checking the destination was a
directory. With the directory already absent, `Copy-Item` obligingly made a file of
that name. The loop now has no counterpart to fix, because the decision is that
**every datalib installation package comes from `Z:/_pkg/datalib` and nowhere
else**, so the retired roots are not being rebuilt.

What removed the two directories in the first place is not established. They were
verified byte-identical to git at the 0.9.18 publish, 39 files each by SHA-256, and
were gone hours later. Recorded here as unexplained rather than attributed.

**The forwarding rule in `_dl_update.ado` is now load-bearing and must not be
deleted as a transition leftover.** Until 0.9.19 the retired roots were kept in step
so an un-migrated machine could still install from the path it remembered; that
fallback no longer exists. The redirect is the only thing between such a machine and
a hard failure -- and it survives the removal by design, because it tests the
*canonical* `stata.toc`, never the retired one. Conformance u08 and u10 pass with
both roots absent, which is the evidence that the decision is safe to take.

### The version-stamp convention is now enforced

`which datalib` reported `*! v0.9.10` on a 0.9.18 package four separate times in one
session, and each time the honest answer required reading git history by hand. The
reason is that a stamp below the package version is sometimes correct -- the file
genuinely has not changed -- and sometimes a defect. Nothing distinguished them.

New `python/tests/test_stamps.py` pins the invariant that does:

> a file's `*!` stamp must be >= the VERSION in effect at the commit that last
> changed that file

`>=`, not `==`, because a fixup may land between releases; stamping ahead is
harmless, stamping behind is the defect. It ran once and immediately found **four
stale stamps nobody knew about**: `datalib_root.ado` and `_dl_islib.ado` claiming
0.9.3 after changing in 0.9.5, and `_dl_islib.sthlp` and `_uc_init.sthlp` claiming
0.9.3 after changing in 0.9.11. `datalib.sthlp`'s five-release drift, found by
accident while editing it in 0.9.17, would have been caught on the commit that
introduced it.

`datalib.ado` is a deliberate exception and now tracks VERSION exactly: it is the
file `which datalib` reports, so a front door eight releases behind the package
sends people to the wrong conclusion. The stamp bump is itself a content change, so
this does not break the only-bump-what-changed rule -- it means this one file
changes every release.

### Sixteen false documentation claims

Found by a systematic audit against ground truth, not by reading for tone. Each was
verified against a named file or command before being changed. The most consequential:

- **`config/grammar.md` described the opposite of the resolver.** It said a
  non-library candidate "never shadows a later one"; `datalib_root.ado` sets
  `badcand` and exits 198, so the first set candidate that is not a library
  **aborts** resolution. This is normative contract text -- an implementer working
  from it would have written the wrong resolver -- and the same bullet list
  contradicted itself four lines later.
- **Two false claims of my own about `jpazvd/datalib`**, in `README.md` twice: that
  it exposes "the same trilingual surface". It does not. Its `R/NAMESPACE` exports a
  `dl_*` verb API with no `datalib_*` function at all, its `src/d/` holds only
  `datalib.ado`, and it has no `config/` directory, so no contract v1. The *role*
  claim -- public release of the `datalib-dev` generic package -- was correct and
  stands.
- **"guarded on every push" / "runs the R + Python legs on every push/PR"** in
  `tests/README.md` and `docs/README.md`, and "With CI required on the branch" in
  `test_surface.py`'s own docstring. Nothing is guarded on any push: every Actions
  run for months completed `failure` with zero steps executed, neither `main` nor
  `dev` returns a protection object, there are no git hooks, and PR #58 merged with
  all checks red. All three legs are local gates.
- **Stale counts** in `.github/copilot-instructions.md`, which is what agents read
  first: the Stata harness as "57/57 -- 18 cross-language cases" (now 122 across ten
  parts, 34 shared), R as 97 tests (237), Python as 184 (311 + 1 xfail). Its repo map
  also omitted the `src/` level, pointing at `stata/d/` and friends, none of which
  exist.
- **`r/README.md` documented a module the registry cannot resolve**: `module =
  c("hh", "hhmembers")` under `collection = "HLT"`. Per `config/collections.yml`,
  `hh` is an **IPUMS** module; HLT has `household`, `hhmembers`, `adult`, `children`.
- **The open 1.0.0 gate named an abandoned root** (`Z:/_statapkg` "accepted as
  canonical") and the wrong licence carve-out ("the UNICEF data" for what is
  actually the World Bank PDFs under `docs/pdf/`). Both corrected in place, since
  the gate is a live checklist rather than history.
- `stata/README.md` said "five parts" above a table of eight, for a harness with
  ten; two parts were missing entirely. Plus version and date drift across
  `README.md` (v0.9.3, "Last Updated 2026-07-10"), `stata/README.md` (v0.9.16),
  `internal/BRIEFING_microdata_archive.md` (v0.9.3), and the pinned artefact
  filenames in `r/README.md` and `python/README.md` (0.9.16, which no longer
  resolves at the path given).

Two `CHANGELOG` claims are left as written, being history rather than a live
checklist: the v0.9.8 entry's "enforced on every push" and its repetition below it.
`internal/PLAN_v0.10.0_alignment.md` already records both as known-false, and
rewriting past entries is worse than annotating them.

## [0.9.18] — 2026-07-26

Two more ways the report could contradict reality, both found from a live session.

### stata.trk is not authoritative for "what is installed"

Reported: `update install` ran, printed *all files already exist and are up to
date*, and the follow-up check still said `installed : 0.9.16` with 0.9.17
available -- on a machine whose files on disk were verifiably 0.9.17.

Probed rather than assumed. Two consecutive `net install ... replace` calls into
one PLUS:

```
install #1 into an EMPTY PLUS   -> entries 1, d Version 0.9.17
install #2, nothing changed     -> entries 1, d Version 0.9.17
VERDICT: a no-op install writes NO trk entry.
```

So `net install` appends its record only when it copies. When it copies nothing the
trk keeps an older version, and since `installed` was read from the trk, the command
reported an update that was permanently available and that installing could not
clear -- the same dead-end shape as 0.9.17's notice bug, in a different mechanism.

Every `install` now also records the version, next to the source, in
`PLUS/datalib_netsource.txt` (three lines: source, version, trk entry count; a
0.9.17-era one-line file still supplies the source). The version written is the
site's even after a no-op, which is justified rather than convenient: a no-op is
Stata asserting that the installed files already match this net site's package, and
if they match the site then the installed version *is* the site version.

**Ranked by recency, not by version number.** "Prefer the higher version" would have
been one line, and would hide a deliberate downgrade performed with plain
`net install` -- which is the exact failure this command exists to prevent. The trk
is append-only, so its entry count answers "did anything install after we wrote our
stamp?" in both directions. Conformance **u13** pins it: a *lower* trk version wins
when the trk grew since our stamp. Disagreements are always printed, never resolved
silently -- an invisible substitution is treated as a defect everywhere else in this
package and the rule applies to us too.

A no-op install no longer says "Installed." either. It says nothing was copied, that
no `discard` is needed because nothing on disk changed, and why the version was
recorded here instead.

### It now checks it is describing the copy you will run

Prompted by the question "shouldn't we use `findfile` to know where to install?"
Not for that -- `net install` has no destination option, it always writes to PLUS,
so there is nothing to choose. (`whereis` is a different tool again: it locates
external executables from a registry the operator maintains, not ado-files.)

But the question exposed an assumption: every version reported described the PLUS
copy, without ever checking that the adopath *resolves* `datalib.ado` to that copy.
If a clone is on the path first -- ordinary while developing this repo -- the
installed package is shadowed and the whole report is about files the session will
not execute. `findfile` answers that, the path is printed when it differs, and it is
returned in `r(running_from)` / `r(shadowed)`.

Reported for the adopath only. A program already loaded by `run` is invisible to
`findfile`, `which` and everything else, so that is not claimed.

### Conformance: 114 -> 122 cases

`u09`-`u16` are new. Two are worth naming:

- **u08 was silently dead.** It was guarded on "does this machine still record the
  legacy root?", so it stopped running the moment the migration it tests succeeded
  -- losing coverage of a path that still has to work for everyone who has not
  migrated. It now writes its own trk fixture into a redirected PLUS and runs
  everywhere.
- **u16 failed first as u15**, asserting that redirecting PLUS leaves the real one
  shadowing it. It does not: `sysdir set PLUS` *replaces* PLUS on the adopath, so
  `findfile` found nothing and the command correctly declined to claim shadowing.
  Rewritten to reproduce the hazard the way it actually occurs, with `adopath ++`.

### R and Python

Unchanged again. Neither installs, so neither has a trk to disagree with and no
install event whose version could go unrecorded.

## [0.9.17] — 2026-07-26

`datalib , update` now remembers where it installed from, and the "the net site
moved" notice can actually be dismissed.

### The notice that could never stop

Reported from a live session that saw it twice in a row, both times at
0.9.16 = 0.9.16:

```
  installed from : Z:/_statapkg  (legacy root)
                   The net site moved. Checking the current
                   root instead; installing from here updates
                   the recorded source, so this is a one-off.

  Up to date - installed and net site are both 0.9.16.
```

The advice was correct and unreachable. Installing *does* rewrite the record --
but the only place that offered an install was the `newer_available` branch, and a
machine on a retired root is normally **already current**, because the retired
roots are kept in step precisely so nobody strands. So the status that needs the
offer most was the one status that never printed it. The "one-off" was permanent.

The offer now lives outside the status branches and fires whenever a redirect
happened, worded as what it is -- a re-point at the same version, same files:

```
  This machine still records the old root, and only a
  reinstall can rewrite that record -- so the notice above
  repeats until you re-point it. Same 0.9.17, same files:
    Re-point to Z:/_pkg/datalib/stata now
```

### A memory this command can write

Until now the only record of the install source was `stata.trk`, which
`net install` appends to and nothing else can write — which is why the dead end
existed at all. Added `PLUS/datalib_netsource.txt`: one line, written on every
successful `install`, read on every check, reported as `remembered`, returned as
`r(remembered_source)`. It takes precedence slot 3, above the `stata.trk` record
and below an explicit `netsource()` or `${datalib_netsource}`.

**Not** implemented by persisting `${datalib_netsource}` into `profile.do`, which
would have been less code and reused an existing slot. A global is treated here as
an *instruction* and is deliberately never redirected; something we wrote down
ourselves is a *record*, and must stay redirectable, or the next move of the net
site becomes unmigratable and every machine needs re-pointing by hand. Trading
today's dead end for a worse one is not a fix. Conformance case **u10** pins this:
a remembered legacy root is migrated forward; u11 pins that an explicit
`netsource()` still is not.

Written *after* the install succeeds, so a failed install leaves the old memory
intact rather than pointing at a root that did not work. An unwritable PLUS
(locked-down install, read-only share) says so and carries on -- `stata.trk` still
records the source, which is the pre-0.9.17 behaviour, not a regression.

### Also fixed

- **`datalib.sthlp` was stamped 0.9.11** in a 0.9.16 package, and still documented
  the pre-move net-site chain (`${zDrive}_statapkg`, `Z:/_statapkg`). Both
  corrected; the resolution order now matches the code.
- **A `{bf:...}` group split across a newline**, introduced by 0.9.16's `discard`
  paragraph and not yet rendered by anyone. This is the same defect class that
  broke the help layout twice before, so the per-line brace-balance check is now
  run as a standing gate alongside the ASCII scan -- it was what caught this.
- **Retired roots served stale code under a current manifest.** Refreshing
  `Z:/_statapkg` and `Z:/_pkg/stata` had been copying `stata.toc` and
  `datalib.pkg` but not the `src/` tree, so they briefly advertised 0.9.17 while
  serving 0.9.16 ado-files -- strictly worse than being behind, because the
  version check would have called it up to date. All three roots are now verified
  by SHA-256 over all 39 source files, not by reading version stamps.
- **The 0.9.16 versioned archive was never created**, leaving that release with no
  rollback floor. Backfilled, and 0.9.17 archived alongside it.

### R and Python

Unchanged, deliberately. Neither installs -- both print the command and let the
operator run it, because `install.packages()` over a loaded namespace and
`pip install` over an imported module are both unsafe -- so neither has an install
event to remember. Their default net site is already the canonical root.

## [0.9.16] — 2026-07-26

Fixes a misleading post-install message that made a **working** update look like a
failed one.

### The ado cache

Stata holds ado-programs in memory once they are loaded. `net install` replaces the
files on disk, but the running session keeps executing the copies it already has --
so a check re-run immediately after installing reports the **old** behaviour.

The previous message said "Done. Run `datalib , update` again to confirm", which
invites exactly that. Reported from a live session where 0.9.15 installed correctly
and the follow-up check still showed the retired root, because the redirect added in
0.9.14/0.9.15 was on disk but not in memory. Verified afterwards in a fresh session:
the same installed file redirects correctly, `r(migrated)=1`.

The message now says what to do:

```
Installed. One more step in THIS session:
  Stata still has the previous copies loaded in memory,
  so run  discard  before using datalib again --
  otherwise you keep running the old code. Restarting Stata
  does the same thing.

  Then: datalib, update to confirm.
```

Also documented in `help datalib` under Updating, and in the source header -- the
diagnosis is worth keeping, because "the update did not work" and "the update worked
but this session cannot see it yet" look identical from the prompt.

`discard` is **not** called automatically: it would drop the program while it is
running, and it also clears stored estimation results, which is not this command's
business to do to a user's session.

## [0.9.15] — 2026-07-26

One subtree per package, so the same parent can serve other CSO packages.

### The net site is now Z:/_pkg/datalib

```
Z:\_pkg    datalib        VERSION                                     shared by all three legs
        stata\    datalib.pkg, stata.toc, src\      a Stata net site
        R\        datalib_<ver>.tar.gz
        python\   unicef_datalib-<ver>-py3-none-any.whl
        <ver>\    full archive of all three
    csotoolkit\   (the point: a sibling, when it arrives)
```

`Z:/_pkg` on its own was ambiguous the moment a second package was in prospect --
and `VERSION` at that level would have been meaningless, since `datalib` and
`csotoolkit` version independently. Per-package subtrees put the manifest where it
belongs.

### Retired roots are a list now, not a special case

The site has moved twice today, so the redirect no longer hardcodes one old path:

| root | status |
|---|---|
| `Z:/_statapkg` | retired -- the only one with a real installed base |
| `Z:/_pkg/stata` | retired -- existed under an hour, **zero** recorded installs (verified against `stata.trk`) |
| `Z:/_pkg/datalib/stata` | **canonical** |

A machine recorded against either retired root is redirected to the canonical one and
told why; installing then rewrites its `stata.trk`, so one `datalib , update install`
completes the move. Both retired roots are also kept publishing the current version,
so nothing is stranded even if the redirect is somehow bypassed.

An explicit `netsource()` or `${datalib_netsource}` is still never redirected.

### Install

```stata
net install datalib, from("Z:/_pkg/datalib/stata") replace
```
```r
install.packages("Z:/_pkg/datalib/R/datalib_0.9.15.tar.gz", repos = NULL, type = "source")
```
```bash
pip install --upgrade "Z:/_pkg/datalib/python/unicef_datalib-0.9.15-py3-none-any.whl"
```

### A mistake worth recording

The first attempt at populating the new subtree wrote everything into
`Z:/_pkg/datalib/python/`. Cause: a PowerShell loop variable `$d` and the destination
`$D` -- **PowerShell variable names are case-insensitive**, so the loop silently
overwrote the destination with its own last value. Caught immediately because the
follow-up read failed on a nonsensical path, and the misplaced files were removed
before anything was published. The lesson is not "be careful" but "do not name a loop
variable a case-variant of a live one".

## [0.9.14] — 2026-07-26

Makes the net-site move actually happen. v0.9.13 relocated the site to `Z:/_pkg` but
**no existing install would ever have followed it.**

### Fixed: the migration could not complete on its own

`datalib , update` resolves the net site from the source `net install` recorded in
`stata.trk`, and that recorded value outranks the built-in default -- deliberately, so
an existing install keeps working. But that alone means the recorded value wins
*forever*: an operator on `Z:/_statapkg` would keep checking the old root, never be
told a new one exists, and only move if they happened to type the new path by hand.
Reported from a live session, where 0.9.13 installed cleanly and still said
`net site : Z:/_statapkg`.

Now, when the recorded source **is** the legacy root and the canonical root is
readable, the check redirects to the canonical one and says why:

```
  installed from : Z:/_statapkg  (legacy root)
                   The net site moved. Checking the current
                   root instead; installing from here updates
                   the recorded source, so this is a one-off.
```

Because the install then runs against the redirected source, `stata.trk` is rewritten
and a **single `datalib , update install` completes the move**. New in the return
surface: `r(migrated)`.

**An explicit source is never redirected.** `netsource()` and `${datalib_netsource}`
are instructions, not legacy artefacts, so both are honoured exactly as given --
verified as separate cases, along with the no-op case where the canonical root is
already what was named.

This is a transition measure and is marked as one in the source; it comes out when
`Z:/_statapkg` retires.

### Also fixed

- `_dl_update.ado` still stamped **0.9.10** after being retargeted in 0.9.13 -- a
  stale stamp on a file whose contents had changed twice.

### Note on the shared manifest

All three legs read one `VERSION` file, so **a version bump obliges republishing all
three legs**. Bumping `VERSION` alone would tell an R user that 0.9.14 is available and
then hand them a tarball filename that does not exist. Both artefacts were rebuilt and
both roots publish 0.9.14.

## [0.9.13] — 2026-07-26

Reorganises the net site into a language-neutral layout, and makes R and Python
installable from it. **Migration is additive: nothing existing breaks.**

### The net site is now Z:/_pkg

```
Z:\_pkg    VERSION                                    shared manifest, read by R and Python
    stata\    datalib.pkg, stata.toc, src\     a Stata net site
    R\        datalib_<ver>.tar.gz
    python\   unicef_datalib-<ver>-py3-none-any.whl
    <ver>\    full archive of all three, for rollback
```

`Z:/_statapkg` was a misleading name once it served three languages -- `_statapkg/python`
reads as "the Python part of the Stata package". `Z:/_pkg/stata` is also a proper Stata
net site, so it can host other CSO packages later without further reorganisation.

### R and Python are installable from the share

```r
install.packages("Z:/_pkg/R/datalib_0.9.13.tar.gz", repos = NULL, type = "source")
```
```bash
pip install --upgrade "Z:/_pkg/python/unicef_datalib-0.9.13-py3-none-any.whl"
```

A **built wheel** is published, not a Python source tree, and deliberately so: this
project builds with `hatchling`, which an operator will not have installed, so
`pip install <dir>` would try to fetch a build backend. A wheel needs none. R gets a
built source tarball, which needs no Rtools because the package is pure R.

### Nothing existing breaks

`Z:/_statapkg` is **kept in place and current**, publishing the same 0.9.13. Every
existing install records `S Z:\_statapkg` in its `stata.trk`, and that recorded value
is what `datalib , update` resolves to by default -- so moving and deleting would have
silently broken update for every operator already installed, which is exactly the
failure class the downgrade guard exists to prevent. The old root is retired only once
operators have reinstalled from the new one.

### Per-leg defaults, because the legs read different things

| leg | default net site | what it reads |
|---|---|---|
| Stata | `Z:/_pkg/stata` | `stata.toc` (`net install` needs a net site) |
| R | `Z:/_pkg` | `VERSION`, then `<root>/R/` |
| Python | `Z:/_pkg` | `VERSION`, then `<root>/python/` |

### Two defects caught by verifying rather than assuming

- **Both `datalib_update()` functions were printing an uninstallable command.** They
  named `<src>/r` and `<src>/python`, which are now *directories holding artefacts* --
  `install.packages()` and `pip install` both fail on those. They now name the exact
  artefact, constructed from the version just read off the manifest.
- **The first artefacts I published had the old default baked in.** Built before the
  retarget, so an install from Z: reported its net site as `Z:/_statapkg`. Caught by
  installing the artefact into a temp library and asking it -- not by reading the diff.
  Both were rebuilt from the retargeted source and re-verified: an installed R package
  and an installed wheel each now report `Z:/_pkg`.

### Why this is 0.9.13 and not a republished 0.9.12

0.9.12 was published, then shipped code changed. Republishing the same number with
different contents is precisely the ambiguity the versioned archives and the downgrade
guard exist to prevent, so the version was bumped instead. 0.9.12 remains archived
under both roots exactly as it was published.

## [0.9.11] — 2026-07-26

`update` reaches R and Python. All three legs can now answer "am I running the
current datalib, and where would a newer one come from?" from **one** published
manifest.

### Added

- **`datalib_update()` in R and Python**, alongside Stata's `datalib , update`.
  Each reports the same three coordinates — the version you are running, the
  version published at the net site, and which way they differ — and each reads the
  **same** `VERSION` file, so a single publish serves all three languages.
- **`VERSION` published to the net site**, at `Z:/_statapkg/VERSION` and inside each
  versioned archive. That is the shared manifest; Stata continues to read
  `stata.toc` as well, which it already carried.
- **A `maintenance:` section in `config/surface.yml`**, declaring the update surface
  per language, with the per-leg shape and an explicit `installs: false` for R and
  Python. Guarded in both: R's formals and Python's signature must match the
  declaration.

### The asymmetry is deliberate, and asserted

R and Python **do not install**. Stata's `datalib , update install` can replace
ado-files under a running session; the other two cannot safely do the equivalent:

- `install.packages()` over a namespace that is already loaded fails or corrupts on
  Windows, where the package's own files are locked by the running session;
- `pip install` over a package whose module is already imported leaves the
  interpreter holding half-replaced modules.

So both print the exact command instead of running it. This is **enforced, not just
documented**: each suite asserts it against the *parse tree* rather than the text,
because both functions legitimately print the string `install.packages(...)` /
`pip install ...` as the command for the user to run — a text search matches that
literal and reports a call that does not exist. R walks `all.names(body(fn))`,
Python walks the AST.

### Not a fourteenth contract command

`datalib_update` is declared under `maintenance:`, **not** `commands:`. Which
version you are running is a question about deployment, not about the folder
grammar, and folding it into `commands:` would make the canonical count 14 and
silently destroy the meaning of the Stata-side guard
`test_subcommands_are_exactly_the_canonical_commands`. The R surface guard was
taught the distinction rather than widened — and it caught the 14th export
immediately, which is the guardrail working.

### Also fixed

- **R had no way to report its own version at runtime.** `packageVersion()` fails
  when the package has been *sourced* from a clone rather than installed, which is
  how the test suite and most development sessions run it. `datalib_update()` now
  says so explicitly (`running = NA`, status `unknown`) instead of guessing — and
  the version comparison was split into an internal helper so it is testable at all,
  since on such a machine the report path can never reach it.
- The comparison is numeric per component in every leg. R uses `numeric_version`,
  which gets this right natively; Python compares integer tuples. Both suites pin
  the trap directly, including a test that asserts the *premise* — that as text
  `"0.9.10" < "0.9.9"` — so nobody "simplifies" it back to a string compare.

## [0.9.10] — 2026-07-26

Adds **`datalib , update`** — check the net site this machine installed from for a
newer package, and optionally reinstall. Stata only.

### Added

- **`datalib , update`** reports **three coordinates**: the installed version, the
  version the net site advertises, and which way they differ. It writes nothing.
  `datalib , update install` reinstalls; `force` is needed only to permit a
  downgrade. Backed by `_dl_update.ado`, so the front door stays a dispatcher.
- **It refuses to downgrade.** This is the reason the command exists rather than
  leaving it to `adoupdate`: the failure is not hypothetical. A stale **v0.1**
  snapshot on this net site once silently downgraded a working v0.8 install and
  reinstated the `recode windex5 8=.` data mutation that contract v1 forbids.
  `adoupdate` answers a yes/no question and moves you whichever way the recorded
  source points; this reports the direction and stops.
- **The comparison is numeric per component, not textual.** As strings, `0.9.10`
  sorts *below* `0.9.9` — precisely the comparison this command exists to get
  right. Pinned by conformance case `u-cmp[0.9.10]`.
- **The net site is resolved, not hardcoded**: `netsource()` for one call, then
  `${datalib_netsource}` for the session, then **the source `net install` recorded
  for this machine** (the `S` line in `PLUS/stata.trk`) — literally where this copy
  came from — then `${zDrive}_statapkg`, then `Z:/_statapkg`. The GitHub URL is
  deliberately **not** a default: the repository is private, so an anonymous
  `net install` answers HTTP 404, and the workaround would be putting a token into
  Stata.
- **The installed version is read from `stata.trk`, not from a `*!` stamp.** This
  repo bumps only the files whose contents changed, so `datalib.ado` stamps 0.9.3
  inside a 0.9.10 package — a file stamp is not the package version. Note also that
  `net install ... replace` **appends** a trk entry rather than replacing it (17
  datalib entries on the machine this was written on), so the parser takes the
  **last**.
- `update` is an **option, not a subcommand**: `datalib`'s subcommand list is
  asserted to be exactly the 13 canonical contract commands, and this is a
  Stata-only maintenance affordance, not part of the trilingual contract. It is
  handled before library resolution and returns immediately, because the machine
  most likely to need an update is the one with no library configured yet
  (conformance case `u03`).
- New help section, `help datalib##update`, and **Part 10** of the conformance
  harness (7 cases). The comparison cases recompute the expected verdict
  numerically from the machine's own installed version rather than hardcoding one,
  so they are valid on any machine.

### Fixed

- A `${datalib_netsource}` reference inside a `display` string was **expanded by
  Stata**, so the "no stata.toc" message printed `set .` with the global's name
  eaten. Found by the verification probe. Stata has no backslash escapes, so the
  message now names the global without the `${}` sigil.

### Worth knowing before you rely on it

At the time of writing this command would report **"up to date"** on a fresh
machine — truthfully and uselessly. The installed package, `Z:/_statapkg` and
GitHub `main` are all at **0.9.3**; everything from 0.9.4 on exists only on `dev`.
Detection was never the bottleneck: **publication is**. The versioned
`Z:/_statapkg/<version>/` publish and the `dev`->`main` milestone are Phase 0 of
`internal/PLAN_v0.10.0_alignment.md` and are
still outstanding.

## [0.9.9] — 2026-07-26

Help-file corrections. **No code change in any leg** — every edit is to a `.sthlp`
or a manifest. An audit of `datalib.sthlp` against `datalib.ado` produced 27 claimed
defects; 22 survived adversarial verification and are fixed here, 5 were rejected.

The option *names* were already clean: all 21 agree across `datalib.ado`,
`datalib.sthlp` and `config/surface.yml`, which is what the v0.9.8 guard checks.
Every defect below is something a name check cannot see.

### Fixed — the help promised behaviour the code does not have

- **`latest` is inert.** Documented as "use the latest available year"; nothing
  reads it. `_dlw.ado` declares it and assigns the local when `year()` is empty,
  then never consumes it — latest-year selection is driven purely by `year==""`. Its
  documented escape hatch is also unreachable: `datalib` only calls `_dlw` when
  `year()` is non-empty. Now documented as accepted-for-compatibility, like
  `harmonization()`.
- **`year()` or `survey()` without `country()` does nothing at all.** The help said
  navigation starts; in fact no dispatch branch matches, and the command exits rc 0
  having printed nothing. The Description two sections earlier already stated the
  rule correctly — that internal disagreement is what flagged the Options wording as
  the stale one.
- **`subfoldr(DATA|DOC|PROGRAMS)` does not navigate "directly".** Those three are
  section links that resume from the vintage folder the previous call left in
  `r(subfoldr)`; issued cold they stop with rc 198. Neither the click-state
  dependency nor the error was documented, on the same line that enumerated the
  three values.
- **`path()` is silently ignored for those same three values**, which resolve under
  `${datalib}` regardless — so the documented "base path for `subfoldr()`
  navigation" was false for exactly the values the neighbouring line lists.
- **`path()` together with `subfoldr()` bypasses library resolution entirely** — no
  config chain, no structural library test, no publication to `${datalib}`. This is
  the internal form the clickable links use, and it is the one input combination
  where the page's promise that "a directory that is not a library is refused" does
  not hold.
- **The subcommand form does change `${datalib}`.** The help said it never does.
  `datalib root, root(path) set` writes it — the page recommends exactly that two
  paragraphs earlier as the way to switch library — `datalib root, find` opts into
  descent and discovery, and `datalib config` fills it from the config key.
- **`return add` does not cover a bare `datalib`.** Three of the four dispatch
  branches carry it; the bare-navigation branch does not, and because `datalib` is
  rclass it posts an empty return list — clearing the very click-state it had just
  held and restored. A script relying on `r(subfoldr)` after a bare `datalib` breaks.
- **`datalib` never calls `_mkdir`**, though the Subroutines section listed it as one
  of its subroutines. The creation path is `datalib_create`.
- **Eleven of the thirteen wrappers have no help file of their own**, contradicting
  "each is documented in `datalib_api` and in its own help file". Only the two
  aliases have their own pages.
- **The provenance claim was over-broad.** "On every load ... `ctrycode` and `year`
  are added" is false for a `filename()` load: a named file has no registry module
  and is returned exactly as stored. The same overclaim in `datalib_api.sthlp` is
  qualified too.
- The two-file config search was cross-referenced to `datalib_api`; it is documented
  in `getuserconfig`.

### Fixed — behaviour the help never mentioned

- The **once-per-session validation cache** (`${datalib_checked}`), which skips the
  disk probes while `${datalib}` is unchanged — and therefore does *not*
  re-diagnose a library that moves or is unmounted mid-session.
- That the **config chain is read only by the legacy surface**: the subcommand form
  never reads the config file, so a fresh session with no `profile.do` needs
  `datalib config` once, or an explicit `root()`.
- That an **unrecognised first token is never dispatched** — it falls through to the
  option-only surface and is rejected as a syntax error, with no
  *unknown subcommand* message.

### Fixed — stale metadata

- `datalib.sthlp` was stamped **Version 0.7.0 / Date 2026-07-10 in four places**,
  four minor versions behind, on a file whose content plainly changed during v0.9.x
  (it documents `library()`, which did not exist at 0.7.0).
- Its Version History still labelled the v0.9.0 feature set **"(unreleased)"** —
  telling an operator that features they are already using have not shipped.
- `datalib_api.sthlp` was also stamped 0.7.0, and had no date line.
- `_dl_islib.sthlp` claimed **Version 0.8.0**, a release in which the command it
  documents did not yet exist (the `.ado` says 0.9.3).
- **`_mkdir.sthlp`'s header named the wrong command** — `{cmd:help _vcheck}` — a
  copy-paste that would render the wrong title.
- `datalib.pkg` and `stata.toc` gave **different dates for the same version**.
- Four options accept minimum abbreviations in the code but were rendered without
  the marker; `module`, `master` and `nomerge` now show `{opt mod:ule()}` etc.

### Added

- **Joint attribution in the help headers.** `datalib.sthlp` and
  `datalib_api.sthlp` now credit **Joao Pedro Azevedo and Minh Cong Nguyen**,
  matching the citation and the Provenance section in the README.

### Note on the version number

The help files' content changed here, so they are stamped 0.9.9 rather than
back-dated to a release they did not ship in. This release is *part* of Phase 0 of
`internal/PLAN_v0.10.0_alignment.md`; the rest
of that phase — the rollback floor (tag, GitHub release, `dev`->`main`, a versioned
`Z:/_statapkg` publish) and the CHANGELOG gate corrections — is **still outstanding**.
Tags currently stop at v0.9.3.

## [0.9.8] — 2026-07-26

Adds the guardrail that makes the contract self-defending: a public parameter,
option or subcommand may not be added to any implementation until it is declared
in [`config/surface.yml`](config/surface.yml). **Stata's surface — previously the
only completely unguarded one in the repo — is now enforced on every push,
without a Stata licence.**

### What is actually enforced

The rule people want is "documented before implemented". That ordering **cannot**
be tested: a test sees a snapshot of the tree, not its history. What is enforced
is the equivalent invariant — *at every commit the implemented surface equals the
declared surface*. With CI required on the branch, declaring first becomes the only
way to land code. Adding an undeclared option turns the suite red immediately.

### Added

- **`config/surface.yml`** — one declaration of the public surface: every
  parameter of all 13 canonical commands **in all three languages**, the
  Stata-only commands, the `datalib` subcommand list, the alias relationships, and
  the `source_stage` vocabulary. Comparison semantics differ on purpose: **Stata
  is compared as a set** (its option order does not constrain callers), **R and
  Python as ordered lists** (they match positionally, and their doc tests already
  pin documentation to the signature in order).
- **`python/tests/_stata_parse.py` + `python/tests/test_surface.py`** — the Stata
  enforcer. `.ado` and `.sthlp` are plain text, so the implemented option set is
  read straight out of each `syntax` declaration and compared from Python, in CI,
  on every push. This is the only reason Stata can be guarded at all today.
  Also asserted: the dispatcher's `local subcmds` equals the 13 canonical
  commands; every public `.ado` is declared; every declared option is *mentioned*
  in its help text; `grammar.md`'s prose surface list equals the declaration; the
  `source_stage` vocabulary is the union of the per-language lists and every stage
  is documented; and `datalib.pkg` lists every shipped file.
- **`r/tests/testthat/test-surface.R`** — R's column, plus a check that no
  `source_stage` string emitted by `datalib_root.R` is undeclared.
- **`run_conformance.do` Part 9** — calls each of 11 commands with **every**
  declared option. This exists because `surface.yml` was first *generated* from
  the text parser, so a parser bug would be baked into the declaration and the
  Python guard would confirm it happily. Ten `.ado` files carry their own
  `.sthlp` whose Syntax section agrees exactly with the parse (independent,
  human-written corroboration); `datalib_config` and `datalib_map_drive` are
  covered through their aliases and are deliberately **not** probed live, because
  their remaining options write files, open an editor or shell out to `net use`.

### Fixed

- **Three options were documented nowhere**: `datalib_browse`'s `nodisplay`, and
  `datalib_load`'s `filename()`, `clear` and `debug` on the wrapper form. Found by
  the new mention check, and now documented in `datalib_api.sthlp`.
- **Two hand-typed copies of the public surface are gone.** `test-docs.R` and
  `test_docs.py` each carried a literal list citing `grammar.md` in a comment
  while nothing read it — three copies in total, each free to drift. Both now read
  `surface.yml`, and the redundant R assertion was removed rather than duplicated.

### Deliberately not asserted

That every `*! Version:` stamp inside an `.ado` equals `VERSION`. This repo bumps
only the files whose contents changed, so most stamps legitimately lag (nine
wrappers still read 0.9.3), and `_svycheck` / `_vcheck` carry pre-datalib lineages
of their own (1.7.1, 1.2.0). Asserting a repo-wide stamp invariant would invent a
convention the project deliberately rejects and force churn on every release. What
*is* asserted is the package version a user installs: `datalib.pkg` and
`stata.toc` must equal `VERSION`.

### The cross-language divergence report

Declaring all three languages side by side makes the v0.10.0 work-list explicit
and machine-checked. **9 of 13 commands diverge today**:

| command | divergence |
|---|---|
| `datalib_config` | R and Python lack the writer options (`init` `library` `profile` `replace` `edit`); Python also lacks `configdir` |
| `datalib_root` | Stata lacks `config` `configdir` `report` `user`; R and Python lack `find` `set` |
| `datalib_surveys` | Stata lacks `year`; Python lacks `survey` and `year` |
| `datalib_files` | R lacks `pattern` |
| `datalib_catalog` | R lacks `clear`; Python lacks `clear` and `country` |
| `datalib_load` | the largest: `module`/`modules`, `merge`/`nomerge`, plus `clear` `debug` `filename` `verbose` `columns` `convert_categoricals` `engine` spread unevenly |
| `datalib_browse` | Python takes `token`, Stata/R take `country` + `path`; only Stata has `nodisplay` |
| `datalib_create` | Stata/R use `create`, Python uses `overwrite` + `dry_run` |
| `datalib_map_drive` | Stata `dryrun` vs R/Python `dry_run` |

Only `datalib_countries`, `datalib_vintages`, `datalib_adaptations` and
`datalib_resolve` agree across all three.

### Six parser bugs, each of which failed *silently*

Recorded because they are the reason this guard can be trusted, and because each
would have made the guard assert something false:

1. `syntax [, opt]` hides the positional/option comma inside a **bracket**, so a
   bracket-counting depth tracker never cut and whole option blocks read as
   positional.
2. An `.ado` may define several programs — `getuserconfig.ado` defines the private
   `_dl_parse_cfg` *before* the public `getuserconfig` — so "the first `syntax` in
   the file" was the wrong one, and `getuserconfig` appeared to have 2 options
   instead of 8.
3. `///` means "discard the rest of **this** line and continue", so an inline
   comment (`_ctrycheck.ado`) leaked its prose in as options.
4. A dangling `///` before a blank line (`_vcheck.ado`) swallowed the next comment;
   worse, a bare `path` from it **overwrote** the real `path(string)`, corrupting
   the parse instead of failing. Continuations now stop at a blank or comment line
   so the parser fails **closed**. Stata itself handles both files correctly
   (verified by loading and running them) — these were parser defects, not source
   defects, and neither file was touched.
5. `{opt lib:rary(string)}`, Stata's minimum-abbreviation form, was rejected by a
   regex that excluded `:` from the name.
6. Help files differ in convention — some carry a formal `{synopthdr:Options}`
   table, others name options only in the Syntax section — and prose legitimately
   names *other* commands' options, which produced three false positives. Hence
   the strict check lives on `surface.yml`, where it is reliable, and the help
   check is a deliberately weaker *mention*.

A seventh, in the live probe: Stata's rc 198 conflates "option not allowed" with
"invalid value", so Part 9 must use valid values — `datalib_browse`'s `path()`
takes a library **token**, not a filesystem path. That ambiguity is why Part 9
corroborates the parse rather than replacing it.

## [0.9.7] — 2026-07-26

Makes the error taxonomy **true**, gives it an enforcer in every leg, and settles
enumerator return semantics so a shared corpus is possible. Three of the four
blockers standing between 0.9.x and a credible 1.0.0; the remaining two (CI
billing, install path) are outside the code.

### Fixed

- **The contract documented a bug as if it were the design.** Section 6 listed
  `198/601` for `not_found`, but every failure site in the Stata wrappers exits
  198 — the only 601 a caller could ever observe came from an **unguarded**
  `: dir` extended function on a missing directory, which surfaced Stata's own
  message rather than a datalib one. The three enumerators now check the
  directory first and raise a deliberate, message-bearing **601 when the library
  itself is absent**, keeping **198** for something missing *inside* a library
  that exists. That split is coherent, matches Stata idiom, and makes the
  documented codes reachable on purpose.
- **`datalib_vintages` returned the wrong code for an unknown country.** It lists
  `<root>/<country>` directly, so an unknown country leaked 601 from that same
  `: dir` while `datalib_surveys` returned 198 for the identical mistake. Both now
  return 198.
- **Section 6's premise was wrong.** It presented a per-language mapping as
  though each language could distinguish all five contract errors. Stata has
  **three** usable exit codes for five errors, so its mapping collides *by
  construction* — `input_invalid`, `not_found` and `root_unset` all reach 198, and
  `not_found` and `config_file_missing` both reach 601. The contract now
  identifies errors by **name**, states the collisions plainly, and tells callers
  to treat a Stata `_rc` as a hint rather than an identity. The Alignment status
  table records this as **inherent**, not as a gap awaiting work — a third
  deliberate non-target alongside the `datalib <sub>` front door and a Python
  startup-file writer.

### Added

- **`tests/error_taxonomy.csv`** — the machine-readable contract error mapping,
  and the first artefact in this repo that **enforces** section 6 rather than
  restating it. Each leg asserts its own column against a real trigger
  (`run_conformance.do` Part 8, `test-taxonomy.R`, `test_taxonomy.py`), because a
  name can survive a rename while nothing raises it any more.
- **A doc-truth test for `config/grammar.md`.** `test_taxonomy.py` parses the
  section 6 table out of the markdown and compares it to the CSV. Before this,
  **nothing in any suite had ever read `grammar.md`** — every reference to it was
  a prose citation, which is exactly how its taxonomy table drifted for four
  releases. Verified the test can fail: perturbing one CSV cell turns it red.
- **Two R condition subclasses**, `datalib_error_not_found` and
  `datalib_error_root_unset`, routed at the eleven sites that were raising the
  generic class. **Not breaking**: R conditions carry a class *vector*, and each
  specific class keeps `datalib_error_input` after it, so a handler written before
  v0.9.7 keeps firing. Verified by probe and then by the suite, which asserts the
  old handler still catches the new condition. R now distinguishes all five
  contract errors, so its Alignment status entry moves from *partial* to **yes**.
- **`tests/cases_enumerate.csv`** — ten shared enumerator cases, asserted by all
  three legs. This was declared **impossible** in v0.9.6, and that was correct for
  the design as specified: it matched the *container*, and the three ports return
  structurally different objects. Pinning the **value set** instead makes it
  trivial — all three reach `9 10`, `HLT IPUMS` and `BRA KEN ZWE` from their own
  return types in one expression.
- **Contract rule 9: enumerators pin the value set, not the container** — the same
  move rule 7 makes for paths (identity, not spelling), applied to return types.
  It also pins the **order per enumerator**, because "sorted" alone is not enough:
  vintages sort **numerically**, since sorting 9 and 10 as text yields `10 9`, and
  that trap is live in all three languages.
- **`windows-latest` in the CI matrix**, for both legs. The whole config, writer
  and root-resolution surface is path- and case-shaped, and every operator of this
  library is on Windows — CI tested only the platform nobody uses. It cannot run
  until the billing block clears, but the coverage is in place for the first green
  run.
- **A `[1.0.0] — planned` entry** (above) carrying the release gate.

### Note on the Stata taxonomy

Two designs were considered: (a) state the collisions honestly and correct the
contract, or (b) add a `_dl_err` helper setting `${datalib_error}` to the contract
error name at all 28 exit sites, so Stata could discriminate fully. **(a) shipped**
— it is far cheaper, and no caller is known to branch on *why* datalib failed. (b)
remains **additive**: it can be layered on later without undoing any of this, and
the CSV is already the specification it would satisfy.

## [0.9.6] — 2026-07-26

Tests only — no behaviour change in any of the three ports. Closes the coverage
gap v0.9.5 documented, fixes a latent defect in the Stata harness's own tally,
and gives four canonical commands their first behavioural coverage in the two
CI-runnable languages.

### Fixed

- **The CFG golden cases now run.** They lived in
  `stata/tests/test_config_resolution.do`, which `run_conformance.do` never
  called — it ran only when hand-typed, which is how it came to be cited as
  passing while nothing had executed it (recorded in `tests/DIVERGENCES.md` in
  v0.9.5). They are now **Part 6** of the single entry point, and their bare
  `assert`s — which abort the run instead of tallying a failure — were rewritten
  in the harness idiom. The file is deleted rather than left as a second copy,
  because two copies of the same nine cases is exactly the condition that caused
  the original problem. Coverage went **up**: the six two-file search cases, plus
  `datalib_root` erroring when no key exists anywhere (guarded against an ambient
  `DATALIB_ROOT`, like c04), `config()` pinning one file with the fallback off,
  and the `global`/`argument` precedence stages. Harness total 70 -> 79.
- **The harness could print a negative pass count.** A Part 4 setup guard
  incremented `fails` without the matching `total` that all twenty other sites
  pair it with, while the report prints `total - fails` as its numerator. Latent
  (it needs the scratch-tree setup to fail) but it sat in the Stata leg's only
  regression signal.
- **Two dispatch-recognition probes were not hermetic.** The Part 3 loop called
  every subcommand bare, so `datalib config` read the operator's real
  `~/.config` files and `datalib map_drive` reached `qui shell net use`
  (`mapzdrive.ado:85`) against a live share. Both now pass an option that makes
  the call inert. The assertion is only "the subcommand is recognised
  (rc != 199)", so what is asserted does not change — `datalib config` simply
  reports 601 (the documented config-missing code) instead of 0.
- **CI's R summary hid two outcomes.** The `TOTALS:` line printed pass and fail
  only, so an errored or skipped test did not show up in the one line a reviewer
  reads. It now prints `error=` and `skip=` as well.

### Added

- **`python/tests/test_enumerators.py` and `r/tests/testthat/test-enumerators.R`**
  — `datalib_countries`, `datalib_surveys`, `datalib_vintages` and
  `datalib_adaptations`, four of the thirteen canonical commands, had **no
  behavioural coverage at all** in either CI-runnable language. The only mentions
  anywhere in either suite were name-surface lists in the docs tests (that the
  function exists and is exported), which cannot catch a wrong return value.
  Both files pin uppercase-at-the-boundary (contract rule 1) and
  latest-is-the-numeric-maximum (rule 2) — the latter against `BRA_2015_PNAD`,
  which carries `v09` and `v10` precisely so alphabetical order cannot pass by
  accident.
- **`tests/README.md`** — the CSV dialect contract, one rule per verified reader
  asymmetry. The rules with real bite: a literal `NA` cell becomes R's `NA` even
  under `colClasses="character"` while Python yields the string `'NA'`; a UTF-8
  BOM silently breaks Python (`utf-8`, not `utf-8-sig`) but not R; Stata rewrites
  a literal `.` to empty after import; and these files are **not** byte-identical
  across machines — no `.gitattributes`, `core.autocrlf=true`, so the index holds
  LF, a Windows tree holds CRLF, and CI on `ubuntu-latest` sees LF.
- **One strict xfail**, in Python's enumerator tests: an unknown country must
  raise, and Python still returns `[]` where Stata exits 198 and R raises
  `datalib_error_input`. `pytest.mark.xfail(strict=True)` keeps the suite green
  now and turns the case into a **failure** the moment v0.10.0 fixes it — so the
  marker cannot be forgotten. Verified by probe that strict mode reports
  `[XPASS(strict)]` as a failure, and that this particular case fails for the
  intended reason (`DID NOT RAISE`) rather than a mistyped exception name.

### Deliberately not built

The plan for this release also called for a shared case corpus of eight new CSVs,
a machine-readable error taxonomy, a per-language result ledger, an
`EXPECTED_FAILURES.csv` ledger with four invariants, and a refactor of the Stata
harness into extracted helpers plus `parts/*.do`. An adversarial review of that
design found enough of it unbuildable or unmotivated **today** that it was cut
back to what is load-bearing:

- **A shared enumerator corpus cannot be written yet.** The three ports return
  structurally different objects for the same query — Stata
  `r(adaptations)="HLT:2:1 IPUMS:2:1"` and `r(masters)="9 10"`, R data frames of
  full folder names, Python `VintageCatalog` / `AdaptationInfo`. One shared
  expectation column could match at most one language, and Stata's
  colon-delimited form is illegal in the dialect. Whether the shapes should
  converge is a contract question for `config/grammar.md`, so it is settled there
  first — not papered over in a CSV. Per-language tests (above) close the actual
  coverage gap now.
- **The xfail ledger would have landed with zero rows.** Its two candidate row
  sources were themselves cut, and the apparatus (a testthat helper, a pytest
  parametriser, two invariant test files, a Stata counter and report change, and a
  restructure of both R conformance files from one `test_that` into eighteen) is
  scaffolding for a later phase. The one case that genuinely needs the mechanism
  today gets it from a single `xfail(strict=True)` marker, at no infrastructure
  cost. The ledger will be built in the phase that produces its first row — the
  cost is the same then, minus today's restructure risk.
- **A machine-readable error taxonomy cannot discriminate anything yet.** R has
  three condition classes in total, so three of the contract's five errors
  collapse onto `datalib_error_input`; Stata exits 198 at every failure site in
  `datalib_resolve.ado`. A CSV would be a fourth copy of a table that cannot yet
  distinguish its own rows. It becomes meaningful in v0.10.0, when the classes do.
- **`cases_create.csv` would have duplicated shipping coverage.**
  `test_create_dryrun.py` already pins Python's latest+1 proposal and
  `test-create.R` already pins R's `v01`; the only new fact was the divergence
  between them, which the Alignment status table already records.
- **The `_uc_init` `nodetect` option is deferred.** It was the only source-code
  change in a tests-only release, spans two shipped ado files, and would not have
  achieved hermeticity anyway — the read path probes the real `Z:` share
  independently of the writer. It belongs to the phase that owns the writer.
- **The harness refactor is not done.** Extracting helpers and splitting the parts
  would touch nine sites in the one leg with no CI and a currently-green suite; a
  refactor there can only lose. The three edits that carry their own weight (the
  tally fix, Part 6, the two hermeticity fixes) are in; the tidy-up is not.

Two design errors were caught before implementation and are worth recording: a
proposed `stata_rc_alt` column would have expanded to `if (198!=198 & 198!=)` — a
syntax error aborting the harness before its epilogue and its restore block —
and a proposed hermeticity fix referenced the harness's `TMP` local at line 233,
which is not defined until line 297.

## [0.9.5] — 2026-07-26

Documentation only — no behaviour change in any of the three ports. This is the
**contract freeze**: `config/grammar.md` is corrected to describe what the
implementations actually do, before v0.10.0 changes them. Every claim below was
checked by execution or source read, not inference.

### Fixed — contract text that was false

- **"the path is returned as given" was false in two of three languages.**
  `grammar.md` §7 said the default root resolution returns the candidate
  unchanged. Verified: Stata does; **R normalises** it (`fs::path_norm` collapses
  `..`, expands `~`, strips a trailing separator); **Python returns a `Path`**
  whose Windows string form uses backslashes and keeps `..`. Given `Z:/a/../b`
  the three return `Z:/a/../b`, `Z:/b` and `Z:\a\..\b` — no two agree.
  The contract now pins the resolved **identity, not its spelling**, and says
  outright that a returned root must not be compared byte-for-byte across
  languages. The same false sentence had been copied into
  `stata/src/d/datalib_root.ado`, `stata/src/d/datalib_api.sthlp`,
  `python/src/datalib/config.py` and `.github/copilot-instructions.md`; all four
  are corrected. What survives unchanged: the default still does **not** touch
  the disk, so a nonexistent root still resolves and fails later.
- **The `source_stage` vocabulary contradicted itself.** The text called the
  strings "byte-identical across languages" and then listed three per-language
  exceptions. Both halves could not be true. Replaced with a
  mechanism-by-language table — and it documents `unset`, a **sixth** stage that
  Stata and R both return and the contract had never mentioned.
- **Per-domain config keys were advertised and read by nobody.**
  `datalib_hlt:` / `_edu:` / `_nut:` / `_chp:` appeared as commented examples in
  both config templates and in `grammar.md`. `getuserconfig` publishes a fixed
  global list and discards every other key it parses, so those lines reached
  nothing. Removed from both templates. The trap they hid is now documented:
  `${datalib_hlt}` *does* work in the HLT workflows, but because
  `profile_datalib.do` sets that global directly — not because any config key
  feeds it, so adding the key and expecting the global is silent failure.
- **A rule two implementations cite as the contract was missing from it.** "A
  missing section directory is an empty listing, not an error" is asserted in the
  Stata and R sources but appeared nowhere in `grammar.md`. Added as rule 8 —
  appended rather than inserted mid-list, because `section 7` is cited by name
  from `r/R/datalib_config.R`, `python/src/datalib/config.py` and
  `.github/copilot-instructions.md`, and renumbering would silently redirect
  those citations.
- **`_dl_islib.ado`'s header contradicted its own code.** It advertised "holds at
  least one country-code-shaped (3-character) folder" — exactly the weaker test
  the code's inline comment explains is unsafe (`C:/` has `c:/ado`, so a missing
  library would resolve to its parent and have that parent's subfolders read as
  country codes). The header now describes the `<CCC>/<CCC>_*` **grandchild pair**
  the code actually requires.
- **`stata/README.md` claimed "57 cases" and "Parts 3–4"** against a harness that
  is now five parts with c01–c14 and i01–i11. Replaced with a per-part table and
  no hardcoded total — the harness prints its own.

### Added

- **An Alignment status table** in `grammar.md`: per-surface Stata/R/Python state
  and the version that closes each gap. This replaces hedged prose as the way the
  contract handles one leg being ahead, and names the two surfaces that are **not**
  convergence targets (the `datalib <sub>` front door; a Python startup-file
  writer).
- **[`r/README.md`](r/README.md)** — R was the only leg without one, so
  `docs/README.md` had been pointing readers at `r/DESCRIPTION`. Documents the
  reader/resolver split, the `source_stage` values, the normalisation caveat,
  what is not yet at parity, and the `roxygen2` doc-truth constraint. Its usage
  examples were checked against the actual `formals()`: R's loader takes
  `module =` (singular) and `merge = TRUE` today, both renamed in v0.10.0.
- Two rules in `CONTRIBUTING.md`: the contract is **descriptive, not
  aspirational**, and `VERSION` must be bumped in lockstep with the five files
  three tests pin to it.

### Changed

- `tests/DIVERGENCES.md` §2 — `find` as a "sanctioned Stata-only extension" is
  **withdrawn in place, not deleted**, with a claim-by-claim table of what
  replaced it. `find` is being promoted into contract v2 in v0.10.0, so a reader
  who remembers the old rule sees it retired rather than silently gone.
- `tests/DIVERGENCES.md` now records the **coverage gap that let a regression
  through**: `stata/tests/test_config_resolution.do` is not called by
  `run_conformance.do` and runs only when hand-typed, which is how it was cited
  as passing during v0.9.x while nothing had executed it. Folding it into the
  single entry point is scheduled for v0.9.6.

### Unchanged, deliberately

- `contract_version` stays **1**. Python pins it, so bumping it in a docs-only
  release would break the suite; it becomes **2** in v0.10.0, in the same commit
  as both synced copies.

## [0.9.4] — 2026-07-25

### Fixed
- **R's public `datalib_config()` bypassed the config seam.** It hardcoded
  `~/.config/user_config.yml`, so the two-file fallback and the
  `DATALIB_CONFIG` / `DATALIB_CONFIG_DIR` isolation hooks — added in 0.8.0 —
  lived only in `datalib_root()`'s private helpers. The two public functions
  therefore disagreed about where configuration lives: on a machine configured
  via `datalib_config.yml`, `datalib_root()` worked while `datalib_config()`
  raised `datalib_error_config_missing`. The search now lives in the reader,
  which reports `source_stage` / `source_file` like Stata's `getuserconfig`, and
  `datalib_root()` delegates to it — one resolver instead of two that can
  disagree. The CFG cases missed this because they only ever called
  `datalib_root()`; the new cases call the reader directly.
- **`withr` was an undeclared R test dependency** (13 uses), absent from
  `Suggests` and from the CI install list; it worked only via `testthat`'s
  transitive import, and `R CMD check` would have flagged it.
- **Version drift.** `r/DESCRIPTION` and `python/pyproject.toml` both said
  `0.1.0` against a repo at 0.9.3. A new `VERSION` file at the repo root is now
  the single source of truth, pinned by a test in each language — `contract_version`
  was already pinned this way, the package version was not.

### Added
- `configdir` argument on R's `datalib_config()` and `datalib_root()`, for
  parity with Stata's `configdir()` accommodation and so a test can redirect the
  search without setting an environment variable.

## [0.9.3] — 2026-07-25

### Fixed
- **The generated `profile.do` no longer nags after `ado uninstall datalib`.** It
  called `capture noisily getuserconfig`, and `capture noisily` on a missing
  command still *prints* `command getuserconfig is unrecognized` — so a machine
  that had uninstalled the package got that error at every Stata launch, from a
  file the package writes but cannot remove. The generated profile now checks the
  command exists first.
- **The `profile.do` writer could emit a truncated file.** An embedded quote in a
  generated comment ended the `file write` string early (Stata has no backslash
  escapes), aborting the writer, so the profile shipped without its code lines —
  a silent no-op that still returned rc 0. Pinned by conformance case i11, which
  asserts the code lines are present rather than that writing succeeded.

### Changed
- Documentation no longer claims the PERSONAL `profile.do` runs in *every*
  session: Stata searches the **current directory first**, so a project folder
  with its own `profile.do` takes precedence and this one does not run there.

## [0.9.2] — 2026-07-25

> **Why PATCH and not MINOR.** The new command surface is Stata-only, and the
> cross-language contract is untouched: `datalib_root`'s default resolution, the
> `datalib:` config key, the `source_stage` vocabulary and the golden cases are
> all unchanged, so R and Python read exactly what they read at 0.9.1. The
> release therefore adds nothing to the *package contract* the three languages
> share. **0.10.0 is reserved for the version in which R and Python gain the
> same features**, which is where this belongs as a MINOR bump.

### Added
- **`getuserconfig, init` — bootstrap an operator's configuration.** Writes a
  prepopulated `user_config.yml` block filling in everything Stata can detect:
  the block name from `c(username)`, `githubFolder` from `whereis github`,
  `zDrive`/`zDriveUNC` from `mapzdrive, discover`, and the library from whatever
  the caller resolved. Anything ambiguous is written as a commented `TODO` with
  the candidates listed rather than guessed — `teamsRoot` in particular, since a
  UNICEF machine has a dozen synced roots. Candidates are listed case-correctly
  using Mata's `dir()`, because the `dir` macro function lowercases names on
  Windows and a lowercased path can be wrong for the R and Python readers.
- **`profile` option** manages a startup `profile.do` in `c(sysdir_personal)` —
  on the adopath, so Stata runs it at launch, and writable without administrator
  rights. It is checked, created only when absent, and **never overwritten**: an
  existing profile is likely to hold the operator's own startup code.
- **Both already in place → nothing is written and both files are opened** for
  editing. Files are opened only in the GUI: `doedit` does not exist in a console
  or batch session, so `c(console)` is checked first and the paths printed
  instead.
- **`datalib config, init`** is the datalib-side entry point: it resolves the
  library with `datalib_root, find` and hands the value to the generic writer.
- **`profile_datalib.do` bootstraps automatically.** On a machine with no
  configuration (`getuserconfig` rc 601) it runs `datalib config, init profile`
  and re-reads. The profile is the setup step, so a write there is expected —
  whereas `getuserconfig` itself stays a pure read.
- New packaged internal `_uc_init` with its help file.

### Changed
- `getuserconfig` is **1.2.0** and remains **generic**: it knows the config
  schema, not any project. A value needing project knowledge is passed in via
  `library()`. The bootstrap outcome is reported as `r(init_action)`,
  `r(init_file)`, `r(init_profile)`, `r(init_todo)` — under their own names,
  because when the configuration is complete the command carries on to the read,
  whose returns would otherwise replace them.

### Fixed
- `getuserconfig` now strips a **UTF-8 BOM** as well as CR before parsing. A
  BOM-prefixed config — what Windows PowerShell's `Out-File` and `>` produce by
  default — made the first line eight characters, so the leading username block
  went unrecognised and the command reported "no entry for user" on a file that
  plainly had one. Pre-existing since the parser was written; surfaced by the new
  BOM conformance case.

### Unchanged (deliberately)
- **The config read path still never writes.** A read that created files on
  failure would make the CFG golden cases non-hermetic — they exercise the
  missing-file and missing-key paths — and would repeat the `_mkdir`
  side-effect defect recorded in `tests/DIVERGENCES.md`.

## [0.9.1] — 2026-07-25

### Fixed
- **Interactive navigation into `DATA` / `DOC` / `PROGRAMS` was broken by 0.9.0.**
  Those section links resume from the folder the previous `datalib` call left in
  `r(subfoldr)`. 0.9.0 began resolving the library at the top of `datalib`, and
  `datalib_root` is `rclass`, so the resolution wiped `r()` before `_foldernav`
  could read it back. `local subfoldr = r(subfoldr)` on a missing result yields
  `.`, so the path became `<root>/./Data/Stata/` and the call failed with a
  confusing r(601) — `directory Z:/datalib/./Data/Stata/ not found`.
  `datalib` now holds and restores `r()` around the resolution, so the
  click-state survives.
- `_foldernav` reads the click-state once, as a string, and stops with an
  actionable rc 198 when it is absent, instead of building a path with a missing
  component in it.

### Changed
- The library is validated **once per session** rather than on every call: after
  a successful resolution `datalib` records the value in `${datalib_checked}` and
  skips the disk probes while it is unchanged. Besides removing the `r()` churn,
  this stops a slow network share from being probed on every navigation click.

## [0.9.0] — 2026-07-25

### Added
- **Stata subcommand dispatch.** `datalib <subcommand>` now runs the matching
  contract v1 wrapper (`datalib resolve, ...` → `datalib_resolve, ...`) for all
  13 wrappers, returning its `r()` results unchanged. Exact lowercase match
  only; the option-only legacy surface is untouched. The `datalib_*` commands
  remain the canonical cross-language API — the dispatcher is Stata-side
  convenience.
- **Root bootstrap on the legacy surface.** When `${datalib}` is unset, bare
  `datalib` (and every legacy-mode call) now fills it once from the config
  chain (`getuserconfig` → `DATALIB_ROOT` env var) instead of dying inside
  `_foldernav` with r(601) `directory ... not found` — where the path shown was
  the literal `/`, because the unset global left `"${datalib}/"`. If no root can
  be found it now errors upfront with rc 198 and an actionable message.
- **`library()` option on `datalib`** — names the library for one call and
  outranks `${datalib}`, the config chain and discovery. It is resolved against
  the disk (a `library()` that is not a library is always an error) and published
  to `${datalib}`, because the clickable navigation links carry no options and
  must find the same library on the next call. `library()` is a legacy-surface
  option; the subcommand form and the `datalib_*` wrappers take `root()`, which
  does not touch the global.
- **`datalib_root, find`** — opt-in disk resolution, used by the `datalib`
  command. Candidates are tested in the contract precedence order, so one that
  is not a library never shadows a later one; each may name the library *or* the
  place holding it (`<cand>/datalib` first, `r(descended)`=1); a candidate that
  is set but is not a library is an **error** naming it, never silently replaced;
  and a library named `datalib` is discovered under `${zDrive}` then `Z:/` only
  when nothing at all is configured (`r(source_stage)`=`discovered`). Paths are
  normalized (backslashes, trailing separators, drive roots preserved).
- **`_dl_islib`** — new packaged internal implementing the structural library
  test: a directory named `datalib`, or carrying a `.datalib` marker, or holding
  a `<CCC>/<CCC>_<YYYY>_<SURVEY>` pair. Testing structure rather than mere
  existence is what stops a missing library from resolving to its parent, whose
  subfolders would otherwise be enumerated as country codes.

### Changed
- `profile_datalib.do` now reads the operator's configuration first
  (`getuserconfig`, then `DATALIB_ROOT`) and resolves it with
  `datalib_root, find set`, instead of hardcoding a root. It distinguishes "the
  package is not installed" (rc 199) from "no library resolved", and no longer
  shadows a configured `datalib:` key.

### Unchanged (deliberately)
- **`datalib_root`'s default behaviour is untouched**: pure string selection,
  first candidate wins, returned as given, disk never touched — byte-identical to
  R and Python, including that a nonexistent `root()` resolves successfully with
  `source_stage` `argument`. The CFG golden cases
  (`stata/tests/test_config_resolution.do`) pass unmodified, and the
  cross-language `source_stage` vocabulary keeps its meaning; `discovered` occurs
  only in `find` mode. Specified in `config/grammar.md` §7, cross-referenced from
  `tests/DIVERGENCES.md`.

## [0.8.0] — 2026-07-12

### Added
- **Two-file config-root fallback (the ecosystem config seam).** The library
  root now resolves from a two-file, key-presence search: the current user's
  block is read first from `~/.config/user_config.yml` (the file shared with
  the CSO Toolkit) and then from `~/.config/datalib_config.yml`; the first file
  whose user block carries a non-empty `datalib:` key wins (block-level, never
  merged; an empty value counts as absent). A `config/datalib_config.yml`
  template ships.
- **`datalib_root` now reports where the root resolved from** —
  `source_stage`/`source_file` attributes on the returned path (R),
  `resolve_root(report=True)` returning a `RootResolution` (Python), and
  `r(source_stage)`/`r(source_file)` on `getuserconfig` (Stata). The
  `source_stage` strings are byte-identical across languages (`argument`,
  `env`, `config_generic`, `config_package`; `option` in R, `global` in Stata).
- **Isolation hooks**: `DATALIB_CONFIG` pins one file (fallback off);
  `DATALIB_CONFIG_DIR` searches the two-file list in another directory; Stata
  additionally accepts a `configdir()` option (it cannot set env vars
  in-session). CFG golden cases added to all three suites.

### Changed
- The `datalib:` key in `~/.config/user_config.yml` is now optional in the
  documented sense that its absence falls through to `datalib_config.yml`
  rather than erroring. Contract updated in `config/grammar.md` section 7.
- **`getuserconfig`** bumped to 1.1.0 and refactored around an internal
  per-file parse. (A companion cso-toolkit change adds an indent guard to
  `dw_load_config` so the shared `user_config.yml` safely carries both the
  toolkit's flat keys and datalib's per-user block.)

## [0.7.0] — 2026-07-11

### Added
- **World Bank lineage references** in README Related Projects: datalibweb, GLAD,
  SARMD (+ guidelines, harmonized household surveys) and SAR Labor Force Surveys —
  all URLs verified live.
- **DB-Managers briefing** (`internal/BRIEFING_microdata_archive.md`) — one-page
  circulation piece: silos → archive, the archive/catalogue/tool distinction,
  stock vs flow, the two-week start, the four open decisions.
- README Project Structure now shows the package-internal layouts of `r/`,
  `python/`, and `stata/`.

### Changed
- **`stata/` reorganized** into `src/` (ados + help, by initial letter), `doc/`
  (markdown guides), `tests/` (the conformance harness, moved from
  `tests/stata/` for symmetry with `r/tests` and `python/tests`), and a package
  `README.md`. `datalib.pkg` + `stata.toc` stay at the `stata/` root, so the
  published `net install ... from(".../stata")` path is **unchanged**; run the
  harness with `do stata/tests/run_conformance.do` from the repo root.
- **Governance draft v0.3** (docs/GOVERNANCE_microdata_deposit.md), reframed for the
  UNICEF DB-Managers review: the initiative is a **microdata archive** (with the
  archive / catalogue / tool layers explained); scope = household surveys used for
  global child monitoring, evolving to other survey types and anonymized public-use
  files; **thematic domains** replace "indicator families" (registry mapped to the
  Z:/datalib-* trees); corrected promotion target (canonical microdata trees — never
  060.DW-MASTER, which holds aggregates); a 7-item review-gate checklist; access
  tiers / licensing / de-identification section (restoring the ECATSD lineage pieces);
  phase entry/exit criteria; role-based wording with a Current-appointments block;
  a pragmatic "first two weeks" start plan; glossary.
- New **docs/DEPOSIT_QUICKSTART.md** — one-page depositor guide for unit focals.
- **config/grammar.md** gains a "Deployment topologies" note (single-root contract
  model and the per-domain multi-root pattern both supported; canonical topology is
  an open Standards-Board decision); per-domain root keys added as commented
  examples in the user-config template.
- scripts/ps README no longer hardcodes the real storage-account UNC.

## [0.6.0] — 2026-07-11

### Added
- The four remaining Stata wrappers completing the 13-command shared surface:
  `datalib_config`, `datalib_root`, `datalib_browse`, `datalib_map_drive` (PR #23).
- `datalib_files`: six shared section names in all three languages (`data`,
  `data-original`, `data-r`, `data-other`, `doc`, `programs`); a missing section
  directory is an empty listing, not an error.
- Conformance: `expect_provenance` pins the `ctrycode`/`year` provenance columns
  in every language; fixture library gains `Data/R` (grammar-complete).

### Fixed
- `datalib_load` (Stata) honors the `DATALIB_ROOT` environment variable.
- `_dlw` adds provenance columns on master loads (previously registry loads only).
- R merge: matched-row NA in the master survives (Stata/pandas semantics).
- Contract docs made precise: provenance in grammar §4, exact per-language root
  precedence in §7, truthful shared-surface statement, collections.yml header.
- Root README: self-contained-package dependencies (the project profile is not
  part of the installed package), `Data/Other` in the convention, tests/ + CI in
  the structure tree, registered-collections wording, MIT named in License.
- The Azevedo & Nguyen design paper is now cited as an **unpublished working
  draft** everywhere; it had been mispresented as a forthcoming Stata Journal
  article.
- Documentation review remediation (batches B/C): `datalib.sthlp` + `_dlw.sthlp`
  rewritten against the v1.10 engine; clone-first INSTALLATION; corrected helper
  r() tables; `datalib:` key documented in getuserconfig help; the developer
  guide (`.github/copilot-instructions.md`) fully rewritten for the trilingual
  architecture; IMPROVEMENT_PLAN banner + per-part status table.

## [0.5.1] — 2026-07-11

### Added
- Self-documenting packages with mechanically-enforced doc truth (PR #18):
  roxygen2 `man/` pages for all R exports; numpy-style docstrings across the
  Python public surface; +141 doc-truth tests (R 48 → 75, Python 62 → 176)
  asserting documented parameters identically match real signatures and the
  export sets match the contract.

## [0.5.0] — 2026-07-10

### Breaking
- **Repository layout**: package-first, multi-language layout mirroring the unicefData-dev
  house pattern. The Stata package root moved `02_programs/src` → **`stata/`**; the
  `net install` URL is now `https://raw.githubusercontent.com/unicef-drp/datalib-unicef/main/stata`
  (old URL 404s — reinstall once; see README "Upgrading from ≤ 0.4").
- **`_dlw` loader semantics repaired** (see PR #7):
  - Multi-module merges use explicit registry keys validated per module with `isid`
    (HLT persons chain 1:1 on `svy_id cluster_id household_id line_number`; hh-level
    modules attach m:1). The previous unkeyed row-order merge is gone; modules whose
    identifiers are missing/duplicated stop the merge with an actionable error.
  - Removed the undocumented `recode windex5 8=.` mutation from the loader.
  - `vm()`/`va()` default to the numerically latest vintage on disk; accept `1`/`01`/`v01`/`V01`.
  - Exact country matching with case normalized at the boundary; exact survey-suffix matching.
  - Master files loadable via `module()`/`filename()` (previously hard-blocked).
- `scripts/py` and `scripts/ps` are no longer distributed inside the ado package
  (`net install` ships only the Stata commands).

### Added
- **Contract v1** (`config/grammar.md` + `config/collections.yml`): the language-neutral
  `datalib_*` API, with nine Stata wrapper commands (`help datalib_api`), a committed
  synthetic fixture library, 18 golden conformance cases, and `tests/DIVERGENCES.md`.
- **R package `r/`** (`datalib`): all 13 contract functions; testthat suite (48 tests)
  reads the shared golden cases.
- **Python package `python/`** (`unicef-datalib`, `import datalib`): full surface, pure
  AppLocker-safe wheel, `python -m datalib`; pytest suite (62 tests) reads the same cases.
- **CI** (`.github/workflows/conformance.yml`): R + Python conformance on push/PR;
  the Stata leg runs locally (`do tests/stata/run_conformance.do`) as a release gate.
- Optional `datalib:` root key in `~/.config/user_config.yml`, honored by all three
  implementations (Stata `getuserconfig` fills `${datalib}` when unset).
- `CHANGELOG.md`, `CONTRIBUTING.md`; `internal/` for plans and generated reports.
- `LICENSE` and `data/hosted_in_repo/*.csv` are now tracked (both were silently
  gitignored by the extension allowlist — the CSV is a required input of the
  MICS/IPUMS import workflows).

### Fixed
- `scripts/py/recursive_file_finder.py` executed a **delete on Z:** at import time;
  now guarded under `__main__` and list-only by default.
- Version-string drift aligned (pkg 0.4 / toc 0.3 / sthlp 0.2 / ado 0.1 → 0.5.0-dev).

## [0.4] — 2026-07-10
- **Repositioning**: repo renamed to `datalib-unicef` (command stays `datalib`); README
  refocused on the UNICEF CSO ecosystem (CSO Toolkit, CSO Handbook, unicefData).
- **Removed the Brazil/IBGE ingestion subsystem**: the `ibge` command, the IBGE/INEP
  Python downloaders, the `020_bra*` pipeline, the `datazoom_social` dependency, and
  Brazil examples/docs. `datalib` is now ingestion-agnostic.
- **Documentation**: file-naming guidance inside the folder convention — harmonised
  `Data/Stata` + `Data/R` vs raw `Data/Original` vs non-microdata `Doc/` + `Programs/`.

## [0.3] — 2026-07-10
- **New commands**: `getuserconfig` (per-operator paths from `~/.config/user_config.yml`)
  and `mapzdrive` (map the Z: mirror from that config).
- **Config template** shared by the R and Stata onboarding routines.
- **Governance**: microdata-deposit governance proposal (docs/GOVERNANCE_microdata_deposit.md).
- **Documentation**: design-paper reference (Azevedo & Nguyen, draft) + annotated reference library.
- **Packaging**: `datalib.pkg`/`stata.toc` tracked so `net install` from the repo works.

## [0.2] — 2024-12-19
- **Bug fix**: `_foldernav` refactored into a standalone program file.
- **Documentation**: comprehensive help for `_foldernav`; updated `datalib.sthlp`.
- **Repository**: references updated to the UNICEF DRP GitHub organization.

## [0.1] — 2024-08-18
- Initial release: interactive folder navigation and data-loading utilities.
