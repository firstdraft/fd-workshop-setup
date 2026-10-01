# install-wsl.ps1
#
# Turns on the Windows features WSL needs and installs the WSL package.
# Needs administrator rights: it asks Windows for permission by itself.
# Does NOT restart the computer; it records that a restart is needed and
# check-status.ps1 will then report NEXT STEP: RESTART.
#
#   powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/install-wsl.ps1

param(
    [string]$LogPath,      # set when this script relaunches itself as administrator
    [string]$LaunchedBy
)

. "$PSScriptRoot\lib\common.ps1"

if (-not (Test-IsAdmin)) {
    exit (Invoke-Elevated -ScriptPath $PSCommandPath)
}

$result = @{ ExitCode = 0 }

$main = {
    Write-Output '=== Installing WSL (administrator) ==='
    if ($LaunchedBy -and $LaunchedBy -ne $env:USERNAME) {
        Write-Output "[INFO] Approved by administrator account '$env:USERNAME' for '$LaunchedBy'. That is fine for this step."
    }

    $restartNeeded = $false

    foreach ($feature in @('VirtualMachinePlatform', 'Microsoft-Windows-Subsystem-Linux')) {
        $dism = Invoke-Native -FilePath 'dism.exe' -Arguments @('/online', '/enable-feature', "/featurename:$feature", '/all', '/norestart') -TimeoutSec 900
        if ($dism.ExitCode -eq 0) {
            Write-Check 'PASS' $feature 'enabled'
        }
        elseif ($dism.ExitCode -eq 3010) {
            Write-Check 'PASS' $feature 'enabled (takes effect after a restart)'
            $restartNeeded = $true
        }
        else {
            Write-Check 'FAIL' $feature "dism exit code $($dism.ExitCode)"
            Write-Output $dism.Output
            $result.ExitCode = 1
            return
        }
    }

    # WSL 2 needs the Windows hypervisor to start at boot. Some machines have it
    # switched off (for example by older VirtualBox or VMware installers).
    $bcd = Invoke-Native -FilePath 'bcdedit.exe' -Arguments @('/set', 'hypervisorlaunchtype', 'auto')
    if ($bcd.ExitCode -eq 0) {
        Write-Check 'PASS' 'Hypervisor at startup' 'set to auto'
    }
    else {
        Write-Check 'WARN' 'Hypervisor at startup' "bcdedit exit code $($bcd.ExitCode): $($bcd.Output)"
    }
    if (-not (Get-CimInstance Win32_ComputerSystem).HypervisorPresent) { $restartNeeded = $true }

    if (Test-WslPackageInstalled) {
        Write-Output 'Updating the WSL package ...'
        $attempts = @(@('--update'), @('--update', '--web-download'))
    }
    else {
        Write-Output 'Downloading and installing the WSL package (this can take a few minutes) ...'
        $attempts = @(@('--install', '--no-distribution'), @('--install', '--no-distribution', '--web-download'), @('--update', '--web-download'))
    }
    foreach ($arguments in $attempts) {
        $wsl = Invoke-Wsl -Arguments $arguments -TimeoutSec 900
        Write-Output "wsl.exe $($arguments -join ' ') -> exit code $($wsl.ExitCode)"
        if ($wsl.Output) { Write-Output $wsl.Output }
        if ($wsl.Output -match 'restart|reboot') { $restartNeeded = $true }
        if ($wsl.ExitCode -eq 0 -and (Test-WslPackageInstalled)) { break }
    }

    $version = Test-WslPackageInstalled
    if ($version) {
        Write-Check 'PASS' 'WSL package' $version
    }
    elseif ($restartNeeded) {
        Write-Check 'WARN' 'WSL package' 'not confirmed yet; check again after the restart'
    }
    else {
        Write-Check 'FAIL' 'WSL package' 'could not be installed'
        $result.ExitCode = 1
        return
    }

    if ($restartNeeded) {
        Set-RestartRequired 'install-wsl'
        Write-Output ''
        Write-Output 'RESTART REQUIRED: Windows must restart before WSL can be used.'
    }
    Write-Output 'DONE: install-wsl finished.'
}

if ($LogPath) {
    & $main *>&1 | Tee-Object -FilePath $LogPath
}
else {
    & $main
}
exit $result.ExitCode
