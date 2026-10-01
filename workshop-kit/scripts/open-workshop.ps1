# open-workshop.ps1
#
# Opens an Ubuntu terminal window that runs the 'workshop' command: the
# sign-in session first (if needed), then Claude Code in the app folder.
#
#   powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/open-workshop.ps1

. "$PSScriptRoot\lib\common.ps1"

# The next interactive Ubuntu shell sees this file, deletes it, and starts
# 'workshop' (see the autostart line handoff.sh adds to ~/.bashrc).
$marker = Invoke-Wsl -Arguments @('--distribution', $DistroName, '--exec', 'touch', "/home/$LinuxUser/.workshop/autostart")
if ($marker.ExitCode -ne 0) {
    Write-Output "[FAIL] Could not prepare Ubuntu: $($marker.Output)"
    exit 1
}

try {
    if (Get-Command wt.exe -ErrorAction SilentlyContinue) {
        Start-Process wt.exe -ArgumentList "wsl.exe --distribution $DistroName --cd ~"
    }
    else {
        Start-Process wsl.exe -ArgumentList "--distribution $DistroName --cd ~"
    }
}
catch {
    Write-Output "[FAIL] Could not open a terminal window: $($_.Exception.Message)"
    Write-Output 'Ask the attendee to open "Ubuntu 24.04" from the Start menu instead; it starts the workshop by itself.'
    exit 1
}
Write-Output 'OPENED: an Ubuntu window is starting the workshop command.'
