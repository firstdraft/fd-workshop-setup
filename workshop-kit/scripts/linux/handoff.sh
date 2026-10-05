#!/usr/bin/env bash
# handoff.sh
#
# Gets the laptop ready for the rest of the workshop, which happens in a
# Claude Desktop session running inside Ubuntu (WSL) on Windows, or in a
# Local session on a Mac. Runs inside Ubuntu as appdev, piped in by
# handoff.ps1, or on a Mac as the attendee, from scripts/mac/setup.sh. It:
#   - creates the app folder ~/<app name> (~/workshop/<app name> on a Mac)
#   - installs the platform layer to ~/.workshop/platform.sh, the link
#     opener to ~/.workshop/open.sh, the sign-in checks to ~/.workshop/auth.sh, the sign-in helper
#     to ~/.workshop/login.sh, ~/.workshop/git-identity.sh (sets git's
#     name and email from the GitHub account),
#     ~/.workshop/render-workspace.sh (sets the Render CLI's workspace) and
#     ~/.workshop/cloudinary.sh (saves the Cloudinary key, puts it in apps)
#   - installs the sign-in skill to ~/.claude/skills/workshop-signin (it only
#     loads when the attendee types /workshop-signin)
#   - links the First Draft skill from the npm package into ~/.claude/skills,
#     so the WSL session has it without installing the plugin
#   - adds the workshop's notes for app sessions (native preview, deploys) to
#     ~/.claude/CLAUDE.md, which every Claude session in Ubuntu loads. On a
#     Mac, the attendee's own account, they go in ~/workshop/CLAUDE.md
#     instead, which Claude loads in every folder under ~/workshop.
#   - starts Claude sessions in auto mode (on a Mac, only if the attendee has
#     not chosen a default mode)
#   - removes what an earlier version of the kit installed for the terminal
#     flow (the 'workshop' launcher, its plugin and its ~/.bashrc line; WSL only)
#
#   bash handoff.sh check all
#   bash handoff.sh apply     app name from WORKSHOP_APP_NAME, kit folder from
#                             WORKSHOP_KIT_DIR (on Windows, both passed in via WSLENV)

set -uo pipefail

ITEMS="app-folder platform-layer open-helper auth-checks login-helper git-identity-helper render-workspace-helper cloudinary-helper signin-skill firstdraft-skill app-instructions auto-mode"

WORKSHOP_DIR="$HOME/.workshop"
SKILLS_DIR="$HOME/.claude/skills"
CLAUDE_SETTINGS="$HOME/.claude/settings.json"
if [ "$(uname -s)" = Darwin ]; then
    MAC=1
    APPS_DIR="$HOME/workshop"
    CLAUDE_MD="$APPS_DIR/CLAUDE.md"
else
    MAC=""
    APPS_DIR="$HOME"
    CLAUDE_MD="$HOME/.claude/CLAUDE.md"
fi
# The workshop's block in CLAUDE_MD sits between these lines, so a re-run
# replaces it and leaves anything else in the file alone.
BLOCK_START='<!-- workshop-kit: start -->'
BLOCK_END='<!-- workshop-kit: end -->'
CR=$(printf '\r')   # older macOS sed does not read \r
export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:$PATH"
cd "$HOME"


check_app_folder() {
    local dir
    dir=$(cat "$WORKSHOP_DIR/app-dir" 2>/dev/null) || { echo "no app chosen yet"; return 1; }
    [ -d "$dir" ] || { echo "$dir does not exist"; return 1; }
    echo "$dir"
}

check_platform_layer() {
    [ -f "$WORKSHOP_DIR/platform.sh" ] || { echo "not installed"; return 1; }
    echo "$WORKSHOP_DIR/platform.sh"
}

check_open_helper() {
    [ -f "$WORKSHOP_DIR/open.sh" ] || { echo "not installed"; return 1; }
    echo "$WORKSHOP_DIR/open.sh"
}

