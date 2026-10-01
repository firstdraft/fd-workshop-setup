# handoff.ps1
#
# Final step on the Windows side: creates the app folder in Ubuntu, installs
# the 'workshop' command and its sign-in plugin, then opens an Ubuntu window
# that starts it (unless -NoOpen). No administrator prompt. Safe to run again.
#
#   powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/handoff.ps1 -AppName firstdraft-workshop

param(
    [string]$AppName,
    [switch]$NoOpen
)

. "$PSScriptRoot\lib\common.ps1"

Write-Output '=== Handing over to Claude Code in Ubuntu ==='

$AppName = "$AppName".Trim()
if ($AppName -eq '') {
    Write-Output 'ASK: what the attendee wants to call their app (default: firstdraft-workshop).'
    exit 40
}
if ($AppName -cnotmatch '^[a-z][a-z0-9-]{0,49}$') {
    Write-Output "[FAIL] '$AppName' is not a valid app name. Use lowercase letters, numbers and dashes, starting with a letter (e.g. my-first-app)."
    exit 41
}

# WSLENV passes these into Ubuntu; /p converts the kit's Windows path to a Linux path.
$env:WORKSHOP_APP_NAME = $AppName
$env:WORKSHOP_KIT_DIR = $KitRoot
$env:WSLENV = (@($env:WSLENV, 'WORKSHOP_APP_NAME/u', 'WORKSHOP_KIT_DIR/p') | Where-Object { $_ }) -join ':'

$result = Invoke-LinuxScript -Path (Join-Path $PSScriptRoot 'linux\handoff.sh') -ScriptArguments @('apply') -TimeoutSec 120
Write-Output $result.Output
if ($result.ExitCode -ne 0) {
    Write-Output ''
    Write-Output 'STOPPED: the handoff is not complete (see [FAIL] above).'
    exit 1
}

if (-not $NoOpen) {
    & (Join-Path $PSScriptRoot 'open-workshop.ps1')
}
Write-Output ''
Write-Output "DONE: ~/$AppName is ready."
