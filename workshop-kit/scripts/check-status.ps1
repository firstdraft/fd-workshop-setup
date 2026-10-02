# check-status.ps1
#
# Read-only. Checks every part of the WSL setup and prints the single next
# step to take. Safe to run at any time, as often as you like.
#
#   powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/check-status.ps1

. "$PSScriptRoot\lib\common.ps1"

$commands = @{
    'ENABLE_VIRTUALIZATION' = 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/prepare-bios.ps1'
    'INSTALL_WSL'           = 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/install-wsl.ps1'
    'RESTART'               = 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/restart.ps1'
    'SETUP_UBUNTU'          = 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/setup-ubuntu.ps1'
    'INSTALL_TOOLS'         = 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/install-tools.ps1'
    'CONFIGURE'             = 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/configure.ps1'
    'HANDOFF'               = 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/verify.ps1, then scripts/handoff.ps1 -AppName "<app name>"'
    'DONE'                  = '(none: the attendee continues in a Claude Desktop WSL session; see DONE in CLAUDE.md)'
}

Write-Output '=== WSL setup status ==='
$status = Get-SetupStatus
foreach ($check in $status.Checks) {
    Write-Check $check.Status $check.Name $check.Detail
}

Write-Output ''
Write-Output "NEXT STEP: $($status.NextStep)"
if ($commands.ContainsKey($status.NextStep)) {
    Write-Output "COMMAND:   $($commands[$status.NextStep])"
}

$status | ConvertTo-Json -Depth 4 | Set-Content -Path (Join-Path $StateDir 'status.json') -Encoding ASCII
