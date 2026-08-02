<#
.SYNOPSIS
    Local CI for datalib. One command, one pasteable verdict.

.DESCRIPTION
    .github/workflows/conformance.yml covers the R and Python legs on Linux and Windows,
    Actions was billing-blocked org-wide from v0.9.4 until the quota reset on
    2026-08-01, and every job failed after ~2 seconds with zero steps -- the signature of
    a job that never started. CI runs again now, and its first green run immediately found
    a test that produced false failures under the default shallow checkout, which is a
    fair argument for not relying on local runs alone.

    This script is still worth running BEFORE pushing: it is faster than a round trip
    through Actions, it checks the version manifests that no CI job covers, and it is the
    only gate that exists for the Stata leg.

    What it checks, in the order that fails fastest:

      1. version manifests   every file that carries the version must agree with VERSION,
                             and no file may name a stale versioned artefact
      2. Python              pytest over python/tests
      3. R                   testthat over r/tests/testthat
      4. R CMD check         --as-cran, only with -Full (it is slow)
      5. stata record        the recorded result of the last hand-run must be CURRENT

    No count of version-carrying files is given here on purpose. Every time this said
    "nine" it went stale, and check 1 now discovers them rather than trusting a list.

    The STATA leg is still not run here, and that is stated rather than silently omitted.
    Stata has no CI licence, and batch-mode Stata on Windows is not trustworthy in a
    script: the executable can hang after finishing, writes its log to the working
    directory rather than where asked, and its exit code does not reflect whether the
    do-file failed. So it stays a manual gate:

        do stata/tests/run_conformance.do        (expect NNN/NNN passed, 0 skipped)

    What check 5 adds is that the RESULT is recorded, in tests/stata-conformance.txt, and
    that a record behind VERSION fails this script. A manual gate whose result nobody
    writes down cannot be told apart from a gate never run -- 0.9.33 shipped that way.

    Exit code is 0 only when every leg that ran passed.

.PARAMETER Full
    Also run R CMD check --as-cran. Adds a couple of minutes.

.PARAMETER SkipR
    Skip the R leg (useful when only Python changed).

.PARAMETER SkipPython
    Skip the Python leg.

.EXAMPLE
    pwsh scripts/verify.ps1
    pwsh scripts/verify.ps1 -Full
#>
[CmdletBinding()]
param(
    [switch]$Full,
    [switch]$SkipR,
    [switch]$SkipPython
)

$ErrorActionPreference = 'Continue'
$repo = Split-Path -Parent $PSScriptRoot
Push-Location $repo

$results = [ordered]@{}
$detail  = [ordered]@{}

function Set-Result([string]$leg, [bool]$ok, [string]$note) {
    $results[$leg] = $ok
    $detail[$leg]  = $note
}

Write-Host ""
Write-Host "datalib local verification" -ForegroundColor Cyan
Write-Host ("repo: {0}" -f $repo)
Write-Host ("=" * 72)

# ---------------------------------------------------------------------------
# 1. Version manifests
#
# Several files carry the version, each pinned by a DIFFERENT test, so a partial bump passes
# some suites and fails others -- which is exactly how 0.9.21 shipped with pyproject.toml left
# behind. Checking them here fails in a second instead of a minute.
#
# No count is stated on purpose. Every time this comment named one it went stale, and a
# confident wrong number is worse than none: the second half of this check DISCOVERS stale
# references rather than trusting the list below to be complete.
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "1. version manifests" -ForegroundColor Yellow
$version = (Get-Content -Raw "$repo\VERSION").Trim()
Write-Host ("   VERSION = {0}" -f $version)

