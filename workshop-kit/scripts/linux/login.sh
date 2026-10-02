#!/usr/bin/env bash
# login.sh
#
# Starts a sign-in that waits for the browser, without blocking Claude:
# the sign-in keeps running in the background, and this script prints its
# link (and one-time code, if any) as soon as it appears, then returns.
# It also opens the link in the default Windows browser and copies it (or
# the code, if the page asks for one) to the Windows clipboard.
# Installed to ~/.workshop/login.sh by handoff.sh; used by the sign-in skill.
#
#   bash login.sh start <service>    github | github-refresh | render | neon | revyl
#                                    | firstdraft | firstdraft-device
#   bash login.sh stop <service>     cancel a sign-in that is still waiting
#   bash login.sh status <service>   is it still waiting, or did it finish / time out?
#
# Starting again cancels the previous attempt for that service, because its
# link no longer works once a new one is created.
# Set WORKSHOP_NO_OPEN=1 to skip opening the browser and the clipboard (for tests).

set -uo pipefail

export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:$HOME/.revyl/bin:$PATH"
# Stop the CLIs from opening a browser themselves (most ignore this setting
# anyway, and the ones that do would open a second tab): this script opens
# the link instead, the same way for every service.
export BROWSER=/bin/false

LOG_DIR="$HOME/.workshop/logs"
mkdir -p "$LOG_DIR"

action=${1:-}
service=${2:-}
opens_browser_itself=""   # set for CLIs that open the link whatever BROWSER says
expires_after=""          # set for CLIs whose sign-in gives up quickly

case "$service" in
    github)
        # --skip-ssh-key: the skill uploads the key itself, which needs the
        # admin:public_key permission.
        command=(gh auth login --hostname github.com --git-protocol ssh --web --skip-ssh-key --scopes admin:public_key) ;;
    github-refresh)
        # Adds missing permissions to an existing GitHub sign-in.
        command=(gh auth refresh --hostname github.com --scopes admin:public_key) ;;
    render) command=(render login) ;;
    neon)
        # neonctl always opens the link itself (the 'open' package ignores
        # BROWSER), and its local listener for the browser's reply closes
        # after 60 seconds, which cannot be changed.
        command=(neonctl auth); opens_browser_itself=1; expires_after=60 ;;
    revyl)  command=(revyl auth login) ;;
    # The browser sends the approval back to a local address in Ubuntu.
    firstdraft) command=(firstdraft login) ;;
    # Fallback if that does not reach Ubuntu: approve with a code instead.
    firstdraft-device) command=(firstdraft login --device) ;;
    *)
        echo "usage: login.sh start|stop|status github|github-refresh|render|neon|revyl|firstdraft|firstdraft-device"
        exit 2 ;;
esac

log="$LOG_DIR/$service.log"
pid_file="$LOG_DIR/$service.pid"
# The auth.sh check for this service: github-refresh -> github, firstdraft-device -> firstdraft.
check_service=${service%-refresh}
check_service=${check_service%-device}

stop_previous() {
    local pid
    pid=$(cat "$pid_file" 2>/dev/null) || return 0
    # The sign-in runs in its own process group (setsid), so stop the whole group.
    kill -- "-$pid" 2>/dev/null || kill "$pid" 2>/dev/null
    rm -f "$pid_file"
}

if [ "$action" = stop ]; then
    stop_previous
    echo "STOPPED: $service sign-in cancelled"
    exit 0
fi
if [ "$action" = status ]; then
    pid=$(cat "$pid_file" 2>/dev/null)
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
        echo "WAITING: the $service sign-in is still waiting for approval in the browser"
    elif grep -qi 'timed out' "$log" 2>/dev/null; then
        echo "TIMED OUT: the $service sign-in gave up before it was approved; start it again"
    else
        echo "ENDED: the $service sign-in is no longer running. Its last output:"
        sed 's/\x1b\[[0-9;]*[A-Za-z]//g' "$log" 2>/dev/null | tail -n 5
        echo "Run: bash ~/.workshop/auth.sh check $check_service"
    fi
    exit 0
fi
[ "$action" = start ] || { echo "usage: login.sh start|stop|status <service>"; exit 2; }

