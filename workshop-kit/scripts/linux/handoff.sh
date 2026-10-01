#!/usr/bin/env bash
# handoff.sh
#
# Hands the attendee over from Claude Desktop to Claude Code in Ubuntu.
# Runs inside Ubuntu as appdev, piped in by handoff.ps1. It:
#   - creates the app folder ~/<app name>
#   - installs the workshop plugin (the sign-in skill) to ~/.workshop/plugin
#   - installs the sign-in checks to ~/.workshop/auth.sh and the sign-in
#     helper to ~/.workshop/login.sh
#   - installs the 'workshop' command, which runs the sign-in session until
#     every sign-in passes, then starts Claude Code with the First Draft plugin
#   - makes the next Ubuntu terminal start 'workshop' by itself (once)
#
#   bash handoff.sh check all
#   bash handoff.sh apply     app name from WORKSHOP_APP_NAME, kit folder from
#                             WORKSHOP_KIT_DIR (both passed in via WSLENV)

set -uo pipefail

ITEMS="app-folder plugin auth-checks login-helper launcher autostart-hook"

WORKSHOP_DIR="$HOME/.workshop"
LAUNCHER="$HOME/.local/bin/workshop"
AUTOSTART_LINE='[ -f "$HOME/.workshop/autostart" ] && rm -f "$HOME/.workshop/autostart" && "$HOME/.local/bin/workshop"'
cd "$HOME"


check_app_folder() {
    local dir
    dir=$(cat "$WORKSHOP_DIR/app-dir" 2>/dev/null) || { echo "no app chosen yet"; return 1; }
    [ -d "$dir" ] || { echo "$dir does not exist"; return 1; }
    echo "$dir"
}

check_plugin() {
    [ -f "$WORKSHOP_DIR/plugin/.claude-plugin/plugin.json" ] && [ -f "$WORKSHOP_DIR/plugin/skills/auth/SKILL.md" ] \
        || { echo "not installed"; return 1; }
    echo "$WORKSHOP_DIR/plugin"
}

check_auth_checks() {
    [ -f "$WORKSHOP_DIR/auth.sh" ] || { echo "not installed"; return 1; }
    echo "$WORKSHOP_DIR/auth.sh"
}

check_login_helper() {
    [ -f "$WORKSHOP_DIR/login.sh" ] || { echo "not installed"; return 1; }
    echo "$WORKSHOP_DIR/login.sh"
}

check_launcher() {
    [ -x "$LAUNCHER" ] || { echo "not installed"; return 1; }
    echo "$LAUNCHER"
}

check_autostart_hook() {
    grep -qxF "$AUTOSTART_LINE" "$HOME/.bashrc" || { echo "not in ~/.bashrc"; return 1; }
    echo "in ~/.bashrc"
}


# Copies a file or folder from the kit, removing Windows line endings.
copy_from_kit() {
    local source=$1 target=$2
    rm -rf "$target"
    cp -r "$source" "$target"
    find "$target" -type f \( -name '*.sh' -o -name '*.md' -o -name '*.json' \) -exec sed -i 's/\r$//' {} +
}

apply_all() {
    local name=${WORKSHOP_APP_NAME:-} kit=${WORKSHOP_KIT_DIR:-}
    if ! printf '%s' "$name" | grep -qE '^[a-z][a-z0-9-]{0,49}$'; then
        echo "[FAIL] app name '$name' must be lowercase letters, numbers and dashes, starting with a letter"
        return 1
    fi
    [ -d "$kit/workshop-plugin" ] || { echo "[FAIL] kit folder not found: '$kit'"; return 1; }

    mkdir -p "$HOME/$name" "$WORKSHOP_DIR" "$HOME/.local/bin"
    printf '%s\n' "$HOME/$name" > "$WORKSHOP_DIR/app-dir"

    copy_from_kit "$kit/workshop-plugin" "$WORKSHOP_DIR/plugin"
    copy_from_kit "$kit/scripts/linux/auth.sh" "$WORKSHOP_DIR/auth.sh"
    copy_from_kit "$kit/scripts/linux/login.sh" "$WORKSHOP_DIR/login.sh"

    cat > "$LAUNCHER" <<'EOF'
#!/usr/bin/env bash
# workshop: starts Claude Code for the workshop.
# Until every sign-in passes, it starts a sign-in session (workshop plugin).
# Then it starts Claude Code in the app folder with the First Draft plugin.

export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:$HOME/.revyl/bin:$PATH"
app_dir=$(cat "$HOME/.workshop/app-dir")
cd "$app_dir" || exit 1

echo "Checking your sign-ins ..."
if ! bash "$HOME/.workshop/auth.sh" check all >/dev/null 2>&1; then
    echo "Starting Claude to sign you in to the workshop tools ..."
    claude --plugin-dir "$HOME/.workshop/plugin" "/workshop:auth"

    echo "Checking your sign-ins ..."
    if ! bash "$HOME/.workshop/auth.sh" check all; then
        echo ""
        echo "Some sign-ins are not finished yet. Type  workshop  and press Enter to continue."
        exit 1
    fi
    echo ""
    echo "All signed in. Starting a fresh Claude session for your app ..."
fi

exec claude --plugin-dir "$(npm root --global)/@firstdraft.com/claude-code"
EOF
    chmod +x "$LAUNCHER"

    if ! grep -qxF "$AUTOSTART_LINE" "$HOME/.bashrc"; then
        printf '\n# Added by workshop setup: start the workshop once when asked to\n%s\n' "$AUTOSTART_LINE" >> "$HOME/.bashrc"
    fi
}


run_check() {
    local item=$1 detail
    if detail=$("check_${item//-/_}" 2>&1); then
        echo "[PASS] $item: $detail"
        return 0
    fi
    echo "[FAIL] $item: $detail"
    return 1
}

check_all() {
    local missing=0 item
    for item in $ITEMS; do
        run_check "$item" || missing=$((missing + 1))
    done
    return "$missing"
}

case "${1:-}" in
    check)
        check_all
        ;;
    apply)
        # A subshell with -e so the first failing command stops. (Not inside
        # 'if': bash ignores -e in a condition.)
        (set -e; apply_all)
        if [ $? -ne 0 ]; then
            echo "[FAIL] handoff could not be completed"
            exit 1
        fi
        check_all
        ;;
    *)
        echo "usage: handoff.sh check all | handoff.sh apply"
        exit 2
        ;;
esac
