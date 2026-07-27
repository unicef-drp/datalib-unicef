# Contributing to datalib-unicef

Thanks for contributing. The essentials:

## Workflow

- Base branch is **`dev`**; `main` is the release trunk (the `net install` URL serves from
  `main/stata`). Branch off `dev`, open a PR into `dev`. **`dev` → `main` PRs happen only
  at version milestones** (a CHANGELOG release entry + version bump), never per-batch.
- Conventional Commits (`feat:`, `fix:`, `feat!:`/`BREAKING CHANGE:`); SemVer.
- Update [CHANGELOG.md](CHANGELOG.md) with user-visible changes.

## Repo shape (trilingual suite)

One shared public API — the `datalib_*` functions — implemented per language:

| Home | Contents |
|---|---|
| `stata/` | The ado package (net-install root: `datalib.pkg` + `stata.toc` must stay at this root, and every packaged file must be listed as an `f` entry) |
| `r/` | R package `datalib` ([`r/README.md`](r/README.md)) |
| `python/` | Python package `unicef-datalib` (import `datalib`, [`python/README.md`](python/README.md)) |
| `config/` | The language-neutral contract data (collection registry, user-config template) |
| `tests/` | Language-neutral conformance fixtures + golden cases — a behavior change must keep **all** implemented languages passing the same cases |

## Rules of the road

1. **Semantics are contract-first.** Path resolution, catalog, matching, and "latest"
   rules live in the shared contract; don't change one language's behavior alone.
2. **Loaders never mutate data.** No hidden recodes; merges only on validated keys.
3. **`.gitignore` is a deny-all allowlist.** New file *types* must be added as
   `!/**/*.<ext>` (or explicit path) rules or they will be silently untracked.
4. **Windows + AppLocker friendliness.** Pure-Stata/R/Python only; no unsigned
   executables; Python ships no console-script shims (`python -m datalib`).
5. **The contract is descriptive, not aspirational.** `config/grammar.md` states
   what the three ports *do*, not what they should do. When one leg is ahead,
   say so in the [Alignment status
   table](config/grammar.md#alignment-status) and name the version that closes
   it — never write a claim that is true of no implementation. v0.9.5 withdrew
   two such claims that had been copied into five files, so a wrong sentence
   here propagates.
6. **Declare a parameter before you implement it.** Every public option,
   argument and subcommand is declared in
   [`config/surface.yml`](config/surface.yml), and
   `python/tests/test_surface.py` + `r/tests/testthat/test-surface.R` assert the
   code against it in all three languages. The *ordering* cannot be tested -- a
   test sees a snapshot, not history -- so what is enforced is the equivalent
   invariant: **at every commit the implemented surface equals the declared
   surface**. Adding an option without declaring it turns the suite red, so
   declaring first is simply the path of least resistance. Internal `_*` helpers
   are deliberately out of scope: the contract covers the public surface, and
   forcing private plumbing into it would make the guard noisy, and noisy guards
   get switched off.
7. **A release publishes all three legs.** The Z: net site
   (`Z:/_pkg/datalib`) is the supported install path for every language, so a release is
   not done until it carries the Stata net site under `stata/`, the R source
   tarball under `R/`, the Python wheel under `python/`, the shared `VERSION`
   manifest at the root, and a full copy archived under `<version>/`. The older
   `Z:/_statapkg` and `Z:/_pkg/stata` roots have been **removed** (v0.9.19):
   every datalib installation package comes from `Z:/_pkg/datalib` and nowhere
   else. Machines whose `stata.trk` still records a retired root are carried by
   the forwarding rule in `_dl_update.ado`, which is now load-bearing rather than
   a courtesy — do not delete it as a transition leftover. Publish
   the built **wheel**, not the Python source tree: the build backend
   (`hatchling`) is not something an operator will have. Never overwrite a
   published version in place with different contents -- bump instead. A stale
   in-place overwrite on this exact share once downgraded a working install.
8. **One version, in `VERSION`.** Bumping it means bumping `r/DESCRIPTION`,
   `python/pyproject.toml`, `python/src/datalib/__init__.py`,
   `stata/datalib.pkg` and `stata/stata.toc` in the **same** commit — an R test
   and **three** Python tests pin them to `VERSION` and will fail otherwise
   (`test_version.py` covers the two Python files; `test_surface.py`'s
   `test_package_manifest_version_matches_the_repo_version` covers **both** Stata
   manifests). `test_stamps.py` additionally pins `datalib.ado`'s own `*!` stamp,
   because that is what `which datalib` reports.

## Verification before a PR

- Stata: `net install datalib, from("<clone>/stata") replace` into a clean ado dir; run
  the Stata conformance harness (`do stata/tests/run_conformance.do` from the repo root) when it applies.
- R: `devtools::test()` in `r/`. Python: `pytest` in `python/`.
