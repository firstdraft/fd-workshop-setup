# setup-ubuntu.ps1
#
# Installs Ubuntu 24.04 for the current Windows user and creates the Linux
# user 'appdev' (password 'appdev') as the default, without the interactive
# first-run questions. Runs as the normal user: no administrator rights needed.
# Safe to run again.
#
#   powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/setup-ubuntu.ps1 [-ReplaceExistingUser]

param(
    # Required when Ubuntu-24.04 already exists with a different default user,
    # so an attendee's existing setup is never changed without them agreeing.
    [switch]$ReplaceExistingUser
)

. "$PSScriptRoot\lib\common.ps1"

Write-Output "=== Setting up $DistroName ==="

if (-not (Test-WslPackageInstalled)) {
    Write-Output '[FAIL] WSL is not installed yet. Run check-status.ps1 and follow its NEXT STEP.'
    exit 1
}

$null = Invoke-Wsl -Arguments @('--set-default-version', '2')

if ((Get-WslDistros) -contains $DistroName) {
    Write-Check 'PASS' $DistroName 'already installed'
}
else {
    Write-Output "Downloading and installing $DistroName (this can take 5-15 minutes) ..."
    # --no-launch skips Ubuntu's first-run questions; the user is created below instead.
    foreach ($arguments in @(
            @('--install', '--distribution', $DistroName, '--no-launch'),
            @('--install', '--distribution', $DistroName, '--no-launch', '--web-download'))) {
        $install = Invoke-Wsl -Arguments $arguments -TimeoutSec 1800
        Write-Output "wsl.exe $($arguments -join ' ') -> exit code $($install.ExitCode)"
        if ($install.Output) { Write-Output $install.Output }
        if ((Get-WslDistros) -contains $DistroName) { break }
    }

    # Older WSL versions install Ubuntu as a Store app that is not registered
    # until its launcher runs once. 'install --root' registers it without questions.
    if (-not ((Get-WslDistros) -contains $DistroName)) {
        $launcher = Get-Command 'ubuntu2404.exe' -ErrorAction SilentlyContinue
        if ($launcher) {
            $register = Invoke-Native -FilePath $launcher.Source -Arguments @('install', '--root') -TimeoutSec 900
            Write-Output "ubuntu2404.exe install --root -> exit code $($register.ExitCode)"
        }
    }

    if (-not ((Get-WslDistros) -contains $DistroName)) {
        Write-Check 'FAIL' $DistroName 'could not be installed'
        exit 1
    }
    Write-Check 'PASS' $DistroName 'installed'
}

if ((Get-DistroWslVersion) -ne '2') {
    Write-Output 'Converting Ubuntu to WSL 2 ...'
    $convert = Invoke-Wsl -Arguments @('--set-version', $DistroName, '2') -TimeoutSec 1800
    if ($convert.ExitCode -ne 0) {
        Write-Check 'FAIL' 'WSL version' $convert.Output
        exit 1
    }
}
Write-Check 'PASS' 'WSL version' '2'

$currentUser = Get-DistroDefaultUser
if ($currentUser -and $currentUser -ne 'root' -and $currentUser -ne $LinuxUser -and -not $ReplaceExistingUser) {
    Write-Output "ASK: $DistroName already has default user '$currentUser'. Setup would add '$LinuxUser' and make it"
    Write-Output "the default (the existing user and files are kept). Ask the attendee, then run again with -ReplaceExistingUser."
    exit 40
}

$setup = Invoke-LinuxScript -Path (Join-Path $PSScriptRoot 'linux\setup-user.sh') -User 'root'
Write-Output $setup.Output
if ($setup.ExitCode -ne 0) {
    Write-Check 'FAIL' 'Linux user' "setup-user.sh exit code $($setup.ExitCode)"
    exit 1
}

# /etc/wsl.conf now names the default user. Also set it where WSL itself keeps
# it, and mark the first-run questions as done so they never appear.
$uid = Invoke-Wsl -Arguments @('--distribution', $DistroName, '--user', 'root', '--exec', 'id', '-u', $LinuxUser)
foreach ($key in Get-ChildItem 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss' -ErrorAction SilentlyContinue) {
    $properties = Get-ItemProperty $key.PSPath
    if ($properties.DistributionName -eq $DistroName) {
        if ($uid.ExitCode -eq 0) {
            Set-ItemProperty $key.PSPath -Name 'DefaultUid' -Value ([int]$uid.Output.Trim()) -Type DWord
        }
        if ($properties.PSObject.Properties.Name -contains 'RunOOBE') {
            Set-ItemProperty $key.PSPath -Name 'RunOOBE' -Value 0 -Type DWord
        }
    }
}

$null = Invoke-Wsl -Arguments @('--set-default', $DistroName)
$null = Invoke-Wsl -Arguments @('--terminate', $DistroName)

$currentUser = Get-DistroDefaultUser
if ($currentUser -ne $LinuxUser) {
    Write-Check 'FAIL' 'Default Linux user' "expected '$LinuxUser' but got '$currentUser'"
    exit 1
}
Write-Check 'PASS' 'Default Linux user' $LinuxUser
Write-Output 'DONE: Ubuntu is set up. Next: run check-status.ps1.'
