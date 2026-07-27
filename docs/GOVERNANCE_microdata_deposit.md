# The UNICEF Microdata Archive — Governance Proposal

[← datalib README](../README.md) · [Documentation hub](README.md) · [Deposit quickstart](DEPOSIT_QUICKSTART.md)

*Draft v0.3 · 2026-07-11 · for discussion at the DB Managers group*

## Contents

- [Purpose & scope](#purpose--scope)
- [Archive, catalogue, tool — three layers](#archive-catalogue-tool--three-layers)
- [Principles](#principles)
- [Stock vs flow — the differentiated approach](#stock-vs-flow--the-differentiated-approach)
- [Why deposit as-is (a phased payoff)](#why-deposit-as-is-a-phased-payoff)
- [Thematic domains (registry)](#thematic-domains-registry)
- [What teams deposit](#what-teams-deposit)
- [The review gate (checklist)](#the-review-gate-checklist)
- [Access, licensing & de-identification](#access-licensing--de-identification)
- [Roles](#roles)
- [Decision rights (subsidiarity)](#decision-rights-subsidiarity)
- [Getting started — the first two weeks](#getting-started--the-first-two-weeks)
- [Open decisions for the Standards Board](#open-decisions-for-the-standards-board)
- [Tooling & migration](#tooling--migration)
- [Glossary](#glossary)
- [Current appointments](#current-appointments)

## Purpose & scope

Today, UNICEF's survey **microdata is managed in silos** — each team and
project holds its own copies, its own folder conventions, its own preparation
scripts. This proposal takes a **gradual approach towards a cohesive,
efficient microdata archive**: every unit can deposit the household-survey
microdata and documentation it holds into a shared, IHSN-aligned structure —
**without redesigning what already works** (IHSN convention + `datalib`
tooling, in use since 2024) and **without breaking any unit's existing code
pathways**.

**Scope — start narrow, evolve deliberately:**

1. **Now: household surveys used for global child monitoring** (MICS, DHS,
   LSMS and kin — the assets the DB Managers teams hold today, including the
   **MICS Harmonized Database** vintages on Teams).
2. **Next: other survey types** as the process proves itself.
3. **Later: anonymized public-use microdata** — the openly shareable face of
   the archive (a natural extension of the access-tier model below).

Governance follows proven practice; it does not gate the first deposits.

## Archive, catalogue, tool — three layers

Three related things are easy to conflate. This work is about the **first**;
the other two are complements that grow out of it:

| Layer | What it is | What it is NOT | Where UNICEF stands |
|---|---|---|---|
| **Microdata archive** | The governed store of the **data files themselves**: organized, versioned, preserved, access-controlled — the vault and its shelving convention | Not a website, not a metadata index | **This initiative.** The `Z:/datalib*` trees + the staging area + the deposit process below |
| **Microdata catalogue** | The **metadata & discovery layer**: which surveys exist, coverage, vintages, terms of use, citations. Describes holdings; holds no data. (Reference model: IHSN/NADA + DDI — the lineage this archive descends from) | Not the files; a catalogue entry can even describe data the archive does not hold | Only a seed: the tool auto-generates **inventories** (folder → table). A true catalogue is a Phase 2+ product, once the archive is worth describing |
| **`datalib` (the tool)** | **Software** (same functions in Stata, R, Python) that encodes the shelving convention as executable code: navigate, resolve, load, validate, inventory | Not the archive itself — a tool over it | Shipped (v0.9.3). It *serves* the archive and *feeds* the future catalogue |

**Complementarity in one line:** an archive without a catalogue is unfindable;
a catalogue without an archive points at silos; both without a tool are manual
drudgery. The gradual path: **archive first** (the deposits below), the tool's
inventories as the proto-catalogue, a real catalogue when the holdings justify
it.

## Principles

1. **Build on what exists.** IHSN convention + `datalib` tooling + the existing
   `Z:/datalib*` trees are the substrate. We adopt; we do not reinvent.
   (DW-Production's `060.DW-MASTER` remains the separate canonical home for
   **aggregate/indicator** outputs — it is out of scope for microdata.)
2. **Separate stock from flow.** The backlog of existing holdings never blocks
   new deposits, and there is no big-bang reorganisation of what teams hold.
3. **Deposit-to-learn.** The near-term goal is visibility — surfacing each
   unit's microdata and variable transformations so we can converge on a
   product that serves every team.
4. **Additive & non-breaking.** Deposits land in a staging area and pass a
   review gate before promotion. No change breaks an existing pathway.
5. **Least privilege, licence-respecting.** Depositing does not re-license:
   producer terms (MICS is country-owned; DHS access is per-project) travel
   with the files, access defaults to the depositing unit, and wider access is
   granted per survey — never assumed.
6. **One accountable owner, delegated coordination.** A single executive is
   accountable; day-to-day guidance is delegated to a nominated Unit Chief.

## Stock vs flow — the differentiated approach

The centrepiece of the model: **existing holdings and new work are treated
differently, on purpose.**

| | **STOCK** — what teams already hold | **FLOW** — new / ongoing work |
|---|---|---|
| **What** | Existing household-survey microdata + documentation in each team's current storage (incl. the MICS Harmonized Database vintages) | Data and documentation produced or acquired from now on |
| **Structure** | **Deposited exactly as-is** — the team's folder structure is preserved unchanged, so the team's existing scripts keep running | Follows the `datalib` convention: `CCC/CCC_YYYY_SSSS/<vintage>/{Data,Doc,Programs}` with the [file-naming rules](../README.md#file-naming-inside-the-folders) |
| **Where** | `Z:/staging-area/<domain>/<team-folder-as-is>/` | Staging first, then the canonical domain tree after the gate |
| **How it moves** | **Assisted / scripted move**: the unit's focal runs the [ps toolbox](../scripts/ps/README.md) sync (or asks the Data Steward to run it) — logged, resumable, additive-only | Deposited by the unit as work completes |
| **Conformance** | **Never a precondition.** Stock is progressively conformed through the gate, survey by survey, as capacity allows | Already conforms |
| **Rule of thumb** | *Copy it as it is; don't touch it* | *Name it right from day one* |

## Why deposit as-is (a phased payoff)

Preserving the structure on deposit is what unlocks each phase — forcing
reorganisation up front would break scripts and lose provenance.

| Phase | What happens | Entry criterion | Exit criterion |
|---|---|---|---|
| **1 — Preserve & make portable** | Teams' stock lands in staging unchanged; their scripts become runnable by anyone from the shared location | Staging folders exist; quickstart published | Every participating unit has ≥ 1 survey deposited; one script re-run by a non-author |
| **2 — Compare inputs** | For same-named surveys (same country/year), compare the input microdata and where post-processing diverges | ≥ 2 units have deposited overlapping surveys | A written comparison note for ≥ 1 shared survey |
| **3 — Reverse-engineer** | Deposited scripts explain *what* each team did and *why* — methodological choices vs accidental drift | Phase 2 note identifies divergences | Documented transformation inventory per shared survey |
| **4 — Consolidate** | One consolidated file per survey reconciling inputs + transformations | Phase 3 inventory agreed by the owning units | Consolidated vintage promoted to the canonical tree |

## Thematic domains (registry)

Staging is organised by **thematic domain** — the unit-facing grouping of the
microdata holdings, mapping one-to-one onto the existing `Z:` trees. (In
earlier discussions these were called "families of indicators"; the archive
holds *microdata*, so the grouping is by domain, not by indicator.)

| Domain (slug) | Existing canonical tree | Collection code |
|---|---|---|
| `health` | `Z:/datalib-hlt` | HLT |
| `education` | `Z:/datalib-edu` | EDU¹ |
| `nutrition` | `Z:/datalib-nut` | NUT¹ |
| `child-protection` | `Z:/datalib-chp` | CHP¹ |
| *(cross-cutting / unassigned)* | `Z:/datalib` | — |

Staging path: `Z:/staging-area/<domain-slug>/<team-folder-as-is>/`.
New domains are ratified by the Standards Board — do not mint folder names
ad hoc (avoid `health` vs `hiv` vs `immunization` fragmentation).

¹ Only **HLT** (and IPUMS) are registered in the merge registry
([config/collections.yml](../config/collections.yml)) today; EDU/NUT/CHP become
first-class as their module lists and merge keys are verified during Phase 2–3.
**Domain** (organisational grouping of holdings) and **collection**
(harmonization code in the folder grammar) are deliberately aligned but not
identical — see [Glossary](#glossary).

## What teams deposit

For each household survey, whatever the team has of:

- **Microdata** — the data files (raw and/or harmonised), **de-identified only**
  (see [Access, licensing & de-identification](#access-licensing--de-identification)).
- **Survey documentation** — the **core survey report**, the **questionnaire**,
  **interview instructions**, and the **interviewer manual**.
- **Preparation scripts** *(where available)* — any microdata-preparation code.

## The review gate (checklist)

The Core Group **decides** gate outcomes; the Data Steward **operates** the
checks and executes promotion. Per deposit:

1. ☐ **Inventory** — folder listing captured; deposit logged (who, what, when, source location).
2. ☐ **Naming** *(flow only)* — conforms to the `CCC_YYYY_SSSS_vNN_M[_vMM_A_HHHH]` grammar.
3. ☐ **Reproducibility** *(where scripts provided)* — a non-author can re-run the preparation script from staging.
4. ☐ **No breakage** — the deposit changed nothing outside its own staging folder.
5. ☐ **Licence recorded** — producer terms noted per survey (MICS country-owned; DHS project terms; IPUMS conditions).
6. ☐ **Access tier assigned** — Open-internal / Licensed / Restricted (see below).
7. ☐ **De-identification confirmed** — no direct identifiers; no below-approved-level geography.

Pass → the Data Steward **promotes** conformed vintages into the domain's
canonical tree (`Z:/datalib-<domain>` or `Z:/datalib`), as
`CCC_YYYY_SSSS_vNN_M` masters / `..._A_<HHHH>` adaptations. **Never** into
`060.DW-MASTER` (aggregates only, via DW-Production's own process).

## Access, licensing & de-identification

Pragmatic minimum, adopted from the ECATSD lineage this model descends from
(its gate assigned identifiers and access tiers — see
docs/pdf/README.md):

- **Least privilege by default.** A staging domain folder is readable by the
  depositing unit + the Data Steward + the Core Group. Cross-unit read access
  is granted per survey by the **depositing Unit Chief** (Entra group changes
  requested by the Data Steward, executed by ICT).
- **Three tiers**, set at the gate per survey: **Open-internal** (any CSO/D&A
  team member), **Licensed** (producer terms restrict use — access on request +
  Unit Chief approval), **Restricted** (sensitive — named-user access only).
  When the archive later takes in **anonymized public-use files**, those form a
  fourth, openly shareable tier.
- **Deposit does not re-license.** Producer terms travel with the files; no
  re-sharing beyond the tier. When in doubt, deposit the *documentation* and a
  file inventory first and resolve the licence question at the gate.
- **De-identified microdata only.** Direct identifiers (names, addresses,
  phone numbers) and disallowed geography must not enter staging; this is gate
  check 7, and the depositor's responsibility at copy time.
- **Staging is a waypoint, not an archive.** Staging copies are reviewed
  within one quarter of deposit; after promotion (or a no-go decision) the
  staging copy is retired by agreement with the depositing unit. Deposit logs
  are kept by the Data Steward.

## Roles

| Role | Who | Accountable for |
|---|---|---|
| **Owner (Accountable)** | **Chief Statistician** | Ratifies the standard & resourcing; final arbiter. **Delegates process guidance** (see below). |
| **Process Lead (Delegated)** | **A Unit Chief nominated by the Chief Statistician** | Guides the process day-to-day on the Chief Statistician's authority: chairs the Standards Board, sets cadence, unblocks, escalates only what needs the CS. |
| **Standards Board** | All Unit Chiefs | Ratify the standard, the domain registry, promotion-to-production, and cross-unit priorities. |
| **Microdata Core Group** | One deposit focal per unit + Data Steward (chair) | Draft standards; **decide** review-gate outcomes; converge variable transformations. |
| **Data Steward** (+ deputy) | Named maintainers | Maintain the reference implementation (`datalib`); **operate** the gate checks and the assisted move; execute promotion; keep deposit logs. |
| **Unit Chiefs** | Per unit | Own their unit's deposits, adherence and access decisions; name their focal. |

### Delegation (explicit)

The **Chief Statistician remains accountable** but **delegates the authority to
guide this process to a nominated Unit Chief** (see
[Current appointments](#current-appointments)). The Process Lead acts with the
Chief Statistician's mandate — convening, prioritising, and deciding process
matters. Only **standard ratification, resourcing, and unresolved cross-unit
conflicts** return to the Chief Statistician. The delegation is **revocable and
reassignable** at any time.

## Decision rights (subsidiarity)

- **Within a unit** (own transformations, own cadence, access to own deposits) → **Unit Chief**.
- **Cross-unit standard** (naming, domain registry, shared columns, catalogue scope) → **Core Group proposes → Standards Board ratifies** (chaired by the Process Lead).
- **Access to another unit's Licensed/Restricted deposit** → depositing **Unit Chief**; disputes → Process Lead.
- **Escalation / deadlock / resourcing** → **Process Lead → Chief Statistician**.

## Getting started — the first two weeks

Deliberately small; nothing here waits on the open decisions below.

**Week 1**

1. Chief Statistician confirms the **Process Lead** delegation and names the **Data Steward + deputy** (appointments recorded below).
2. Data Steward creates the four domain folders under `Z:/staging-area/` and publishes the [deposit quickstart](DEPOSIT_QUICKSTART.md).
3. Each Unit Chief names **one deposit focal** (a person who knows where the unit's survey folders live).

**Week 2**

4. **Each unit deposits ONE survey's stock as-is** — focal + Data Steward run the assisted move together (this doubles as tool training).
5. The Core Group holds its **first gate session** on one deposit, walking the 7-item checklist end-to-end — the checklist gets fixed by use, not by review.
6. The Standards Board receives the [open decisions](#open-decisions-for-the-standards-board) with a recommendation from the Process Lead.

Success in two weeks = four domain folders, ≥ 3 units with one survey each in
staging, one gate session held. Everything else is Phase 2+.

## Open decisions for the Standards Board

1. **Canonical topology** — keep the per-domain roots (`Z:/datalib-hlt`, …) or
   consolidate into one root with collections inside (the contract's
   single-root model)? Decide **before first promotion**; staging is unaffected
   either way. (See the [deployment topology note](../config/grammar.md).)
2. **Domain registry confirmation** — ratify the starter table above; process
   for proposing new domains.
3. **Access-tier defaults** — confirm the three tiers and the request path.
4. **MICS Harmonized Database** — deposit route for the existing Teams-hosted
   vintages (v1.1–v1.3): reference-in-place vs copy into staging.

## Tooling & migration

Operator onboarding is self-service and needs no code edits:

- **`getuserconfig` / `datalib_config`** — reads per-operator paths from `~/.config/user_config.yml` (incl. the `datalib:` root key).
- **`mapzdrive` / `datalib_map_drive`** — maps the Z: staging/mirror from that same config.
- **`datalib` + the `datalib_*` API** — the archive's access tool: navigate, resolve, load, validate, inventory — same functions in Stata, R and Python.
- **[`scripts/ps`](../scripts/ps/README.md)** — the assisted-move sync (robocopy: additive, resumable, logged).

These utilities are **staged in `datalib` today** and will **migrate to the CSO
Toolkit** (with the `dw_*` prefix) as their shared, long-term home.

## Glossary

| Term | Meaning here |
|---|---|
| **Microdata archive** | The governed store of the data files themselves — this initiative; the `Z:/datalib*` trees + staging + this process |
| **Microdata catalogue** | The metadata/discovery layer over the holdings (IHSN/NADA + DDI model); a Phase 2+ product seeded by the tool's inventories |
| **`datalib` (tool)** | The Stata/R/Python software encoding the archive's convention: navigate, resolve, load, validate, inventory |
| **Stock** | Household-survey holdings that exist today in a team's storage |
| **Flow** | Data/documentation produced or acquired from now on |
| **Staging area** | `Z:/staging-area/<domain>/` — the as-is landing zone; a waypoint, not the archive |
| **Canonical (microdata)** | The IHSN-convention trees `Z:/datalib` and `Z:/datalib-<domain>` — where gated, conformed vintages live |
| **Canonical (aggregates)** | DW-Production's `060.DW-MASTER` Teams deposit — indicator outputs only; out of scope here |
| **Domain** | Unit-facing thematic grouping of the microdata holdings (health, education, nutrition, child protection) |
| **Collection** | The harmonization code inside folder names (`..._A_HLT`) and the merge registry; aligned with, but narrower than, a domain |
| **Gate** | The 7-item review checklist between staging and canonical |

## Current appointments

| Role | Incumbent | Since |
|---|---|---|
| Process Lead | *Unit Chief nominated by the Chief Statistician — Yves Jaques | Confirmed |
| Data Steward | *to be named* | — |
| Deputy Data Steward | *to be named* | — |

---

*Governance follows practice — nothing here blocks the first deposits.*

---

[← datalib README](../README.md) · [Documentation hub](README.md) · [Deposit quickstart](DEPOSIT_QUICKSTART.md)
