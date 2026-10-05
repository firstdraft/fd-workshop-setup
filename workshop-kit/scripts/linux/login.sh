#!/usr/bin/env bash
# login.sh
#
# Starts a sign-in that waits for the browser, without blocking Claude:
# the sign-in keeps running in the background, and this script prints its
# link (and one-time code, if any) as soon as it appears, then returns.
# It also opens the link in the default browser and copies it (or the code,
# if the page asks for one) to the clipboard (see platform.sh).
# Installed to ~/.workshop/login.sh by handoff.sh; used by the sign-in skill.
#
#   bash login.sh start <service>    github | github-refresh | render | neon | revyl
#                                    | firstdraft | firstdraft-device
#   bash login.sh stop <service>     cancel a sign-in that is still waiting
#   bash login.sh status <service>   is it still waiting, or did it finish / time out?
#   bash login.sh wait <service>     after the approval: give the sign-in up to 30
#                                    seconds to save, then run its auth.sh check
#
# Starting again cancels the previous attempt for that service, because its
# link no longer works once a new one is created.
# Set WORKSHOP_NO_OPEN=1 to skip opening the browser and the clipboard (for tests).

set -uo pipefail

. "$(dirname "${BASH_SOURCE[0]}")/platform.sh"

export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:$HOME/.revyl/bin:$PATH"
# Stop the CLIs from opening a browser themselves (most ignore this setting
# anyway, and the ones that do would open a second tab): this script opens
# the link instead, the same way for every service.
export BROWSER=/bin/false

# Terminal color codes are removed from the CLIs' output. A literal escape
# character, because older macOS sed does not read \x1b.
ESC=$(printf '\033')

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
    # The browser sends the approval back to a local address, which WSL does
    # not forward from Windows on some laptops, so the skill tries this second.
    firstdraft) command=(firstdraft login) ;;
    # Approve with a code instead (the skill's first choice): nothing has to
    # reach this laptop's local address from the browser.
    firstdraft-device) command=(firstdraft login --device) ;;
    *)
        echo "usage: login.sh start|stop|status|wait github|github-refresh|render|neon|revyl|firstdraft|firstdraft-device"
        exit 2 ;;
esac

log="$LOG_DIR/$service.log"
pid_file="$LOG_DIR/$service.pid"
# The auth.sh check for this service: github-refresh -> github, firstdraft-device -> firstdraft.
check_service=${service%-refresh}
check_service=${check_service%-device}

# Is the sign-in still running? An exited sign-in that nothing has reaped yet
# is a zombie, which kill -0 still reports as alive. WSL's init has left
# exited processes as zombies before (microsoft/WSL#4138). macOS has no
# /proc, so there the grep finds nothing; launchd reaps orphans anyway.
running() {
    [ -n "${1:-}" ] && kill -0 "$1" 2>/dev/null \
        && ! grep -qs '^State:[[:space:]]*Z' "/proc/$1/status"
}

stop_previous() {
    local pid
    pid=$(cat "$pid_file" 2>/dev/null) || return 0
    # The sign-in runs in its own process group (DETACH), so stop the whole group.
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
    if running "$pid"; then
        echo "WAITING: the $service sign-in is still waiting for approval in the browser"
    elif grep -qi 'timed out' "$log" 2>/dev/null; then
        echo "TIMED OUT: the $service sign-in gave up before it was approved; start it again"
    else
        echo "ENDED: the $service sign-in is no longer running. Its last output:"
        sed "s/$ESC\\[[0-9;]*[A-Za-z]//g" "$log" 2>/dev/null | tail -n 5
        echo "Run: bash ~/.workshop/auth.sh check $check_service"
    fi
    exit 0
fi
if [ "$action" = wait ]; then
    # A device sign-in saves its login on the CLI's next poll, a few seconds
    # after the approval, and then exits. Checking right away fails, and
    # starting again would cancel the sign-in that was about to succeed.
    pid=$(cat "$pid_file" 2>/dev/null)
    for _ in $(seq 1 60); do
        running "$pid" || break
        sleep 0.5
    done
    if running "$pid"; then
        echo "WAITING: the $service sign-in has not received the approval yet"
    fi
    exec bash "$(dirname "${BASH_SOURCE[0]}")/auth.sh" check "$check_service"
fi
[ "$action" = start ] || { echo "usage: login.sh start|stop|status|wait <service>"; exit 2; }

stop_previous
: > "$log"
"${DETACH[@]}" nohup "${command[@]}" </dev/null >"$log" 2>&1 &
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
    links=$(sed "s/$ESC\\[[0-9;]*[A-Za-z]//g" "$log" | grep -oE 'https://[^ "<>]+' \
        | sed 's/[.,;:)]*$//' | grep -vE '://docs\.')
    printf '%s\n' "$links" | grep -E '[?&](user_)?code=' | head -n 1 | grep . \
        || printf '%s\n' "$links" | awk '{ print length, $0 }' | sort -rn | head -n 1 | cut -d' ' -f2-
}

# Wait up to 30 seconds for a link, or for the command to finish by itself
# (for example "already signed in", or an error).
for _ in $(seq 1 60); do
    [ -n "$(find_link)" ] && break
    running "$pid" || break
    sleep 0.5
done
sleep 1   # let a one-time code printed just after the link arrive too

clean=$(sed "s/$ESC\\[[0-9;]*[A-Za-z]//g" "$log")

if ! running "$pid"; then
    rm -f "$pid_file"
    echo "FINISHED: the sign-in command exited without waiting for the browser. Its output:"
    printf '%s\n' "$clean" | tail -n 15
    echo "Run: bash ~/.workshop/auth.sh check $check_service"
    exit 0
fi

url=$(find_link)
# One-time codes: GitHub prints ABCD-1234, Render prints ABCD-EFGH-IJKL-MNOP.
code=$(printf '%s\n' "$clean" | grep -oE '\b[A-Z0-9]{4}(-[A-Z0-9]{4})+\b' | head -n 1)
if [ -n "$url" ]; then
    echo "URL: $url"
    [ -n "$code" ] && echo "CODE: $code"
    if [ "${WORKSHOP_NO_OPEN:-}" != 1 ]; then
        if [ -n "$opens_browser_itself" ]; then
            # Opening it here too would give the attendee two tabs.
            echo "OPENED: $service opened the sign-in page in the default browser itself"
        else
            open_link "$url" && echo "OPENED: the sign-in page in the default browser" \
                || echo "NOT OPENED: could not open the browser; the attendee must open the link"
        fi
        # Copy what the attendee needs to paste: the code if the link does not
        # already contain it (GitHub), otherwise the link.
        if [ -n "$code" ] && [[ "$url" != *"$code"* ]]; then
            copy_text "$code" && echo "COPIED: the code, ready to paste into the page"
        else
            copy_text "$url" && echo "COPIED: the link, ready to paste into a browser"
        fi
    fi
    echo "WAITING: the sign-in is running in the background until it is approved in the browser."
    [ -n "$expires_after" ] && echo "EXPIRES: this sign-in gives up ${expires_after} seconds after it started; the attendee must approve right away."
    echo "After the attendee approves it, run: bash ~/.workshop/login.sh wait $service"
    exit 0
fi

echo "NO LINK: the sign-in did not print a link within 30 seconds. Its output:"
printf '%s\n' "$clean" | tail -n 20
stop_previous
exit 1
