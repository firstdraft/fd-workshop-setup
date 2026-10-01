# prepare-bios.ps1
#
# Gets the computer ready to turn on virtualization in the BIOS/UEFI:
#   1. If the drive is encrypted, suspends BitLocker for the next 2 restarts so
#      changing firmware settings does not trigger a recovery-key prompt. The
#      drive stays encrypted and protection turns back on by itself.
#   2. Restarts straight into the BIOS/UEFI settings screen after 60 seconds.
#
# If the drive is (or might be) encrypted, it refuses to run until the
# attendee has confirmed they can see their recovery key, which is passed
# in as -RecoveryKeyConfirmed.
#
#   powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/prepare-bios.ps1 [-RecoveryKeyConfirmed]

param(
    [switch]$RecoveryKeyConfirmed,
    [string]$LogPath,      # set when this script relaunches itself as administrator
    [string]$LaunchedBy
)

. "$PSScriptRoot\lib\common.ps1"

function Write-RecoveryKeyRequest {
    Write-Output 'BITLOCKER: this drive is encrypted.'
    Write-Output 'Before continuing, the attendee must open https://aka.ms/myrecoverykey on their PHONE,'
    Write-Output 'sign in with the Microsoft account used on this laptop, and confirm they can see a'
    Write-Output 'recovery key for this computer. Then run this script again with -RecoveryKeyConfirmed.'
}

$bitLocker = Get-BitLockerState

if (-not (Test-IsAdmin)) {
    $computer = Get-CimInstance Win32_ComputerSystem
    $processor = Get-CimInstance Win32_Processor | Select-Object -First 1
    if ($computer.HypervisorPresent -or $processor.VirtualizationFirmwareEnabled) {
        Write-Output 'NOT NEEDED: virtualization is already turned on. Run check-status.ps1 again.'
        exit 0
    }
    # 'Unknown' is settled precisely after elevation, before anything changes.
    if ($bitLocker -eq 'On' -and -not $RecoveryKeyConfirmed) {
        Write-RecoveryKeyRequest
        exit 20
    }
    $extra = @()
    if ($RecoveryKeyConfirmed) { $extra += '-RecoveryKeyConfirmed' }
    exit (Invoke-Elevated -ScriptPath $PSCommandPath -ExtraArguments $extra)
}

$result = @{ ExitCode = 0 }

$main = {
    Write-Output '=== Preparing to enter BIOS/UEFI (administrator) ==='

    if ($bitLocker -ne 'Off') {
        $suspended = $false
        try {
            $volume = Get-CimInstance -Namespace 'root\cimv2\Security\MicrosoftVolumeEncryption' -ClassName Win32_EncryptableVolume -Filter "DriveLetter='$env:SystemDrive'" -ErrorAction Stop
            if (-not $volume -or $volume.ProtectionStatus -eq 0) {
                Write-Check 'PASS' 'BitLocker' 'protection is off; nothing to suspend'
                $suspended = $true
            }
            elseif (-not $RecoveryKeyConfirmed) {
                Write-RecoveryKeyRequest
                $result.ExitCode = 20
                return
            }
            else {
                $call = Invoke-CimMethod -InputObject $volume -MethodName DisableKeyProtectors -Arguments @{ DisableCount = [uint32]2 } -ErrorAction Stop
                if ($call.ReturnValue -eq 0) {
                    Write-Check 'PASS' 'BitLocker' 'suspended for the next 2 restarts'
                    $suspended = $true
                }
                else {
                    Write-Check 'WARN' 'BitLocker' "DisableKeyProtectors returned $($call.ReturnValue); trying manage-bde"
                }
            }
        }
        catch {
            Write-Check 'WARN' 'BitLocker' "WMI not available ($($_.Exception.Message)); trying manage-bde"
        }

        if (-not $suspended -and -not $RecoveryKeyConfirmed) {
            # Could not tell whether the drive is protected: assume it is.
            Write-RecoveryKeyRequest
            $result.ExitCode = 20
            return
        }
        if (-not $suspended) {
            $bde =Invoke-Native -FilePath 'manage-bde.exe' -Arguments @('-protectors', '-disable', $env:SystemDrive, '-RebootCount', '2')
            if ($bde.ExitCode -eq 0) {
                Write-Check 'PASS' 'BitLocker' 'suspended for the next 2 restarts (manage-bde)'
                $suspended = $true
            }
            else {
                Write-Output $bde.Output
            }
        }

        if (-not $suspended) {
            Write-Check 'FAIL' 'BitLocker' 'could not be suspended. NOT restarting. Get the instructor.'
            $result.ExitCode = 21
            return
        }
    }
    else {
        Write-Check 'PASS' 'BitLocker' 'drive is not encrypted'
    }

    if ($env:firmware_type -ne 'UEFI') {
        Write-Check 'WARN' 'Firmware type' "${env:firmware_type}: cannot restart straight into setup"
        Write-Output 'MANUAL BIOS: restart normally and press the BIOS key for this brand as the logo appears (see docs/BIOS-GUIDE.md).'
        $result.ExitCode = 30
        return
    }

    $message = 'Workshop setup: restarting into BIOS/UEFI settings. Turn on virtualization, then save and exit (usually F10).'
    $restart = Invoke-Native -FilePath 'shutdown.exe' -Arguments @('/r', '/fw', '/t', '60', '/c', $message)
    if ($restart.ExitCode -eq 0) {
        Write-Output 'RESTARTING INTO BIOS in 60 seconds. To cancel: shutdown.exe /a'
    }
    else {
        Write-Check 'WARN' 'Restart into BIOS' "not supported here (exit code $($restart.ExitCode))"
        Write-Output 'MANUAL BIOS: Settings > System > Recovery > Advanced startup > Restart now >'
        Write-Output 'Troubleshoot > Advanced options > UEFI Firmware Settings > Restart.'
        $result.ExitCode = 31
    }
}

if ($LogPath) {
    & $main *>&1 | Tee-Object -FilePath $LogPath
}
else {
    & $main
}
exit $result.ExitCode
