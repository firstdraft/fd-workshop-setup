# common.ps1
#
# Settings and helper functions shared by the workshop setup scripts.
# Load it at the top of a script with:
#   . "$PSScriptRoot\lib\common.ps1"
#
# Keep this file (and every .ps1 in the kit) plain ASCII: Windows PowerShell 5.1
# reads files without a byte-order mark as ANSI, which garbles other characters.

$DistroName       = 'Ubuntu-24.04'
$LinuxUser        = 'appdev'
$MinimumBuild     = 19041   # Windows 10 2004: oldest build that runs WSL 2
$RecommendedBuild = 19044   # Windows 10 21H2: oldest build the current WSL package supports
$MinimumFreeGB    = 10

$KitRoot  = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$StateDir = Join-Path $KitRoot 'state'
$LogDir   = Join-Path $KitRoot 'logs'
foreach ($dir in @($StateDir, $LogDir)) {
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
}
$RebootMarker = Join-Path $StateDir 'restart-required.txt'

# Make wsl.exe print UTF-8 instead of UTF-16 so its output can be read.
$env:WSL_UTF8 = '1'
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch { }


# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------

function Write-Check {
    param([string]$Status, [string]$Name, [string]$Detail)
    Write-Output ('[{0}] {1} {2}' -f $Status.PadRight(4), $Name.PadRight(24, '.'), $Detail)
}

function New-Check {
    param([string]$Id, [string]$Name, [string]$Status, [string]$Detail)
    [pscustomobject]@{ Id = $Id; Name = $Name; Status = $Status; Detail = $Detail }
}


# ---------------------------------------------------------------------------
# Running programs
# ---------------------------------------------------------------------------

function Test-IsAdmin {
    $principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Runs a program with a time limit and returns its exit code and output.
# Output goes through temp files so nothing can hang waiting for input, and
# StdinText (if given) is sent with Linux line endings.
function Invoke-Native {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [string[]]$Arguments = @(),
        [string]$StdinText,
        [int]$TimeoutSec = 120
    )

    $base = Join-Path $env:TEMP ('workshop-' + [guid]::NewGuid().ToString('N'))
    $outFile = "$base.out"
    $errFile = "$base.err"
    $inFile = $null

    $params = @{
        FilePath               = $FilePath
        RedirectStandardOutput = $outFile
        RedirectStandardError  = $errFile
        NoNewWindow            = $true
        PassThru               = $true
    }
    if ($Arguments.Count -gt 0) {
        $quoted = foreach ($arg in $Arguments) {
            if ($arg -match '\s') { '"' + $arg + '"' } else { $arg }
        }
        $params.ArgumentList = $quoted -join ' '
    }
    if ($PSBoundParameters.ContainsKey('StdinText')) {
        $inFile = "$base.in"
        [IO.File]::WriteAllText($inFile, ($StdinText -replace "`r", ''), (New-Object Text.UTF8Encoding $false))
        $params.RedirectStandardInput = $inFile
    }

    try {
        $process = Start-Process @params
    }
    catch {
        return [pscustomobject]@{ ExitCode = -1; Output = "Could not start ${FilePath}: $($_.Exception.Message)"; TimedOut = $false }
    }
    # Windows PowerShell 5.1 only reports ExitCode if the handle was opened while the process ran.
    $null = $process.Handle

    $timedOut = $false
    if (-not $process.WaitForExit($TimeoutSec * 1000)) {
        $timedOut = $true
        try { $process.Kill() } catch { }
        $null = $process.WaitForExit(5000)
    }

    $text = ''
    foreach ($file in @($outFile, $errFile, $inFile)) {
        if ($file -and (Test-Path $file)) {
            if ($file -ne $inFile) { $text += [IO.File]::ReadAllText($file) + "`n" }
            Remove-Item $file -Force -ErrorAction SilentlyContinue
        }
    }
    # Some wsl.exe messages are UTF-16 even with WSL_UTF8 set; dropping the NULs recovers them.
    $text = ($text -replace "`0", '').Trim()
    # Drop terminal color codes that some installers print.
    $text = $text -replace "\x1b\[[0-9;]*[A-Za-z]", ''

    $exitCode = if ($timedOut) { -2 } else { $process.ExitCode }
    [pscustomobject]@{ ExitCode = $exitCode; Output = $text; TimedOut = $timedOut }
}