check_auth_checks() {
    [ -f "$WORKSHOP_DIR/auth.sh" ] || { echo "not installed"; return 1; }
    echo "$WORKSHOP_DIR/auth.sh"
}

check_login_helper() {
    [ -f "$WORKSHOP_DIR/login.sh" ] || { echo "not installed"; return 1; }
    echo "$WORKSHOP_DIR/login.sh"
}

check_git_identity_helper() {
    [ -f "$WORKSHOP_DIR/git-identity.sh" ] || { echo "not installed"; return 1; }
    echo "$WORKSHOP_DIR/git-identity.sh"
}

check_render_workspace_helper() {
    [ -f "$WORKSHOP_DIR/render-workspace.sh" ] || { echo "not installed"; return 1; }
    echo "$WORKSHOP_DIR/render-workspace.sh"
}

check_cloudinary_helper() {
    [ -f "$WORKSHOP_DIR/cloudinary.sh" ] || { echo "not installed"; return 1; }
    echo "$WORKSHOP_DIR/cloudinary.sh"
}

check_signin_skill() {
    [ -f "$SKILLS_DIR/workshop-signin/SKILL.md" ] || { echo "not installed"; return 1; }
    echo "/workshop-signin"
}

check_firstdraft_skill() {
    # A link into the npm package: it breaks if Node is reinstalled elsewhere.
    [ -f "$SKILLS_DIR/create-full-stack-app/SKILL.md" ] || { echo "not linked (or the link is broken)"; return 1; }
    echo "create-full-stack-app"
}

check_app_instructions() {
    grep -qxF "$BLOCK_START" "$CLAUDE_MD" 2>/dev/null || { echo "not in $CLAUDE_MD"; return 1; }
    echo "$CLAUDE_MD"
}

check_auto_mode() {
    if [ -n "$MAC" ]; then
        check_default_mode_mac
        return
    fi
    python3 -c 'import json, sys; sys.exit(json.load(open(sys.argv[1])).get("permissions", {}).get("defaultMode") != "auto")' \
        "$CLAUDE_SETTINGS" 2>/dev/null || { echo "defaultMode is not auto in $CLAUDE_SETTINGS"; return 1; }
    echo "auto"
}


# On a Mac, any default mode the attendee chose counts: the handoff keeps it.
check_default_mode_mac() {
    local mode
    mode=$(python3 -c 'import json, sys; print(json.load(open(sys.argv[1])).get("permissions", {}).get("defaultMode", ""))' \
        "$CLAUDE_SETTINGS" 2>/dev/null)
    [ -n "$mode" ] || { echo "no defaultMode in $CLAUDE_SETTINGS"; return 1; }
    echo "$mode"
}

# Edits a file in place with sed; macOS's sed needs an empty backup suffix.
sed_in_place() {
    if [ -n "$MAC" ]; then sed -i '' "$@"; else sed -i "$@"; fi
}

# Copies a file or folder from the kit, removing Windows line endings.
copy_from_kit() {
    local source=$1 target=$2
    rm -rf "$target"
    cp -r "$source" "$target"
    find "$target" -type f \( -name '*.sh' -o -name '*.md' -o -name '*.json' \) -print0 \
        | while IFS= read -r -d '' file; do sed_in_place "s/$CR\$//" "$file"; done
}

# Writes the kit's notes for app sessions into ~/.claude/CLAUDE.md, replacing
# the block an earlier run added.
install_app_instructions() {
    local source=$1
    touch "$CLAUDE_MD"
    sed_in_place "/^$BLOCK_START\$/,/^$BLOCK_END\$/d" "$CLAUDE_MD"
    # Start on a new line if the file does not end with one.
    if [ -s "$CLAUDE_MD" ] && [ -n "$(tail -c 1 "$CLAUDE_MD")" ]; then
        echo >> "$CLAUDE_MD"
    fi
    { echo "$BLOCK_START"; sed "s/$CR\$//" "$source"; echo "$BLOCK_END"; } >> "$CLAUDE_MD"
}

