# Language-neutral conformance fixtures

[← datalib README](../README.md) · [Documentation hub](../docs/README.md) ·
[the contract](../config/grammar.md) · [divergences](DIVERGENCES.md)

The golden cases every implemented language must pass unmodified, and the fixture
library they run against.

| file | what it drives |
|---|---|
| `cases_resolve.csv` | 12 path-resolution cases (Stata Part 1, `test-conformance-resolve.R`, `test_conformance_resolve.py`) |
| `cases_load.csv` | 6 load/merge cases (Stata Part 2, `test-conformance-load.R`, `test_conformance_load.py`) |
| `cases_enumerate.csv` | 10 enumerator cases (Stata Part 7, `test-conformance-enumerate.R`, `test_conformance_enumerate.py`) |
| `error_taxonomy.csv` | the contract error mapping (Stata Part 8, `test-taxonomy.R`, `test_taxonomy.py`) |
| `fixtures/library/` | the fixture tree all cases resolve against |

## The CSV dialect

Three readers consume these files and **none of them negotiates**:

| language | call |
|---|---|
| Stata | `import delimited "tests/cases_resolve.csv", varnames(1) stringcols(_all) clear` |
| R | `read.csv(<path>, colClasses = "character")` |
| Python | `csv.DictReader(open(path, "r", encoding="utf-8", newline=""))` |

The rules below are not style preferences. Each one exists because a reader
behaves differently from the others, verified by probe — break one and a case
silently changes meaning in one language while passing in the other two.

**D1 — Comma-delimited, and never quote anything.** No reader is configured to
handle quotes (Stata passes no `bindquotes`), and the corpus contains zero quote
characters of any kind. It follows that **no cell may contain a comma** — there
is no mechanism to protect it.

**D2 — Every column is a string in every reader.** All three force it
(`stringcols(_all)`, `colClasses = "character"`, `DictReader`). Never rely on
type inference, and convert to a number explicitly in the test when you need
one. This is what makes a column that is numeric in some rows and blank in
others safe.

**D3 — An empty cell is a zero-length field.** Write `a,,b` — no placeholder, no
`NA`, no `.`, no `""`. Stata additionally rewrites a literal `.` to an empty
string after import (`run_conformance.do:71-72`), so `.` can never survive as a
value even if you wanted it to.

**D4 — Never write a literal `NA`.** R's `read.csv` keeps `na.strings = "NA"`
**even under `colClasses = "character"`**, so an `NA` cell arrives as R's `NA`
(`is.na()` true), while Python hands back the two-character string `'NA'` and
Stata a literal `NA`. Verified: only exact uppercase `NA` does this — `na`,
`N/A`, `NaN` all stay strings in all three. A sentinel that reads as missing in
one language and as text in another is the worst kind of case, because it passes.

**D5 — No UTF-8 BOM.** Python opens these files as `utf-8`, not `utf-8-sig`, so a
BOM becomes part of the first header name and every `row["case_id"]` raises
`KeyError`. R strips it silently, so the damage is invisible until CI's Python
leg runs. Verified in both directions.

**D6 — A space-separated cell is a list.** `cases_load.csv`'s `modules` column
uses a space as the list delimiter inside one unquoted field. Do not put
incidental whitespace anywhere else.

**D7 — Header names must be legal Stata variable names.** `import delimited`
turns the header row into varnames: at most 32 characters, no leading digit, no
reserved word, `[A-Za-z0-9_]` only.

**D8 — Adding or renaming a column is a three-file change.** The Stata, R and
Python readers each name their columns independently; there is no schema to
enforce agreement. Change all three in the same commit, or one leg reads a
missing column as empty and silently stops asserting.

**D9 — These files are not byte-identical across machines, and must not be
assumed so.** The repo has no `.gitattributes` and `core.autocrlf=true`, so the
git index stores LF while a Windows working tree checks out CRLF; CI runs on
`ubuntu-latest` and sees LF. The files are *semantically* identical. Compare
parsed values, never bytes.

