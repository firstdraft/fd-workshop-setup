# setup-without-claude.ps1
#
# Fallback for when Claude is not available: runs the same steps as the
# Claude-guided setup, in a window, asking the attendee directly.
# Started by double-clicking "Setup WSL without Claude.cmd".

. "$PSScriptRoot\lib\common.ps1"

function Invoke-Step([string]$Script, [string[]]$Arguments = @()) {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot $Script) @Arguments
    return $LASTEXITCODE
}

function Stop-Here([string]$Message) {
    Write-Host ''
    Write-Host $Message -ForegroundColor Yellow
    Write-Host ''
    Read-Host 'Press Enter to close this window'
    exit 1
}

$previous = ''
while ($true) {
    $status = Get-SetupStatus
    foreach ($check in $status.Checks) { Write-Check $check.Status $check.Name $check.Detail }
    $next = $status.NextStep
    Write-Host ''
    Write-Host "Next step: $next" -ForegroundColor Cyan

    if ($next -eq $previous) {
        Stop-Here "The step '$next' did not complete. Please ask the instructor for help."
    }
    $previous = $next

    switch ($next) {
        'STOP_WINDOWS_TOO_OLD' { Stop-Here 'This version of Windows is too old. Install all Windows updates (Settings > Windows Update), restart, then run this again.' }
        'STOP_LOW_DISK' { Stop-Here "Free up at least $MinimumFreeGB GB of disk space, then run this again." }
        'STOP_NESTED_VIRTUALIZATION' { Stop-Here 'This Windows is a virtual machine. Turn on nested virtualization in the host software, or ask the instructor.' }
        'RESTART' { Stop-Here 'Save your work and restart the computer (Start > Power > Restart). Then double-click "Setup WSL without Claude.cmd" again.' }
        'ENABLE_VIRTUALIZATION' {
            Write-Host 'Virtualization must be turned on in the BIOS. Read docs\BIOS-GUIDE.md first (take a photo of it with your phone).'
            $arguments = @()
            if ((Get-BitLockerState) -ne 'Off') {
                Write-Host 'Your drive may be encrypted. On your PHONE, open https://aka.ms/myrecoverykey and sign in.'
                $answer = Read-Host 'Can you see a recovery key for this computer? (yes/no)'
                if ($answer -notmatch '^y') { Stop-Here 'Please ask the instructor for help before changing BIOS settings.' }
                $arguments = @('-RecoveryKeyConfirmed')
            }
            $code = Invoke-Step 'prepare-bios.ps1' $arguments
            if ($code -eq 0) { Stop-Here 'The computer will restart into the BIOS in 60 seconds. After Windows starts again, run this again.' }
            Stop-Here 'Could not restart into the BIOS automatically. See docs\BIOS-GUIDE.md or ask the instructor.'
        }
        'INSTALL_WSL' {
            if ((Invoke-Step 'install-wsl.ps1') -ne 0) { Stop-Here 'Installing WSL failed. Please ask the instructor for help.' }
        }
        'SETUP_UBUNTU' {
            $code = Invoke-Step 'setup-ubuntu.ps1'
            if ($code -eq 40) {
                $answer = Read-Host "Add the workshop user '$LinuxUser' and make it the default? Your existing Linux user and files are kept. (yes/no)"
                if ($answer -notmatch '^y') { Stop-Here 'Setup stopped. Please ask the instructor.' }
                $code = Invoke-Step 'setup-ubuntu.ps1' @('-ReplaceExistingUser')
            }
            if ($code -ne 0) { Stop-Here 'Setting up Ubuntu failed. Please ask the instructor for help.' }
        }
        'INSTALL_TOOLS' {
            Write-Host 'Installing development tools. This can take 10-30 minutes; please keep the laptop plugged in and awake.'
            if ((Invoke-Step 'install-tools.ps1') -ne 0) { Stop-Here 'Installing the tools failed. Please ask the instructor for help.' }
        }
        'CONFIGURE' {
            $name = Read-Host 'Your full name (as you want it shown on GitHub)'
            $email = Read-Host 'The email address you use to sign in to GitHub'
            if ((Invoke-Step 'configure.ps1' @('-Name', $name, '-Email', $email)) -ne 0) { Stop-Here 'Configuring git failed. Please ask the instructor for help.' }
        }
        'HANDOFF' {
            if ((Invoke-Step 'verify.ps1') -ne 0) { Stop-Here 'Some checks failed (see above). Please show this window to the instructor.' }
            $appName = (Read-Host 'What do you want to call your app? Press Enter for firstdraft-workshop').Trim()
            if ($appName -eq '') { $appName = 'firstdraft-workshop' }
            if ((Invoke-Step 'handoff.ps1' @('-AppName', $appName)) -ne 0) { Stop-Here 'The last step failed. Please ask the instructor for help.' }
        }
        'DONE' {
            Write-Host ''
            Write-Host 'All done! An Ubuntu window will sign you in to the workshop tools.' -ForegroundColor Green
            Write-Host 'Later, open "Ubuntu 24.04" from the Start menu and type  workshop  to start again.'
            Read-Host 'Press Enter to close this window'
            exit 0
        }
    }
}