function Invoke-Wsl {
    param([string[]]$Arguments, [string]$StdinText, [int]$TimeoutSec = 120)
    $params = @{ FilePath = 'wsl.exe'; Arguments = $Arguments; TimeoutSec = $TimeoutSec }
    if ($PSBoundParameters.ContainsKey('StdinText')) { $params.StdinText = $StdinText }
    Invoke-Native @params
}

# Runs a bash script from scripts\linux inside Ubuntu. The script is piped in
# (so Windows line endings in the zip cannot break it) instead of read from /mnt/c,
# saved to a temp file, and run with stdin closed: with plain 'bash -s', any
# command that reads stdin would swallow the rest of the script.
# Script arguments must not contain spaces.
function Invoke-LinuxScript {
    param([string]$Path, [string]$User, [string[]]$ScriptArguments = @(), [int]$TimeoutSec = 300)
    $arguments = @('--distribution', $DistroName)
    if ($User) { $arguments += @('--user', $User) }
    $runner = 'f=$(mktemp) && cat >$f && bash $f ' + ($ScriptArguments -join ' ') + ' </dev/null; rc=$?; rm -f $f; exit $rc'
    $arguments += @('--exec', 'bash', '-c', $runner)
    Invoke-Wsl -Arguments $arguments -StdinText ([IO.File]::ReadAllText($Path)) -TimeoutSec $TimeoutSec
}

# Relaunches a script as administrator and waits for it. Windows shows the
# permission prompt; the elevated copy writes a log that is printed here so
# the output is not lost when its window closes. Returns the exit code.
function Invoke-Elevated {
    param([string]$ScriptPath, [string[]]$ExtraArguments = @())

    $name = [IO.Path]::GetFileNameWithoutExtension($ScriptPath)
    $logPath = Join-Path $LogDir ('{0}-{1:yyyyMMdd-HHmmss}.log' -f $name, (Get-Date))
    $argumentList = @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass',
        '-File', "`"$ScriptPath`"",
        '-LogPath', "`"$logPath`"",
        '-LaunchedBy', "`"$env:USERNAME`""
    ) + $ExtraArguments

    Write-Output 'WAITING FOR PERMISSION: Windows is asking "Do you want to allow this app to make changes to your device?"'
    Write-Output 'The attendee must click Yes (or type an administrator password if asked).'
    try {
        $process = Start-Process powershell.exe -Verb RunAs -ArgumentList ($argumentList -join ' ') -Wait -PassThru
    }
    catch {
        Write-Output '[FAIL] Permission was not granted (the Windows prompt was declined or closed).'
        return 10
    }

    if (Test-Path $logPath) {
        Get-Content $logPath | Write-Output
    }
    else {
        Write-Output "[WARN] The administrator window did not write a log ($logPath)."
    }
    return $process.ExitCode
}


# ---------------------------------------------------------------------------
# Facts about this computer
# ---------------------------------------------------------------------------

function Get-Architecture {
    if ($env:PROCESSOR_ARCHITEW6432) { $env:PROCESSOR_ARCHITEW6432 } else { $env:PROCESSOR_ARCHITECTURE }
}

# Returns On, Off, Suspended or Unknown for the system drive. Works without
# administrator rights. Values come from System.Volume.BitLockerProtection.
function Get-BitLockerState {
    try {
        $shell = New-Object -ComObject Shell.Application
        $value = $shell.NameSpace("$env:SystemDrive\").Self.ExtendedProperty('System.Volume.BitLockerProtection')
    }
    catch {
        return 'Unknown'
    }
    switch ($value) {
        2       { 'Off' }         # not encrypted
        8       { 'Off' }         # device encryption waiting for activation (no protector yet)
        5       { 'Suspended' }
        1       { 'On' }
        3       { 'On' }          # encrypting
        4       { 'On' }          # decrypting
        6       { 'On' }          # locked
        default { 'Unknown' }
    }
}

function Test-RestartPending {
    $lastBoot = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
    if (Test-Path $RebootMarker) {
        $markedAt = (Get-Item $RebootMarker).LastWriteTime
        if ($markedAt -gt $lastBoot) { return $true }
        Remove-Item $RebootMarker -Force   # the computer has restarted since
    }
    Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending'
}

function Set-RestartRequired {
    param([string]$Reason)
    Set-Content -Path $RebootMarker -Value ("{0:s} {1}" -f (Get-Date), $Reason) -Encoding ASCII
}

function Test-WslPackageInstalled {
    if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) { return $null }
    $result = Invoke-Wsl -Arguments @('--version') -TimeoutSec 30
    if ($result.ExitCode -eq 0) { return (($result.Output -split "`n")[0]).Trim() }
    return $null
}

