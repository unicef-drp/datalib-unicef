<#
.SYNOPSIS
    Additive (or mirror) one-way folder sync using robocopy — for depositing or
    mirroring microdata folders to/from the Z: staging area.

.DESCRIPTION
    Wraps robocopy (built into Windows: robust, resumable, multithreaded) to sync a
    selected set of folders one-way from a source root to a destination root.

    Two modes:
      * Additive (default): adds new files and updates changed ones on the
        destination; NEVER deletes. /XO also protects a newer file already on the
        destination from being overwritten by an older source copy.
      * Mirror (-Mirror): makes the destination an EXACT replica of the source,
        which DELETES destination files that no longer exist in the source.
        Destructive — always preview first with -DryRun.

    Use UNC paths (\\server\share\...) rather than mapped drive letters (Z:, S:)
    when this runs from a Windows Scheduled Task: drive letters are per-logon and
    are often absent in the task's session.

.PARAMETER SrcRoot
    Source root (UNC path recommended), e.g. a team's data folder or the Z: share.
.PARAMETER DstRoot
    Destination root (UNC path recommended), e.g. the Z: staging area.
.PARAMETER Folders
    Sub-folder names present under both roots to sync. If omitted, syncs the roots
    themselves.
.PARAMETER Mirror
    Mirror mode (/MIR): exact replica; DELETES extras on the destination.
.PARAMETER DryRun
    List-only (robocopy /L): shows what WOULD change; copies/deletes nothing.
.PARAMETER Estimate
    List-only pre-scan to report how much needs copying + a rough ETA, then proceed.
.PARAMETER EstimateOnly
    Pre-scan + ETA, then exit without copying.
.PARAMETER AssumedMBps
    Throughput guess for the ETA (default 70 MB/s, typical for Azure Files SMB).
.PARAMETER LogDir
    Where to write timestamped logs (default: <DstRoot>\_sync_logs).

.EXAMPLE
    # Deposit a team's survey folders into the Z: staging area (additive, safe)
    .\sync-folders.ps1 -SrcRoot 'D:\my-team-data' `
        -DstRoot '\\<storage-account>.file.core.windows.net\<share>\staging-area\nutrition' `
        -Folders 'ZWE_2019_MICS','KEN_2014_DHS'

.EXAMPLE
    # Preview a mirror before running it for real
    .\sync-folders.ps1 -SrcRoot '\\host\share\src' -DstRoot '\\host\share\dst' -Mirror -DryRun

.NOTES
    robocopy exit codes 0-7 = success (bit flags); >=8 = real error. This script
    exits 0 on success, 1 on any failure — friendly for Scheduled Tasks.
    Do NOT use /COPYALL on Azure Files (NTFS ACL copy is unsupported and errors);
    the default /COPY:DAT (data, attributes, timestamps) is used.
#>
param(
    [Parameter(Mandatory)] [string]   $SrcRoot,
    [Parameter(Mandatory)] [string]   $DstRoot,
    [string[]] $Folders      = @(),
    [switch]   $Mirror,
    [switch]   $DryRun,
    [switch]   $Estimate,
    [switch]   $EstimateOnly,
    [double]   $AssumedMBps  = 70,
    [string]   $LogDir
)
$ErrorActionPreference = 'Stop'

if (-not $LogDir) { $LogDir = Join-Path $DstRoot '_sync_logs' }

# Additive (safe) vs mirror (destructive). /E include subfolders; /XO keep newer on dst.
$modeArgs = if ($Mirror) { @('/MIR') } else { @('/E','/XO') }

function Format-Bytes([double]$b) {
    if     ($b -ge 1TB) { '{0:N2} TB' -f ($b/1TB) }
    elseif ($b -ge 1GB) { '{0:N2} GB' -f ($b/1GB) }
    elseif ($b -ge 1MB) { '{0:N2} MB' -f ($b/1MB) }
    else                { '{0:N0} bytes' -f $b }
}

# Build (src,dst) pairs
if ($Folders.Count -gt 0) {
    $pairs = foreach ($f in $Folders) {
        [pscustomobject]@{ Src = (Join-Path $SrcRoot $f); Dst = (Join-Path $DstRoot $f) }
    }
} else {
    $pairs = ,([pscustomobject]@{ Src = $SrcRoot; Dst = $DstRoot })
}

function Get-CopyEstimate {
    $bytes = [long]0; $files = [long]0
    foreach ($p in $pairs) {
        if (-not (Test-Path $p.Src)) { continue }
        $out = robocopy $p.Src $p.Dst @modeArgs /L /BYTES /NFL /NDL /NJH /R:0 /W:0
        foreach ($line in $out) {
            if ($line -match '^\s*Files\s*:\s+\d') {
                $t = @($line -split '\s+' | Where-Object { $_ -ne '' }); $files += [long]$t[3]
            }
            elseif ($line -match '^\s*Bytes\s*:\s+\d') {
                $t = @($line -split '\s+' | Where-Object { $_ -ne '' }); $bytes += [long]$t[3]
            }
        }
    }
    [pscustomobject]@{ Files = $files; Bytes = $bytes }
}

if ($Estimate -or $EstimateOnly) {
    Write-Host 'Pre-scanning (list-only) to size the job...'
    $est  = Get-CopyEstimate
    $secs = if ($AssumedMBps -gt 0) { $est.Bytes / ($AssumedMBps * 1MB) } else { 0 }
    $eta  = [TimeSpan]::FromSeconds([math]::Max(0, $secs))
    Write-Host ('ESTIMATE: {0} in {1:N0} files  ~{2:hh\:mm\:ss} at {3} MB/s (small-file trees run slower)' -f `
                (Format-Bytes $est.Bytes), $est.Files, $eta, $AssumedMBps)
    if ($EstimateOnly) { return }
}

if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }
$stamp   = Get-Date -Format 'yyyy-MM-dd_HHmmss'
$LogFile = Join-Path $LogDir "sync_$stamp.log"

# /Z restartable; /R:2 /W:5 sane retries; /MT:16 parallel; clean logs; append + echo.
$common = @('/Z','/R:2','/W:5','/MT:16','/NP','/NDL','/TEE', "/LOG+:$LogFile")
if ($DryRun) { $common += '/L' }

$sw = [System.Diagnostics.Stopwatch]::StartNew()
$worst = 0
foreach ($p in $pairs) {
    if (-not (Test-Path $p.Src)) { Write-Warning "SKIP (source missing): $($p.Src)"; continue }
    Write-Host "`n=== $($p.Src)  ->  $($p.Dst) ==="
    robocopy $p.Src $p.Dst @modeArgs @common
    if ($LASTEXITCODE -gt $worst) { $worst = $LASTEXITCODE }
    if ($LASTEXITCODE -ge 8) { Write-Warning "robocopy reported errors (exit $LASTEXITCODE): $($p.Src)" }
}
$sw.Stop()
Write-Host ("`nDone in {0:hh\:mm\:ss}.  Worst robocopy exit code: {1}   Log: {2}" -f $sw.Elapsed, $worst, $LogFile)

# 0-7 = success (bit flags), 8+ = failure. Normalise for Scheduled Tasks.
if ($worst -ge 8) { exit 1 } else { exit 0 }
