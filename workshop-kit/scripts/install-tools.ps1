# install-tools.ps1
#
# Install phase: installs every missing development tool inside Ubuntu, one
# component at a time, in order (see scripts/linux/tools.sh for the list and
# versions). Stops at the first failure. Safe to run again: finished
# components are skipped. No administrator prompt.
#
# Takes 10-30 minutes on a first run (Ruby may be compiled from source), so
# Claude should run it in the background.
#
#   powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/install-tools.ps1

. "$PSScriptRoot\lib\common.ps1"

$toolsScript = Join-Path $PSScriptRoot 'linux\tools.sh'
$timeouts = @{ 'apt-packages' = 1800; 'ruby' = 3600 }   # seconds; others use 900

Write-Output '=== Installing development tools ==='

if ((Get-DistroDefaultUser) -ne $LinuxUser) {
    Write-Output "[FAIL] Ubuntu is not set up yet. Run check-status.ps1 and follow its NEXT STEP."
    exit 1
}

$components = @(Get-LinuxChecks 'tools.sh')
if ($components.Count -eq 0) {
    Write-Output '[FAIL] Could not check the tools inside Ubuntu. Run check-status.ps1.'
    exit 1
}

foreach ($component in $components) {
    if ($component.Status -eq 'PASS') {
        Write-Check 'PASS' $component.Name $component.Detail
        continue
    }

    Write-Output ("Installing {0} ({1:HH:mm:ss}) ..." -f $component.Name, (Get-Date))
    $timeout = if ($timeouts.ContainsKey($component.Name)) { $timeouts[$component.Name] } else { 900 }
    $install = Invoke-LinuxScript -Path $toolsScript -ScriptArguments @('install', $component.Name) -TimeoutSec $timeout

    # tools.sh ends with a [PASS]/[FAIL] line, but installers' error output is
    # appended after normal output, so find that line rather than taking the last one.
    $lines = @($install.Output -split "`n")
    $result = @($lines | Where-Object { $_ -match "^\[(PASS|FAIL)\] $([regex]::Escape($component.Name)):" }) | Select-Object -Last 1
    Set-Content -Path (Join-Path $LogDir ("tools-{0}-{1:yyyyMMdd-HHmmss}.log" -f $component.Name, (Get-Date))) -Value $install.Output -Encoding UTF8
    if ($install.ExitCode -ne 0) {
        if ($install.TimedOut) { Write-Output "[FAIL] $($component.Name): timed out after $timeout seconds" }
        Write-Output ($lines | Select-Object -Last 25)
        Write-Output ''
        Write-Output "STOPPED: $($component.Name) failed. Full output is in logs\. Run this script again to retry."
        exit 1
    }
    Write-Output $result
}

Write-Output ''
Write-Output 'DONE: all development tools are installed. Next: run check-status.ps1.'