stop_previous
: > "$log"
setsid nohup "${command[@]}" </dev/null >"$log" 2>&1 &
pid=$!
echo "$pid" > "$pid_file"

# The sign-in link in the output:
#   - a link that already includes the code, if there is one (First Draft's
#     device sign-in prints the link both without and with the code);
#   - otherwise the longest link: sign-in links carry long parameters, while
#     other links in the text are short (First Draft names its plain address
#     first; Revyl's banner links to its docs, which are skipped anyway).
find_link() {
    local links
    links=$(sed 's/\x1b\[[0-9;]*[A-Za-z]//g' "$log" | grep -oE 'https://[^ "<>]+' \
        | sed 's/[.,;:)]*$//' | grep -vE '://docs\.')
    printf '%s\n' "$links" | grep -E '[?&](user_)?code=' | head -n 1 | grep . \
        || printf '%s\n' "$links" | awk '{ print length, $0 }' | sort -rn | head -n 1 | cut -d' ' -f2-
}

# Wait up to 30 seconds for a link, or for the command to finish by itself
# (for example "already signed in", or an error).
for _ in $(seq 1 60); do
    [ -n "$(find_link)" ] && break
    kill -0 "$pid" 2>/dev/null || break
    sleep 0.5
done
sleep 1   # let a one-time code printed just after the link arrive too

clean=$(sed 's/\x1b\[[0-9;]*[A-Za-z]//g' "$log")

if ! kill -0 "$pid" 2>/dev/null; then
    rm -f "$pid_file"
    echo "FINISHED: the sign-in command exited without waiting for the browser. Its output:"
    printf '%s\n' "$clean" | tail -n 15
    echo "Run: bash ~/.workshop/auth.sh check $check_service"
    exit 0
fi

# Opens a link in the default Windows browser: wslview asks Windows to open
# it, with Windows PowerShell's Start-Process as a fallback.
open_in_windows() {
    wslview "$1" >/dev/null 2>&1 && return 0
    powershell.exe -NoProfile -NonInteractive -Command "Start-Process '$1'" >/dev/null 2>&1
}

# Puts text on the Windows clipboard.
copy_to_windows() {
    local clip
    clip=$(command -v clip.exe || echo /mnt/c/Windows/System32/clip.exe)
    printf '%s' "$1" | "$clip" 2>/dev/null
}

url=$(find_link)
# One-time codes: GitHub prints ABCD-1234, Render prints ABCD-EFGH-IJKL-MNOP.
code=$(printf '%s\n' "$clean" | grep -oE '\b[A-Z0-9]{4}(-[A-Z0-9]{4})+\b' | head -n 1)
if [ -n "$url" ]; then
    echo "URL: $url"
    [ -n "$code" ] && echo "CODE: $code"
    if [ "${WORKSHOP_NO_OPEN:-}" != 1 ]; then
        if [ -n "$opens_browser_itself" ]; then
            # Opening it here too would give the attendee two tabs.
            echo "OPENED: $service opened the sign-in page in the default Windows browser itself"
        else
            open_in_windows "$url" && echo "OPENED: the sign-in page in the default Windows browser" \
                || echo "NOT OPENED: could not open the browser; the attendee must open the link"
        fi
        # Copy what the attendee needs to paste: the code if the link does not
        # already contain it (GitHub), otherwise the link.
        if [ -n "$code" ] && [[ "$url" != *"$code"* ]]; then
            copy_to_windows "$code" && echo "COPIED: the code, ready to paste into the page"
        else
            copy_to_windows "$url" && echo "COPIED: the link, ready to paste into a browser"
        fi
    fi
    echo "WAITING: the sign-in is running in the background until it is approved in the browser."
    [ -n "$expires_after" ] && echo "EXPIRES: this sign-in gives up ${expires_after} seconds after it started; the attendee must approve right away."
    echo "After the attendee approves it, run: bash ~/.workshop/auth.sh check $check_service"
    exit 0
fi

echo "NO LINK: the sign-in did not print a link within 30 seconds. Its output:"
printf '%s\n' "$clean" | tail -n 20
stop_previous
exit 1
