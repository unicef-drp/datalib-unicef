<#
.SYNOPSIS
    Register (or replace) a weekly Windows Scheduled Task that runs a sync script.

.DESCRIPTION
    Registers a Scheduled Task that runs a PowerShell script on a weekly schedule.
    Defaults to "only when logged on" at a limited run level (no elevation, no
    stored credentials). Point -ScriptPath at your own thin wrapper that calls
    sync-folders.ps1 with your source / destination / folders — keep UNC paths
    inside that wrapper so it works in the task's logon session.

.PARAMETER TaskName    Name of the scheduled task (created or replaced).
.PARAMETER ScriptPath  Full path to the .ps1 to run (e.g. your sync wrapper).
.PARAMETER ScriptArgs  Optional extra arguments passed to the script.
.PARAMETER DaysOfWeek  One or more days (default: Sunday).
.PARAMETER At          Time of day (default: 9:00AM).
.PARAMETER RunWhetherLoggedOnOrNot
    Run even when you are not logged on (S4U). Default: only when logged on.

.EXAMPLE
    .\schedule-sync.ps1 -TaskName 'Deposit to Z (weekly)' `
        -ScriptPath 'C:\Users\me\Scripts\my-deposit.ps1' -DaysOfWeek Sunday -At 9:00AM

.NOTES
    StartWhenAvailable is on: if the machine is off/logged-off at the scheduled
    time, the task runs at the next opportunity that day rather than skipping.
#>
param(
    [Parameter(Mandatory)] [string]   $TaskName,
    [Parameter(Mandatory)] [string]   $ScriptPath,
    [string[]] $ScriptArgs = @(),
    [ValidateSet('Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday')]
    [string[]] $DaysOfWeek = @('Sunday'),
    [string]   $At = '9:00AM',
    [switch]   $RunWhetherLoggedOnOrNot
)
$ErrorActionPreference = 'Stop'
if (-not (Test-Path $ScriptPath)) { throw "Script not found: $ScriptPath" }

$argLine = "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`""
if ($ScriptArgs.Count) { $argLine += ' ' + ($ScriptArgs -join ' ') }

$action    = New-ScheduledTaskAction    -Execute 'powershell.exe' -Argument $argLine
$trigger   = New-ScheduledTaskTrigger   -Weekly -DaysOfWeek $DaysOfWeek -At $At
$logonType = if ($RunWhetherLoggedOnOrNot) { 'S4U' } else { 'Interactive' }
$principal = New-ScheduledTaskPrincipal  -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType $logonType -RunLevel Limited
$settings  = New-ScheduledTaskSettingsSet -StartWhenAvailable -MultipleInstances IgnoreNew `
             -ExecutionTimeLimit (New-TimeSpan -Hours 6)

Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger `
    -Principal $principal -Settings $settings `
    -Description "Weekly sync via $ScriptPath" -Force | Out-Null

"Registered: $TaskName"
Get-ScheduledTask -TaskName $TaskName | Select-Object TaskName, State
"NextRunTime : $((Get-ScheduledTaskInfo -TaskName $TaskName).NextRunTime)"
