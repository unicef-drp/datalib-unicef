# Deposit quickstart — for unit focals

[← datalib README](../README.md) · [Documentation hub](README.md) · [Full governance](GOVERNANCE_microdata_deposit.md)

One page for depositing your unit's **household-survey holdings (the stock)**
into the UNICEF microdata archive's staging area. No programming needed.

## 1. What you are depositing

For each survey, whatever your team has of:

- **Microdata** files (raw and/or harmonised) — **de-identified only**: no
  names, addresses, phone numbers, or below-approved-level geography.
- **Survey documentation**: core survey report, questionnaire, interview
  instructions, interviewer manual.
- **Preparation scripts**, if you have them (Stata/R/Python — any state).

**Do not reorganise anything.** The whole point is to copy your folders
**exactly as they are** so your existing scripts keep working.

## 2. Where it goes

```text
Z:\staging-area\<domain>\<your-team-folder-as-is>\
```

Domains: `health` · `education` · `nutrition` · `child-protection`
(unsure? ask the Data Steward — do not invent a new folder name).

## 3. How to copy it

**Option A — ask.** Send the Data Steward the source path; you run the copy
together (15 minutes, doubles as training).

**Option B — self-service.** From PowerShell, using the repo's sync tool
(additive: it never deletes anything, and it is safe to re-run):

```powershell
.\scripts\ps\sync-folders.ps1 `
    -SrcRoot 'D:\my-team\surveys' `
    -DstRoot '\\<your-Z-UNC>\staging-area\health' `
    -Folders 'ZWE_2019_MICS_work' `
    -Estimate
```

(Use the UNC path, not `Z:`, if you schedule it. Find your UNC with
`mapzdrive, discover` in Stata, or ask the Steward.)

## 4. What happens next

The Core Group walks your deposit through a 7-item
[review-gate checklist](GOVERNANCE_microdata_deposit.md#the-review-gate-checklist)
(inventory, licence, access tier, de-identification, …). Nothing is changed in
your folder; nothing is deleted. Cleared, conformed vintages are later promoted
into the archive's canonical trees by the Data Steward.

Your unit keeps ownership: access to your deposit beyond your unit is granted
only by **your Unit Chief**, per survey.

## 5. Questions

| About | Ask |
|---|---|
| Where things go, the copy itself, tooling | Data Steward |
| Access to another unit's deposit | That unit's chief |
| Process, priorities, disputes | Process Lead |

---

[← datalib README](../README.md) · [Documentation hub](README.md) · [Full governance](GOVERNANCE_microdata_deposit.md)
