#!/usr/bin/env bash
# platform.sh
#
# The few commands that differ between a Windows laptop, where the helpers
# run in Ubuntu in WSL, and a Mac. login.sh, auth.sh, cloudinary.sh and
# open.sh source this file. Installed to ~/.workshop/platform.sh by
# handoff.sh.
#
# Every helper must also run under macOS's /bin/bash, which is bash 3.2:
# no mapfile, no ${var,,}, no associative arrays.

if [ "$(uname -s)" = Darwin ]; then
    WORKSHOP_PLATFORM=mac
    CLIPBOARD="the clipboard (pbpaste failed)"
    # This is the attendee's own Mac account, so their global git name and
    # email stay theirs; repositories under ~/workshop include this file
    # instead (git-identity.sh).
    GIT_IDENTITY=(--file "$HOME/.workshop/gitconfig")
    # Homebrew's tools, for a session that started before Homebrew was
    # installed (a new session reads them from the shell's startup files).
    export PATH="$PATH:/opt/homebrew/bin:/usr/local/bin"
    # macOS has no setsid command. Perl starts a new session (its own
    # process group, so 'kill -- -PID' stops all of it), then becomes the
    # command, keeping the PID.
    DETACH=(perl -MPOSIX -e 'POSIX::setsid() or die "setsid: $!\n"; exec { $ARGV[0] } @ARGV or die "cannot run $ARGV[0]: $!\n"' --)
else
    WORKSHOP_PLATFORM=wsl
    CLIPBOARD="the Windows clipboard (powershell.exe Get-Clipboard failed)"
    GIT_IDENTITY=(--global)
    DETACH=(setsid)
fi

# Opens a link in the attendee's default browser.
open_link() {
    if [ "$WORKSHOP_PLATFORM" = mac ]; then
        open "$1" >/dev/null 2>&1
        return
    fi
    # wslview asks Windows to open it, with Windows PowerShell's
    # Start-Process as a fallback.
    wslview "$1" >/dev/null 2>&1 && return 0
    powershell.exe -NoProfile -NonInteractive -Command "Start-Process '$1'" >/dev/null 2>&1
}

# Puts text on the clipboard.
copy_text() {
    local clip
    if [ "$WORKSHOP_PLATFORM" = mac ]; then
        printf '%s' "$1" | pbcopy 2>/dev/null
        return
    fi
    clip=$(command -v clip.exe || echo /mnt/c/Windows/System32/clip.exe)
    printf '%s' "$1" | "$clip" 2>/dev/null
}

# Prints the clipboard's text unchanged. Callers capture it; it must never
# reach the terminal.
paste_text() {
    local powershell
    if [ "$WORKSHOP_PLATFORM" = mac ]; then
        pbpaste </dev/null 2>/dev/null
        return
    fi
    powershell=$(command -v powershell.exe || echo /mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe)
    "$powershell" -NoProfile -NonInteractive -Command Get-Clipboard </dev/null 2>/dev/null
}

# Runs a command and stops it after a number of seconds:
#   run_with_timeout <seconds> <command> [arguments]
run_with_timeout() {
    if [ "$WORKSHOP_PLATFORM" = mac ]; then
        # macOS has no timeout command. The alarm outlives exec, and its
        # signal ends the command.
        perl -e 'alarm shift; exec { $ARGV[0] } @ARGV or die "cannot run $ARGV[0]: $!\n"' -- "$@"
        return
    fi
    timeout "$@"
}