function Get-WslDistros {
    $result = Invoke-Wsl -Arguments @('--list', '--quiet') -TimeoutSec 30
    if ($result.ExitCode -ne 0) { return @() }
    @($result.Output -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })
}

function Get-DistroWslVersion {
    $result = Invoke-Wsl -Arguments @('--list', '--verbose') -TimeoutSec 30
    foreach ($line in ($result.Output -split "`n")) {
        $parts = @(($line -replace '^\s*\*', '').Trim() -split '\s+')
        if ($parts.Count -ge 3 -and $parts[0] -eq $DistroName) { return $parts[-1] }
    }
    return $null
}

function Get-DistroDefaultUser {
    $result = Invoke-Wsl -Arguments @('--distribution', $DistroName, '--exec', 'whoami') -TimeoutSec 90
    if ($result.ExitCode -eq 0) { return $result.Output.Trim() }
    return $null
}


# Runs '<script> check all' for a script in scripts\linux (tools.sh,
# configure.sh) and returns one object per item, in order.
function Get-LinuxChecks {
    param([string]$Script)
    $result = Invoke-LinuxScript -Path (Join-Path $PSScriptRoot "..\linux\$Script") -ScriptArguments @('check', 'all') -TimeoutSec 120
    foreach ($line in ($result.Output -split "`n")) {
        if ($line -match '^\[(PASS|FAIL)\] ([a-z-]+): ?(.*)$') {
            [pscustomobject]@{ Status = $Matches[1]; Name = $Matches[2]; Detail = $Matches[3].Trim() }
        }
    }
}


# Summarizes one phase's Linux checks as a single status line.
function Get-PhaseCheck {
    param([string]$Id, [string]$Name, [string]$Script, [string]$DoneText)
    $items = @(Get-LinuxChecks $Script)
    $missing = @($items | Where-Object { $_.Status -eq 'FAIL' } | ForEach-Object { $_.Name })
    if ($items.Count -eq 0) { return New-Check $Id $Name 'FAIL' 'could not be checked' }
    if ($missing.Count -eq 0) { return New-Check $Id $Name 'PASS' "all $($items.Count) $DoneText" }
    New-Check $Id $Name 'FAIL' ('missing: ' + ($missing -join ', '))
}


# ---------------------------------------------------------------------------
# Overall status: every check plus the single next step to take
# ---------------------------------------------------------------------------

