# restart.ps1
#
# Restarts Windows after a delay so the attendee can save their work.
# Only run this after the attendee has agreed and knows how to resume.
# Cancel a scheduled restart with:  shutdown.exe /a
#
#   powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/restart.ps1

param([int]$Seconds = 60)

. "$PSScriptRoot\lib\common.ps1"

$message = 'Workshop setup: restarting. Afterwards, open Claude, open the workshop folder again and type: continue'
$result = Invoke-Native -FilePath 'shutdown.exe' -Arguments @('/r', '/t', "$Seconds", '/c', $message)

if ($result.ExitCode -eq 0) {
    Write-Output "RESTARTING in $Seconds seconds. To cancel: shutdown.exe /a"
    exit 0
}
Write-Output "[FAIL] Could not schedule a restart (exit code $($result.ExitCode)): $($result.Output)"
Write-Output 'Ask the attendee to restart from the Start menu instead: Power > Restart.'
exit 1
