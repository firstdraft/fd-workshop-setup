# verify.ps1
#
# Final check that the laptop is ready for the workshop. Read-only.
# Prints RESULT: READY or RESULT: NOT READY and saves a copy in logs\.
#
#   powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/verify.ps1

. "$PSScriptRoot\lib\common.ps1"

$lines = New-Object System.Collections.Generic.List[string]
$failures = 0

$lines.Add('=== Windows ===')
$status = Get-SetupStatus
foreach ($check in $status.Checks) {
    # The handoff happens after verification, so it does not count here.
    if ($check.Id -eq 'handoff') { continue }
    $lines.Add((Write-Check $check.Status $check.Name $check.Detail))
    if ($check.Status -eq 'FAIL') { $failures++ }
}

$lines.Add('')
$lines.Add("=== Inside $DistroName ===")
if ((Get-WslDistros) -contains $DistroName) {
    $linux = Invoke-LinuxScript -Path (Join-Path $PSScriptRoot 'linux\verify.sh') -TimeoutSec 180
    foreach ($line in ($linux.Output -split "`n")) { $lines.Add($line.TrimEnd()) }
    if ($linux.ExitCode -ne 0) { $failures++ }

    foreach ($phase in @(@('Development tools', 'tools.sh'), @('Git and SSH', 'configure.sh'))) {
        $lines.Add('')
        $lines.Add("=== $($phase[0]) ===")
        foreach ($item in @(Get-LinuxChecks $phase[1])) {
            $lines.Add(('[{0}] {1}: {2}' -f $item.Status, $item.Name, $item.Detail))
        }
    }
}
else {
    $lines.Add("[FAIL] $DistroName is not installed")
    $failures++
}

$lines.Add('')
if ($failures -eq 0) { $lines.Add('RESULT: READY') } else { $lines.Add('RESULT: NOT READY') }

$lines | Write-Output
$lines | Set-Content -Path (Join-Path $LogDir ('verify-{0:yyyyMMdd-HHmmss}.txt' -f (Get-Date))) -Encoding UTF8
if ($failures -eq 0) { exit 0 } else { exit 1 }