function Get-SetupStatus {
    $checks = New-Object System.Collections.Generic.List[object]

    $os = Get-CimInstance Win32_OperatingSystem
    $computer = Get-CimInstance Win32_ComputerSystem
    $processor = Get-CimInstance Win32_Processor | Select-Object -First 1
    $arch = Get-Architecture
    $build = [int]$os.BuildNumber

    $status = if ($build -lt $MinimumBuild) { 'FAIL' } elseif ($build -lt $RecommendedBuild) { 'WARN' } else { 'PASS' }
    $checks.Add((New-Check 'windows' 'Windows version' $status "$($os.Caption), build $build, $arch"))

    $disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$env:SystemDrive'"
    $freeGB = [math]::Round($disk.FreeSpace / 1GB, 1)
    $status = if ($freeGB -lt $MinimumFreeGB) { 'FAIL' } else { 'PASS' }
    $checks.Add((New-Check 'disk' 'Free disk space' $status "$freeGB GB free on $env:SystemDrive (need $MinimumFreeGB GB)"))

    $isVm = ($computer.Model -match 'Virtual|VMware|Parallels|KVM|QEMU') -or ($computer.Manufacturer -match 'VMware|Parallels|QEMU|innotek')
    if ($computer.HypervisorPresent) {
        $checks.Add((New-Check 'virtualization' 'Virtualization' 'PASS' 'available (a hypervisor is already running)'))
    }
    elseif ($processor.VirtualizationFirmwareEnabled) {
        $checks.Add((New-Check 'virtualization' 'Virtualization' 'PASS' 'turned on in BIOS/UEFI'))
    }
    elseif ($isVm) {
        $checks.Add((New-Check 'virtualization' 'Virtualization' 'FAIL' "this is a virtual machine ($($computer.Model)); nested virtualization must be turned on in the host"))
    }
    elseif ($arch -eq 'ARM64' -and $null -eq $processor.VirtualizationFirmwareEnabled) {
        $checks.Add((New-Check 'virtualization' 'Virtualization' 'WARN' 'cannot be detected on ARM; will be confirmed when Ubuntu starts'))
    }
    else {
        $checks.Add((New-Check 'virtualization' 'Virtualization' 'FAIL' 'turned OFF in BIOS/UEFI'))
    }

    $checks.Add((New-Check 'bitlocker' 'BitLocker / encryption' 'INFO' (Get-BitLockerState)))

    $restartPending = Test-RestartPending
    $status = if ($restartPending) { 'FAIL' } else { 'PASS' }
    $detail = if ($restartPending) { 'Windows is waiting for a restart' } else { 'no restart pending' }
    $checks.Add((New-Check 'restart' 'Restart pending' $status $detail))

    $feature = Get-CimInstance Win32_OptionalFeature -Filter "Name='VirtualMachinePlatform'"
    $featureOn = $feature -and $feature.InstallState -eq 1
    $status = if ($featureOn) { 'PASS' } else { 'FAIL' }
    $checks.Add((New-Check 'vmp' 'Virtual Machine Platform' $status $(if ($featureOn) { 'enabled' } else { 'not enabled' })))

    if ($featureOn -and -not $restartPending -and -not $computer.HypervisorPresent -and $arch -ne 'ARM64') {
        $checks.Add((New-Check 'hypervisor' 'Windows hypervisor' 'FAIL' 'feature is on but the hypervisor is not running'))
    }

    $wslVersion = Test-WslPackageInstalled
    $status = if ($wslVersion) { 'PASS' } else { 'FAIL' }
    $checks.Add((New-Check 'wsl' 'WSL package' $status $(if ($wslVersion) { $wslVersion } else { 'not installed (or an old built-in version)' })))

    if ($wslVersion) {
        $installed = (Get-WslDistros) -contains $DistroName
        $status = if ($installed) { 'PASS' } else { 'FAIL' }
        $checks.Add((New-Check 'distro' $DistroName $status $(if ($installed) { 'installed' } else { 'not installed' })))

        if ($installed) {
            $version = Get-DistroWslVersion
            $status = if ($version -eq '2') { 'PASS' } else { 'FAIL' }
            $checks.Add((New-Check 'distro-version' 'WSL version for Ubuntu' $status "WSL $version"))

            $user = Get-DistroDefaultUser
            $status = if ($user -eq $LinuxUser) { 'PASS' } else { 'FAIL' }
            $detail = if ($user) { "default user is '$user'" } else { 'Ubuntu did not start' }
            $checks.Add((New-Check 'user' 'Default Linux user' $status $detail))

            if ($user -eq $LinuxUser) {
                $checks.Add((Get-PhaseCheck 'tools' 'Development tools' 'tools.sh' 'components installed'))
                $checks.Add((Get-PhaseCheck 'configure' 'Git and SSH' 'configure.sh' 'items configured'))
                $checks.Add((Get-PhaseCheck 'handoff' 'Handoff to Ubuntu' 'handoff.sh' 'items installed'))
            }
        }
    }

    $failed = @($checks | Where-Object { $_.Status -eq 'FAIL' } | ForEach-Object { $_.Id })
    $next = if ($failed -contains 'windows') { 'STOP_WINDOWS_TOO_OLD' }
        elseif ($failed -contains 'disk') { 'STOP_LOW_DISK' }
        elseif ($failed -contains 'restart') { 'RESTART' }
        elseif ($failed -contains 'virtualization') { if ($isVm) { 'STOP_NESTED_VIRTUALIZATION' } else { 'ENABLE_VIRTUALIZATION' } }
        elseif ($failed -contains 'vmp' -or $failed -contains 'hypervisor' -or $failed -contains 'wsl') { 'INSTALL_WSL' }
        elseif ($failed -contains 'distro' -or $failed -contains 'distro-version' -or $failed -contains 'user') { 'SETUP_UBUNTU' }
        elseif ($failed -contains 'tools') { 'INSTALL_TOOLS' }
        elseif ($failed -contains 'configure') { 'CONFIGURE' }
        elseif ($failed -contains 'handoff') { 'HANDOFF' }
        else { 'DONE' }

    [pscustomobject]@{ Checks = $checks; NextStep = $next }
}
