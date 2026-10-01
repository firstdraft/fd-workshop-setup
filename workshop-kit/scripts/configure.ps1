# configure.ps1
#
# Configure phase: sets the attendee's git name and email (the email they use
# to sign in to GitHub), git defaults, an SSH key, and GitHub's host key.
# No administrator prompt. Safe to run again: an existing SSH key is kept.
#
#   powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/configure.ps1 -Name "Full Name" -Email "github-email@example.com"

param(
    [string]$Name,
    [string]$Email
)

. "$PSScriptRoot\lib\common.ps1"

Write-Output '=== Configuring git and SSH ==='

$Name = "$Name".Trim()
$Email = "$Email".Trim()
if ($Name -eq '' -or $Email -eq '') {
    Write-Output 'ASK: the attendee''s full name and the email address they use to sign in to GitHub.'
    Write-Output 'Then run: powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/configure.ps1 -Name "Full Name" -Email "email"'
    exit 40
}
if ($Email -notmatch '^[^@\s]+@[^@\s]+\.[^@\s]+$') {
    Write-Output "[FAIL] '$Email' does not look like an email address."
    exit 41
}

# WSLENV passes these Windows variables into Ubuntu unchanged, so names with
# spaces, apostrophes or accents need no quoting.
$env:WORKSHOP_GIT_NAME = $Name
$env:WORKSHOP_GIT_EMAIL = $Email
$env:WSLENV = (@($env:WSLENV, 'WORKSHOP_GIT_NAME/u', 'WORKSHOP_GIT_EMAIL/u') | Where-Object { $_ }) -join ':'

$result = Invoke-LinuxScript -Path (Join-Path $PSScriptRoot 'linux\configure.sh') -ScriptArguments @('apply') -TimeoutSec 120
Write-Output $result.Output
if ($result.ExitCode -ne 0) {
    Write-Output ''
    Write-Output 'STOPPED: configuration is not complete (see [FAIL] above).'
    exit 1
}
Write-Output ''
Write-Output 'DONE: git and SSH are configured. Next: run check-status.ps1.'
