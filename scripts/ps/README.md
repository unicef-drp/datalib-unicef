# PowerShell utilities

[← datalib README](../../README.md) · [Documentation hub](../../docs/README.md)

Generic Windows PowerShell helpers for the datalib workflow. Their main use is the
**assisted / scripted move** in the [microdata-deposit governance model](../../docs/GOVERNANCE_microdata_deposit.md):
teams schedule a sync that copies their microdata folders into the **Z: staging area**,
**preserving the folder structure** so existing scripts remain runnable as-is.

## Scripts

| Script | What it does |
|---|---|
| [`sync-folders.ps1`](sync-folders.ps1) | Additive (or mirror) one-way folder sync via `robocopy`. UNC-aware, resumable, multithreaded, with a list-only estimator and task-friendly exit codes. |
| [`schedule-sync.ps1`](schedule-sync.ps1) | Register a weekly Windows Scheduled Task that runs a sync script (defaults to Sunday, only when logged on). |

## Quick start

Deposit a team's survey folders into the Z: staging area (additive — never deletes):

```powershell
.\sync-folders.ps1 `
    -SrcRoot 'D:\my-team-data' `
    -DstRoot '\\<storage-account>.file.core.windows.net\<share>\staging-area\<domain>' `
    -Folders 'ZWE_2019_MICS','KEN_2014_DHS' `
    -Estimate
```

Then schedule it weekly by pointing the scheduler at a small wrapper `.ps1` that calls
`sync-folders.ps1` with your arguments:

```powershell
.\schedule-sync.ps1 -TaskName 'Deposit to Z (weekly)' `
    -ScriptPath 'C:\Users\me\Scripts\my-deposit.ps1' -DaysOfWeek Sunday -At 9:00AM
```

## The one decision that matters: additive vs mirror

- **Additive** (default) — adds new files and updates changed ones on the destination;
  **never deletes**. `/XO` also stops an older source file from overwriting a newer one
  already on the destination. Use this unless you specifically want an exact replica.
- **Mirror** (`-Mirror`, robocopy `/MIR`) — makes the destination an **exact copy**,
  which **deletes** destination files no longer present in the source. Powerful but
  destructive — always run once with `-DryRun` first to preview.

## Why UNC paths, not drive letters

Mapped drive letters (`Z:`, `S:`) are **per-logon-session**. A Scheduled Task often runs
in a session where those mappings don't exist, so a script using `Z:\...` fails with
"drive not found." Pass **UNC paths** (`\\server\share\...`) to `sync-folders.ps1` —
read your Z: drive's UNC with `mapzdrive, discover` (Stata). Do not hardcode real
share addresses in committed files (see the note in `config/user_config.yml`).

## robocopy flags used

| Flag | Purpose |
|---|---|
| `/E` | Copy subfolders, including empty ones (additive mode) |
| `/XO` | Skip files where the destination is already newer (additive mode) |
| `/MIR` | Mirror — exact replica, **deletes** extras on the destination |
| `/Z` | Restartable mode — survives network drops (good for mapped/UNC shares) |
| `/R:2 /W:5` | Retry twice, wait 5s (robocopy's default is 1M × 30s — a hang trap) |
| `/MT:16` | 16 parallel threads — much faster for many small files |
| `/L` | List-only (dry run / estimator) — changes nothing |
| `/NP /NDL /TEE /LOG+` | Clean logs: no per-file %, no dir list, echo to console, append to file |

**Exit codes:** robocopy `0–7` = success (bit flags), `>=8` = real error. `sync-folders.ps1`
normalises this to `0` on success / `1` on any failure, so Scheduled Tasks report correctly.

**Azure Files caveat:** do **not** use `/COPYALL` against the Z: Azure Files share — NTFS
ACL copy is unsupported there and errors. The default `/COPY:DAT` (data, attributes,
timestamps) is used.

> One-way only. If you ever need true **two-way** sync (changes on both ends), robocopy is
> the wrong tool — use a dedicated bidirectional sync utility instead.

---

[← datalib README](../../README.md) · [Documentation hub](../../docs/README.md)