# Starts every Claude session in Ubuntu in auto mode, which approves routine
# commands and still asks before risky ones, so attendees are not asked to
# approve each step. Keeps any other settings already in the file. On a Mac
# this file is the attendee's own: a default mode they chose stays.
# (Project settings cannot start sessions in auto mode, and the docs do not
# say Desktop's Local sessions start in it by themselves.)
set_auto_mode() {
    mkdir -p "$(dirname "$CLAUDE_SETTINGS")"
    WORKSHOP_KEEP_MODE=$MAC python3 - "$CLAUDE_SETTINGS" <<'PY'
import json, os, sys
path = sys.argv[1]
settings = json.load(open(path)) if os.path.exists(path) and os.path.getsize(path) else {}
permissions = settings.setdefault("permissions", {})
if not (os.environ.get("WORKSHOP_KEEP_MODE") and permissions.get("defaultMode")):
    permissions["defaultMode"] = "auto"
with open(path, "w") as file:
    json.dump(settings, file, indent=2)
    file.write("\n")
PY
}

remove_terminal_flow() {
    local autostart_line='[ -f "$HOME/.workshop/autostart" ] && rm -f "$HOME/.workshop/autostart" && "$HOME/.local/bin/workshop"'
    local comment_line='# Added by workshop setup: start the workshop once when asked to'
    rm -rf "$WORKSHOP_DIR/plugin" "$WORKSHOP_DIR/autostart" "$HOME/.local/bin/workshop"
    if grep -qxF "$autostart_line" "$HOME/.bashrc"; then
        grep -vxF -e "$autostart_line" -e "$comment_line" "$HOME/.bashrc" > "$HOME/.bashrc.workshop-tmp"
        mv "$HOME/.bashrc.workshop-tmp" "$HOME/.bashrc"
    fi
}

apply_all() {
    local name=${WORKSHOP_APP_NAME:-} kit=${WORKSHOP_KIT_DIR:-} firstdraft_skill
    if ! printf '%s' "$name" | grep -qE '^[a-z][a-z0-9-]{0,49}$'; then
        echo "[FAIL] app name '$name' must be lowercase letters, numbers and dashes, starting with a letter"
        return 1
    fi
    [ -d "$kit/skills/workshop-signin" ] || { echo "[FAIL] kit folder not found: '$kit'"; return 1; }
    firstdraft_skill="$(npm root --global)/@firstdraft.com/claude-code/skills/create-full-stack-app"
    [ -f "$firstdraft_skill/SKILL.md" ] || { echo "[FAIL] First Draft skill not found at $firstdraft_skill"; return 1; }

    mkdir -p "$APPS_DIR/$name" "$WORKSHOP_DIR" "$SKILLS_DIR"
    printf '%s\n' "$APPS_DIR/$name" > "$WORKSHOP_DIR/app-dir"

    copy_from_kit "$kit/scripts/linux/platform.sh" "$WORKSHOP_DIR/platform.sh"
    copy_from_kit "$kit/scripts/linux/open.sh" "$WORKSHOP_DIR/open.sh"
    copy_from_kit "$kit/scripts/linux/auth.sh" "$WORKSHOP_DIR/auth.sh"
    copy_from_kit "$kit/scripts/linux/login.sh" "$WORKSHOP_DIR/login.sh"
    copy_from_kit "$kit/scripts/linux/git-identity.sh" "$WORKSHOP_DIR/git-identity.sh"
    copy_from_kit "$kit/scripts/linux/render-workspace.sh" "$WORKSHOP_DIR/render-workspace.sh"
    copy_from_kit "$kit/scripts/linux/cloudinary.sh" "$WORKSHOP_DIR/cloudinary.sh"
    copy_from_kit "$kit/skills/workshop-signin" "$SKILLS_DIR/workshop-signin"
    ln -sfn "$firstdraft_skill" "$SKILLS_DIR/create-full-stack-app"
    install_app_instructions "$kit/scripts/linux/app-instructions.md"
    set_auto_mode

    [ -n "$MAC" ] || remove_terminal_flow
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