$checks = @(
    @{ File = 'r\DESCRIPTION';                    Pattern = "^Version:\s*$([regex]::Escape($version))\s*$" }
    @{ File = 'python\pyproject.toml';            Pattern = "^version\s*=\s*`"$([regex]::Escape($version))`"" }
    @{ File = 'python\src\datalib\__init__.py';   Pattern = "^__version__\s*=\s*`"$([regex]::Escape($version))`"" }
    @{ File = 'stata\datalib.pkg';                Pattern = "^d Version\s+$([regex]::Escape($version))\s*$" }
    @{ File = 'stata\stata.toc';                  Pattern = "^d Version\s+$([regex]::Escape($version))\s*\|" }
    # The front door twice: -which datalib- reports the *! stamp, and the RUNNING
    # literal is what tells an operator whether their SESSION is current.
    @{ File = 'stata\src\d\datalib.ado';          Pattern = "^\*!\s*v$([regex]::Escape($version))\s*$" }
    @{ File = 'stata\src\d\datalib.ado';          Pattern = "^\s*local RUNNING `"$([regex]::Escape($version))`"" }
)

$badVersion = @()
foreach ($c in $checks) {
    $path = Join-Path $repo $c.File
    if (-not (Test-Path $path)) { $badVersion += "$($c.File) missing"; continue }
    $hit = Select-String -Path $path -Pattern $c.Pattern -List -ErrorAction SilentlyContinue
    if ($null -eq $hit) { $badVersion += "$($c.File) does not carry $version" }
}

# The list above is PRESENCE-based: it asks whether each named file carries the current
# version. It cannot see a file carrying a STALE one, and that is the failure that keeps
# happening -- the enumeration has been short three times now (0.9.21 shipped without
# pyproject.toml; the prose said "seven" when it was nine; and 0.9.32 reported "all
# manifests agree" while r/R/datalib-package.R, r/man/datalib-package.Rd and r/README.md
# still named older tarballs in copy-pasteable install commands).
#
# So DISCOVER instead of enumerate: every reference to a VERSIONED ARTEFACT -- a
# datalib_<v>.tar.gz or a unicef_datalib-<v>-py3 wheel -- must name the current version.
#
# Deliberately BROAD: it matches such a filename wherever it appears, not only inside
# something shaped like an install command. A false positive costs one visible line in a
# local run; a miss ships documentation pointing at a file that may not exist, which is the
# failure that has now recurred three times. Narrowing would trade a cheap failure for an
# expensive one.
#
# The cost of breadth is that legitimate historical quotations match too, so those are
# exempted EXPLICITLY and with the reason. A verbatim error transcript must not be bumped,
# or it stops being a record of what actually happened.
#
# Paths are normalised to forward slashes. $rel derives from FullName, which is
# separator-dependent, so a hard-coded 'r\README.md' would silently stop matching under
# pwsh on Linux or macOS -- and an exemption that stops matching is a false failure on a
# platform nobody here tests. This script ships publicly, so that platform is a stranger's.
$exempt = @(
    @{ File = 'r/README.md'; Version = '0.9.27'
       Why  = 'verbatim RStudio error transcript from the 0.9.27 diagnosis' }
)
$refRe = '(?:datalib_|unicef_datalib-)(\d+\.\d+\.\d+)'
Get-ChildItem $repo -Recurse -File -Include *.md,*.R,*.Rd,*.py,*.ado,*.sthlp,*.do,*.toml,*.yml |
    Where-Object { $_.FullName -notmatch '[\\/]\.git[\\/]|CHANGELOG\.md$|\.Rcheck[\\/]|__pycache__|[\\/]dist[\\/]' } |
    ForEach-Object {
        $rel = $_.FullName.Substring($repo.Length + 1) -replace '\\', '/'
        foreach ($m in [regex]::Matches([IO.File]::ReadAllText($_.FullName), $refRe)) {
            $found = $m.Groups[1].Value
            if ($found -eq $version) { continue }
            if ($exempt | Where-Object { $_.File -eq $rel -and $_.Version -eq $found }) { continue }
            $badVersion += "$rel names datalib $found (current is $version)"
        }
    }
$badVersion = $badVersion | Select-Object -Unique
if ($badVersion.Count -eq 0) {
    Write-Host "   all manifests agree" -ForegroundColor Green
    Set-Result 'versions' $true "all agree on $version"
} else {
    foreach ($b in $badVersion) { Write-Host ("   MISMATCH {0}" -f $b) -ForegroundColor Red }
    Set-Result 'versions' $false ("{0} mismatch(es)" -f $badVersion.Count)
}

# ---------------------------------------------------------------------------
# 2. Python
# ---------------------------------------------------------------------------
if ($SkipPython) {
    Write-Host ""
    Write-Host "2. python  SKIPPED (-SkipPython)" -ForegroundColor DarkGray
    Set-Result 'python' $true 'skipped'
} else {
    Write-Host ""
    Write-Host "2. python" -ForegroundColor Yellow
    $pyOut = & python -m pytest python -q 2>&1 | Out-String
    # Parse the counts rather than trusting the exit code alone: a summary line is
    # evidence, an exit code is a claim.
    $m = [regex]::Match($pyOut, '(?m)^(?<passed>\d+) passed(?:, (?<xfail>\d+) xfailed)?(?:, (?<skipped>\d+) skipped)?')
    $fail = [regex]::Match($pyOut, '(?m)^(?<n>\d+) failed')
    if ($fail.Success) {
        Write-Host ("   {0} FAILED" -f $fail.Groups['n'].Value) -ForegroundColor Red
        $pyOut -split "`n" | Select-String -Pattern '^FAILED' | ForEach-Object { Write-Host ("     {0}" -f $_) }
        Set-Result 'python' $false ("{0} failed" -f $fail.Groups['n'].Value)
    } elseif ($m.Success) {
        $note = "{0} passed" -f $m.Groups['passed'].Value
        if ($m.Groups['xfail'].Success) { $note += ", $($m.Groups['xfail'].Value) xfailed" }
        Write-Host ("   {0}" -f $note) -ForegroundColor Green
        Set-Result 'python' $true $note
    } else {
        Write-Host "   could not parse pytest output" -ForegroundColor Red
        Write-Host ($pyOut -split "`n" | Select-Object -Last 8 | Out-String)
        Set-Result 'python' $false 'unparseable output'
    }
}

# ---------------------------------------------------------------------------
# 3. R
# ---------------------------------------------------------------------------
if ($SkipR) {
    Write-Host ""
    Write-Host "3. R  SKIPPED (-SkipR)" -ForegroundColor DarkGray
    Set-Result 'r' $true 'skipped'
} else {
    Write-Host ""
    Write-Host "3. R" -ForegroundColor Yellow
    # test_local() from inside r/, so the package root and the repo-root corpus both
    # resolve the way they do for a developer.
    # Write the R to a FILE rather than passing it with -e. A multi-line expression
    # handed to `Rscript -e` through PowerShell loses its newlines and comes back as
    # "Error: unexpected end of input"; a file has no quoting or line-joining to get
    # wrong.
    #
    # getwd(), not ".": test_local(path = ".") dies inside path.expand() with
    # "restarting interrupted promise evaluation".
    # And write it WITHOUT a byte-order mark. Windows PowerShell 5.1's
    # `Set-Content -Encoding utf8` emits a BOM, which R reports as
    # `Error: unexpected input in "<U+FEFF>"`. This is the third time the same BOM has
    # bitten in this repo -- it also corrupted the published VERSION manifest on the
    # share -- so the encoding is constructed explicitly rather than named.
    # The package path is EMBEDDED, not inherited from the working directory.
    # Push-Location changes PowerShell's own location but NOT the process working
    # directory a child inherits, so Rscript started in the repo root and pkgload
    # aborted with `pkgload_no_desc` -- no DESCRIPTION there. Passing the path removes
    # the dependency entirely.
    $rPkg = ((Join-Path $repo 'r') -replace '\\', '/')
    $rScript = Join-Path $env:TEMP ("datalib_rtest_" + $PID + ".R")
    $rCode = @"
res <- testthat::test_local(path = "$rPkg", reporter = "summary",
                            stop_on_failure = FALSE)
df <- as.data.frame(res)
cat(sprintf("TOTALS pass=%d fail=%d error=%d skip=%d\n",
            sum(df`$passed), sum(df`$failed), sum(df`$error), sum(df`$skipped)))
"@
    [System.IO.File]::WriteAllText($rScript, $rCode,
                                   (New-Object System.Text.UTF8Encoding $false))
    $rOut = & Rscript $rScript 2>&1 | Out-String
    Remove-Item $rScript -ErrorAction SilentlyContinue
    $t = [regex]::Match($rOut, 'TOTALS pass=(?<p>\d+) fail=(?<f>\d+) error=(?<e>\d+) skip=(?<s>\d+)')
    if ($t.Success) {
        $f = [int]$t.Groups['f'].Value; $e = [int]$t.Groups['e'].Value
        $note = "{0} passed, {1} failed, {2} errors, {3} skipped" -f `
                $t.Groups['p'].Value, $f, $e, $t.Groups['s'].Value
        if ($f -eq 0 -and $e -eq 0) {
            Write-Host ("   {0}" -f $note) -ForegroundColor Green
            Set-Result 'r' $true $note
        } else {
            Write-Host ("   {0}" -f $note) -ForegroundColor Red
            Set-Result 'r' $false $note
        }
    } else {
        Write-Host "   could not parse testthat output" -ForegroundColor Red
        Write-Host ($rOut -split "`n" | Select-Object -Last 10 | Out-String)
        Set-Result 'r' $false 'unparseable output'
    }
}

# ---------------------------------------------------------------------------
# 4. R CMD check --as-cran  (opt-in)
# ---------------------------------------------------------------------------
if ($Full -and -not $SkipR) {
    Write-Host ""
    Write-Host "4. R CMD check --as-cran" -ForegroundColor Yellow
    # R.exe, not R. In PowerShell `R` resolves to the built-in ALIAS for
    # Invoke-History, so `& R CMD build` silently runs the wrong command -- it does not
    # even error in a way that looks like a missing toolchain. Resolve the real
    # executable and fail loudly if it is not on PATH.
    $rExe = (Get-Command 'R.exe' -ErrorAction SilentlyContinue)
    if ($null -eq $rExe) {
        Write-Host "   R.exe is not on PATH -- cannot run R CMD check" -ForegroundColor Red
        Set-Result 'rcheck' $false 'R.exe not on PATH'
        $rExe = $null
    }
    $tmp = Join-Path $env:TEMP ("datalib_check_" + [System.Guid]::NewGuid().ToString('N').Substring(0, 8))
    New-Item -ItemType Directory -Force -Path $tmp | Out-Null
    $tarball = $null
    if ($null -ne $rExe) {
        # R CMD build writes the tarball to its working directory, and getting that
        # directory set from PowerShell took four attempts, so the reasoning is recorded:
        #
        #   Push-Location $tmp                     -> landed in C:\GitHub
        #   [IO.Directory]::SetCurrentDirectory    -> landed in C:\GitHub
        #   Start-Process -WorkingDirectory $tmp   -> landed in C:\GitHub
        #   cmd /c cd /d $tmp && R CMD build       -> lands in $tmp
        #
        # R itself is not at fault: launched from bash after `cd`, getwd() reports the
        # directory correctly. `R CMD build` on Windows re-execs, and the grandchild does
        # not inherit what PowerShell sets -- so hand the whole thing to cmd, whose
        # `cd /d` applies to everything after it in the same instance.
        #
        # Redirection also goes through cmd rather than PowerShell's `2>&1`: in 5.1 that
        # wraps every stderr line in an ErrorRecord and reports failure on exit 0, and
        # R CMD build writes its entire progress log to stderr -- which is how a
        # SUCCESSFUL build first appeared as a NativeCommandError.
        $bLog = Join-Path $tmp 'build.log'
        $cmdLine = 'cd /d "{0}" && "{1}" CMD build "{2}" > "{3}" 2>&1' -f `
                   $tmp, $rExe.Source, (Join-Path $repo 'r'), $bLog
        & cmd.exe /c $cmdLine | Out-Null
        $buildExit = $LASTEXITCODE
        # Even through cmd it still lands elsewhere on this machine, so after the build
        # LOOK for it rather than assert where it should be. The first attempt at this
        # searched $repo and its parent and missed: the tarball appears in the
        # grandparent (C:\GitHub, two levels above the package), which is the shell's
        # own working directory. Off by one level.
        $wanted = "datalib_$version.tar.gz"
        $hunt = @(
            $tmp,
            $repo,
            (Split-Path -Parent $repo),
            (Split-Path -Parent (Split-Path -Parent $repo)),
            (Join-Path $repo 'r'),
            $HOME
        ) | Where-Object { $_ -and (Test-Path $_) } | Select-Object -Unique

        foreach ($d in $hunt) {
            $hit = Join-Path $d $wanted
            if (Test-Path $hit) {
                if ($d -ne $tmp) { Move-Item $hit (Join-Path $tmp $wanted) -Force }
                break
            }
        }
        $cand = Join-Path $tmp $wanted
        if (Test-Path $cand) {
            $tarball = Get-Item $cand
            Write-Host ("   built {0}" -f $wanted)
        } else {
            Write-Host ("   searched: {0}" -f ($hunt -join '; ')) -ForegroundColor DarkGray
            Write-Host ("   build exit {0}; no {1} in {2}" -f $buildExit, $wanted, $tmp) `
                       -ForegroundColor Red
            if (Test-Path $bLog) {
                Get-Content $bLog | Select-Object -Last 8 |
                    ForEach-Object { Write-Host ("     {0}" -f $_) }
            }
        }
    }
    Push-Location $tmp
    if ($null -eq $rExe) {
        # already reported
    } elseif ($null -eq $tarball) {
        Write-Host "   R CMD build produced no tarball" -ForegroundColor Red
        Set-Result 'rcheck' $false 'build failed'
    } else {
        $chkOut = & $rExe.Source CMD check --as-cran --no-manual $tarball.FullName 2>&1 | Out-String
        $status = [regex]::Match($chkOut, 'Status:\s*(?<s>.+)')
        $errs = [regex]::Matches($chkOut, '(?m)^\s*ERROR').Count
        $warns = [regex]::Matches($chkOut, '(?m)^\s*WARNING').Count
        $note = if ($status.Success) { $status.Groups['s'].Value.Trim() } else { 'no Status line' }
        if ($errs -eq 0 -and $warns -eq 0) {
            Write-Host ("   0 ERRORs, 0 WARNINGs -- {0}" -f $note) -ForegroundColor Green
            Set-Result 'rcheck' $true $note
        } else {
            Write-Host ("   {0} ERROR(s), {1} WARNING(s) -- {2}" -f $errs, $warns, $note) -ForegroundColor Red
            Set-Result 'rcheck' $false $note
        }
    }
    Pop-Location
    Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
}

