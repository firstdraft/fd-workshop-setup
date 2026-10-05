#!/usr/bin/env bash
# setup.sh
#
# The Mac setup: the steps the Windows .ps1 scripts take, for a Mac. It runs
# the same scripts/linux/*.sh phases (tools, configure, verify, handoff),
# which install with Homebrew on a Mac. Runs as the attendee, under macOS's
# bash 3.2. Every step is safe to run again.
#
#   bash scripts/mac/setup.sh status             read-only: every check and the NEXT STEP
#   bash scripts/mac/setup.sh install-homebrew   Homebrew and the Command Line Tools, in a
#                                                Terminal window where the attendee types
#                                                their Mac password (waits up to 30 minutes)
#   bash scripts/mac/setup.sh install-tools      the rest of tools.sh, one component at a time
#   bash scripts/mac/setup.sh configure          git defaults, SSH key, GitHub's host key
#   bash scripts/mac/setup.sh verify             final check: RESULT: READY / NOT READY
#   bash scripts/mac/setup.sh handoff <name>     ~/workshop/<name>, the sign-in skill, the notes

set -uo pipefail

KIT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
LINUX="$KIT_DIR/scripts/linux"
LOG_DIR="$KIT_DIR/logs"
MINIMUM_FREE_GB=10   # the same as the Windows kit
mkdir -p "$LOG_DIR"

# Components that need the attendee at the keyboard (install-homebrew).
INTERACTIVE="xcode-clt homebrew"

stamp() { date +%Y%m%d-%H%M%S; }

# Runs '<script> check all' and prints its [PASS]/[FAIL] lines.
checks() {
    bash "$LINUX/$1" check all 2>&1 | grep -E '^\[(PASS|FAIL)\] '
}

# Prints the names of the [FAIL] items in checks output.
failed() {
    grep '^\[FAIL\]' | sed -E 's/^\[FAIL\] ([a-z-]+):.*/\1/'
}

is_admin() {
    id -Gn | tr ' ' '\n' | grep -qx admin
}

status() {
    local tools configure="" handoff="" failing next free_gb
    echo "=== Mac setup status ==="
    echo "[INFO] macOS $(sw_vers -productVersion), $(uname -m)"
    free_gb=$(( $(df -Pk "$HOME" | awk 'NR==2 {print $4}') / 1048576 ))
    if [ "$free_gb" -ge "$MINIMUM_FREE_GB" ]; then
        echo "[PASS] disk: $free_gb GB free (need $MINIMUM_FREE_GB GB)"
    else
        echo "[FAIL] disk: $free_gb GB free (need $MINIMUM_FREE_GB GB)"
    fi
    if is_admin; then echo "[PASS] admin: $USER is an administrator"; else echo "[INFO] admin: $USER is not an administrator"; fi

    echo ""
    echo "=== Development tools ==="
    tools=$(checks tools.sh)
    printf '%s\n' "$tools"
    failing=$(printf '%s\n' "$tools" | failed | tr '\n' ' ')

    # Without the Command Line Tools, git and python3 open Apple's install
    # dialog, so the later phases are checked only once they are there.
    case " $failing " in
        *" xcode-clt "*) ;;
        *)
            echo ""
            echo "=== Git and SSH ==="
            configure=$(checks configure.sh)
            printf '%s\n' "$configure"
            echo ""
            echo "=== Handoff ==="
            handoff=$(checks handoff.sh)
            printf '%s\n' "$handoff"
            ;;
    esac

    if [ "$free_gb" -lt "$MINIMUM_FREE_GB" ]; then
        next=STOP_LOW_DISK
    elif [[ " $failing " == *" xcode-clt "* || " $failing " == *" homebrew "* ]]; then
        # Installing them takes an administrator's password; adding an
        # installed Homebrew to PATH does not.
        if is_admin || [[ " $failing " != *" xcode-clt "* && "$tools" != *"[FAIL] homebrew: not installed"* ]]; then
            next=INSTALL_HOMEBREW
        else
            next=STOP_NOT_ADMIN
        fi
    elif [ -n "${failing// /}" ]; then
        next=INSTALL_TOOLS
    elif [ -n "$(printf '%s\n' "$configure" | failed)" ]; then
        next=CONFIGURE
    elif [ -n "$(printf '%s\n' "$handoff" | failed)" ]; then
        next=HANDOFF
    else
        next=DONE
    fi

    echo ""
    echo "NEXT STEP: $next"
    case "$next" in
        INSTALL_HOMEBREW) echo "COMMAND:   bash scripts/mac/setup.sh install-homebrew" ;;
        INSTALL_TOOLS) echo "COMMAND:   bash scripts/mac/setup.sh install-tools" ;;
        CONFIGURE) echo "COMMAND:   bash scripts/mac/setup.sh configure" ;;
        HANDOFF) echo "COMMAND:   bash scripts/mac/setup.sh verify, then bash scripts/mac/setup.sh handoff <app name>" ;;
        DONE) echo "COMMAND:   (none: the attendee continues in a new Local session; see DONE in CLAUDE.md)" ;;
    esac
}

