# configure.ps1
#
# Configure phase: git defaults, an SSH key, and GitHub's host key. The git
# name and email are set later from the attendee's GitHub account, right
# after they sign in to GitHub (workshop-signin skill). No administrator
# prompt, no questions. Safe to run again: an existing SSH key is kept.
#
#   powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/configure.ps1

. "$PSScriptRoot\lib\common.ps1"

Write-Output '=== Configuring git and SSH ==='

$result = Invoke-LinuxScript -Path (Join-Path $PSScriptRoot 'linux\configure.sh') -ScriptArguments @('apply') -TimeoutSec 120
Write-Output $result.Output
if ($result.ExitCode -ne 0) {
    Write-Output ''
    Write-Output 'STOPPED: configuration is not complete (see [FAIL] above).'
    exit 1
}
Write-Output ''
Write-Output 'DONE: git and SSH are configured. Next: run check-status.ps1.'