## Fixture library

`fixtures/library/` holds three countries. Two properties are load-bearing and
must not be "tidied":

- **`BRA_2015_PNAD` carries `v09` and `v10`.** This is the only reason
  "latest is the numeric maximum" (contract rule 2) cannot pass by accident:
  alphabetical or directory-listing order picks `v09`, numeric order picks `v10`.
- **`ZWE_2019_MICS`'s `windex5` retains the value 8.** Pre-0.5 Stata silently ran
  `recode windex5 8=.`; the `expect_windex8` column in `cases_load.csv` pins that
  loaders never mutate values (contract rule 4, divergence #2).

## Running the suites

```bash
# R and Python are the CI-runnable legs
Rscript -e 'testthat::test_dir("r/tests/testthat")'
cd python && python -m pytest

# Stata has no CI licence: manual pre-release gate, from the repo root
# (the harness insists on the repo root, because it reads these files by
#  relative path)
do "stata/tests/run_conformance.do"
```

## Enumerators: value set, not container

The three ports return structurally different objects for the same query — Stata
`r(masters)="9 10"` and `r(collections)="HLT IPUMS"`, R data frames of full folder
names, Python `VintageCatalog` / `AdaptationInfo`. A corpus matching the
*container* can match at most one language, and a first attempt at
`cases_enumerate.csv` was abandoned on exactly that ground.

[`config/grammar.md`](../config/grammar.md) rule 9 resolves it by pinning the
**value set** and its order, not the type: each leg adapts its own return in one
expression, and all three reach the same string. `BRA 2015 PNAD` masters
normalise to `9 10` everywhere. Note the order rule is per enumerator — vintages
sort **numerically**, because sorting 9 and 10 as text gives `10 9`, and that trap
is live in all three languages (`: list sort`, `sort()` on character, `sorted()`).

Two things stay per-language, and are asserted in `test-enumerators.R` /
`test_enumerators.py` rather than in the corpus: each leg's own return *shape*,
and whether an enumerator **raises** on an absent parent — which still differs
(see the [Alignment status
table](../config/grammar.md#alignment-status)). That is why
`cases_enumerate.csv` carries no error rows: the shared corpus stays green in all
three legs.

## The declared surface

[`config/surface.yml`](../config/surface.yml) declares every public parameter in
all three languages. `python/tests/test_surface.py` enforces it -- including
**Stata's**, by parsing `syntax` out of each `.ado` as text, which is how the one
leg with no CI licence gets guarded at all -- though only as well as the run:
Actions is billing-blocked and neither branch is protected, so today this is a
**local** gate, not a per-push one. `r/tests/testthat/test-surface.R`
covers R's column, and `run_conformance.do` Part 9 calls each command with every
declared option, because `surface.yml` was first generated from that parser and
would otherwise bake in any parser bug.

Comparison semantics differ on purpose: **Stata is a set** (its option order does
not constrain callers), **R and Python are ordered lists** (they match
positionally, and their doc tests already pin documentation to the signature in
order).

## The error taxonomy

`error_taxonomy.csv` is the machine-readable form of `grammar.md` section 6, and
each leg asserts its own column against a real trigger — asserting that a name
*exists* is not enough, because a name can survive a rename while nothing raises
it. `test_taxonomy.py` additionally parses the section 6 table out of
`grammar.md` and compares it to the CSV: before v0.9.7 **nothing in any suite had
ever read `grammar.md`**, which is how its table came to document an accidental
Stata rc 601 leak as though it were the design.

Known deliberate divergences from pre-contract behaviour, and the surfaces where
one language is still ahead, are recorded in [`DIVERGENCES.md`](DIVERGENCES.md)
and the contract's
[Alignment status table](../config/grammar.md#alignment-status).

---

[← datalib README](../README.md) · [Documentation hub](../docs/README.md)