install_homebrew() {
    local component
    echo "=== Installing Homebrew and Apple's Command Line Tools ==="
    for component in homebrew xcode-clt; do
        if ! bash "$LINUX/tools.sh" check "$component" >/dev/null 2>&1; then
            bash "$LINUX/tools.sh" install "$component" 2>&1 | tee "$LOG_DIR/tools-$component-$(stamp).log"
            [ "${PIPESTATUS[0]}" -eq 0 ] || { echo ""; echo "STOPPED: $component is not installed (see above)."; return 1; }
        fi
        bash "$LINUX/tools.sh" check "$component"
    done
    echo ""
    echo "DONE: Homebrew and the Command Line Tools are installed. Next: run setup.sh status."
}

install_tools() {
    local line name log
    echo "=== Installing development tools ==="
    while IFS= read -r line; do
        name=$(printf '%s\n' "$line" | sed -E 's/^\[(PASS|FAIL)\] ([a-z-]+):.*/\2/')
        case "$line" in
            "[PASS]"*) echo "$line"; continue ;;
        esac
        case " $INTERACTIVE " in
            *" $name "*)
                echo "[FAIL] $name: run setup.sh install-homebrew first"
                return 1 ;;
        esac
        echo "Installing $name ($(date +%H:%M:%S)) ..."
        log="$LOG_DIR/tools-$name-$(stamp).log"
        bash "$LINUX/tools.sh" install "$name" </dev/null >"$log" 2>&1
        if [ $? -ne 0 ]; then
            tail -n 25 "$log"
            echo ""
            echo "STOPPED: $name failed. Full output is in logs/. Run this step again to retry."
            return 1
        fi
        # tools.sh ends with this component's [PASS] line, but installers' error
        # output can come after normal output, so find the line.
        grep -E "^\[(PASS|FAIL)\] $name:" "$log" | tail -n 1
    done <<EOF
$(checks tools.sh)
EOF
    echo ""
    echo "DONE: all development tools are installed. Next: run setup.sh status."
}

configure() {
    echo "=== Configuring git and SSH ==="
    bash "$LINUX/configure.sh" apply || { echo ""; echo "STOPPED: configuration is not complete (see [FAIL] above)."; return 1; }
    echo ""
    echo "DONE: git and SSH are configured. Next: run setup.sh status."
}

verify() {
    local failures=0 log
    log="$LOG_DIR/verify-$(stamp).txt"
    {
        echo "=== This Mac ==="
        bash "$LINUX/verify.sh" || failures=$((failures + 1))
        echo ""
        echo "=== Development tools ==="
        checks tools.sh
        echo ""
        echo "=== Git and SSH ==="
        checks configure.sh
    } > "$log" 2>&1
    grep -q '^\[FAIL\]' "$log" && failures=$((failures + 1))
    echo "" >> "$log"
    if [ "$failures" -eq 0 ]; then echo "RESULT: READY" >> "$log"; else echo "RESULT: NOT READY" >> "$log"; fi
    cat "$log"
    [ "$failures" -eq 0 ]
}

handoff() {
    local name
    name=${1:-}
    name=${name#"${name%%[![:space:]]*}"}
    name=${name%"${name##*[![:space:]]}"}
    echo "=== Preparing this Mac for the workshop ==="
    if [ -z "$name" ]; then
        echo "ASK: what the attendee wants to call their app (default: firstdraft-workshop)."
        return 40
    fi
    if ! printf '%s' "$name" | grep -qE '^[a-z][a-z0-9-]{0,49}$'; then
        echo "[FAIL] '$name' is not a valid app name. Use lowercase letters, numbers and dashes, starting with a letter (e.g. my-first-app)."
        return 41
    fi
    WORKSHOP_APP_NAME=$name WORKSHOP_KIT_DIR=$KIT_DIR bash "$LINUX/handoff.sh" apply \
        || { echo ""; echo "STOPPED: the handoff is not complete (see [FAIL] above)."; return 1; }
    echo ""
    echo "DONE: ~/workshop/$name is ready. The attendee now quits and reopens Claude Desktop, then opens a Local session:"
    echo "  New session > Local > folder $HOME/workshop/$name > Trust > type /workshop-signin"
}

case "${1:-}" in
    status) status ;;
    install-homebrew) install_homebrew ;;
    install-tools) install_tools ;;
    configure) configure ;;
    verify) verify ;;
    handoff) handoff "${2:-}" ;;
    *)
        echo "usage: setup.sh status | install-homebrew | install-tools | configure | verify | handoff <app name>"
        exit 2
        ;;
esac