# ---------------------------------------------------------------------------
# 5. Stata conformance record
#
# The Stata leg is NOT run from here: there is no licence on CI runners, and batch Stata
# on Windows is untrustworthy in a script (it can hang after finishing, and its exit code
# does not reliably report failure). It is a manual gate:
#
#     do stata/tests/run_conformance.do
#
# What IS checked is whether the recorded result of the last hand-run is CURRENT. A manual
# gate whose result nobody writes down cannot be distinguished from a gate never run --
# 0.9.33 shipped exactly that way, its Stata leg unverified by anything, and the omission
# was invisible because this script simply printed "NOT RUN" and moved on.
#
# Deliberately a first-class leg in $results rather than a line printed later: a stale
# record must FAIL the run. Placed before the verdict below for that reason -- $allOk is
# computed from $results, so anything set after it prints a warning that changes nothing,
# which is the failure mode this whole check exists to prevent.
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "5. stata conformance record" -ForegroundColor Yellow
$stataRec = Join-Path (Join-Path $repo 'tests') 'stata-conformance.txt'
if (-not (Test-Path $stataRec)) {
    Write-Host "   MISSING tests/stata-conformance.txt -- no record it was ever run" -ForegroundColor Red
    Set-Result 'stata' $false 'no record; run stata/tests/run_conformance.do'
} else {
    $rec = Get-Content -Raw $stataRec
    $rv = if ($rec -match '(?m)^version:\s*(\S+)')    { $Matches[1] } else { $null }
    $rd = if ($rec -match '(?m)^date:\s*(\S+)')       { $Matches[1] } else { '?' }
    # $null, NOT '?'. A '?' placeholder is TRUTHY, so `-not $rr' could never fire and a
    # record carrying version: but no result: line sailed through and PASSED, printing
    # "?, recorded at 0.9.33". $rd stays '?' because the date is informational only.
    $rr = if ($rec -match '(?m)^result:\s*(.+?)\s*$') { $Matches[1] } else { $null }
    if (-not $rv -or -not $rr) {
        # Distinct from stale. Reporting "STALE: last gated at  ()" for a file that simply
        # has no version: line names the wrong problem and sends the reader to re-run Stata
        # when the fix is to repair three lines of text.
        Write-Host "   UNPARSEABLE tests/stata-conformance.txt -- no 'version:' or 'result:' line" -ForegroundColor Red
        Write-Host  "   expected, verbatim:  version: x.y.z / date: YYYY-MM-DD / result: <tally>" -ForegroundColor Red
        Set-Result 'stata' $false 'record exists but cannot be parsed (no version:/result: line)'
    }
    elseif ($rv -eq $version) {
        Write-Host ("   {0}, recorded at {1} ({2})" -f $rr, $rv, $rd) -ForegroundColor Green
        Set-Result 'stata' $true ("{0} at {1}, recorded {2} (run by hand; CI has no licence)" -f $rr, $rv, $rd)
    } else {
        Write-Host ("   STALE: last gated at {0} ({1}), current is {2}" -f $rv, $rd, $version) -ForegroundColor Red
        Write-Host  "   run: do stata/tests/run_conformance.do   then update the record" -ForegroundColor Red
        Set-Result 'stata' $false ("STALE: last gated at {0}, current is {1}" -f $rv, $version)
    }
}

# ---------------------------------------------------------------------------
# Verdict
# ---------------------------------------------------------------------------
$allOk = -not ($results.Values -contains $false)

Write-Host ""
Write-Host ("=" * 72)
Write-Host "paste this into the PR:" -ForegroundColor Cyan
Write-Host ""
Write-Host ("- Local verification (`scripts/verify.ps1`), datalib {0}:" -f $version)
foreach ($k in $results.Keys) {
    $mark = if ($results[$k]) { 'x' } else { ' ' }
    Write-Host ("  - [{0}] {1,-9} {2}" -f $mark, $k, $detail[$k])
}
Write-Host "        (the stata line above is a RECORDED hand-run, not something this"
Write-Host "         script executed -- see tests/stata-conformance.txt)"
Write-Host "  - [ ] GitHub Actions covers the R and Python legs on Linux and Windows;"
Write-Host "        this run additionally checks the version manifests, which no CI"
Write-Host "        job does, and is the only gate for Stata."
Write-Host ""

Pop-Location
if ($allOk) {
    Write-Host "VERIFIED" -ForegroundColor Green
    exit 0
} else {
    Write-Host "FAILED" -ForegroundColor Red
    exit 1
}
