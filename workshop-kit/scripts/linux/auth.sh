#!/usr/bin/env bash
# auth.sh
#
# Authenticate phase: checks whether the attendee is signed in to each
# workshop service. Read-only; the workshop-signin skill does the signing in.
# Installed to ~/.workshop/auth.sh by handoff.sh.
#
#   bash auth.sh check all            one line per service; exit code = number missing
#   bash auth.sh check <service>

set -uo pipefail

. "$(dirname "${BASH_SOURCE[0]}")/platform.sh"

# No 'claude' check: the workshop runs in Claude Desktop, which handles its own
# sign-in. (The Claude Code CLI is installed too, as a fallback; 'claude auth
# status' shows whether it is signed in.)
SERVICES="github git-identity github-ssh-key render render-workspace neon cloudinary revyl firstdraft"

export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:$HOME/.revyl/bin:$PATH"
# Checks must never open a browser to start a sign-in.
export BROWSER=/bin/false
cd "$HOME"


check_github() {
    local login
    login=$(gh api user --jq .login 2>/dev/null) || { echo "not signed in"; return 1; }
    echo "signed in as $login"
}

check_github_ssh_key() {
    local reply
    # GitHub replies "Hi <user>! You've successfully authenticated" (with exit code 1).
    reply=$(ssh -o BatchMode=yes -o ConnectTimeout=10 -T git@github.com 2>&1)
    case "$reply" in
        *"successfully authenticated"*) echo "accepted by GitHub" ;;
        *) echo "not uploaded to GitHub yet"; return 1 ;;
    esac
}

check_git_identity() {
    # git must use the GitHub account's private no-reply address (set by
    # git-identity.sh), so commits link to the account without a real email.
    local name email expected
    expected=$(gh api user --jq '"\(.id)+\(.login)@users.noreply.github.com"' 2>/dev/null) \
        || { echo "needs GitHub sign-in first"; return 1; }
    if [ "$WORKSHOP_PLATFORM" = mac ] \
        && [ "$(git config --global --get 'includeIf.gitdir:~/workshop/.path')" != '~/.workshop/gitconfig' ]; then
        echo "not applied to ~/workshop"; return 1
    fi
    name=$(git config "${GIT_IDENTITY[@]}" user.name) || { echo "git name not set"; return 1; }
    email=$(git config "${GIT_IDENTITY[@]}" user.email) || { echo "git email not set"; return 1; }
    [ "$email" = "$expected" ] || { echo "git email is '$email', not the account's no-reply address"; return 1; }
    echo "$name <$email>"
}

check_render() {
    render whoami --output text >/dev/null 2>&1 || { echo "not signed in"; return 1; }
    echo "signed in"
}

check_render_workspace() {
    # 'render login' does not choose a workspace; render-workspace.sh does.
    local current
    current=$(render workspace current --output text </dev/null 2>/dev/null) || { echo "no workspace set"; return 1; }
    echo "${current#Active Workspace: }"
}

check_neon() {
    # 'neonctl me' starts a browser sign-in when signed out, so only ask it
    # when saved credentials exist, and never let it wait.
    [ -s "$HOME/.config/neon/credentials.json" ] || { echo "not signed in"; return 1; }
    run_with_timeout 20 neonctl me --output json </dev/null >/dev/null 2>&1 || { echo "sign-in expired"; return 1; }
    echo "signed in"
}

check_cloudinary() {
    # Cloudinary has no CLI sign-in: the skill saves its key from the
    # clipboard with cloudinary.sh, and this checks the saved file's shape
    # without printing it.
    [ -f "$HOME/.workshop/cloudinary.sh" ] || { echo "helper not installed (run the handoff again)"; return 1; }
    bash "$HOME/.workshop/cloudinary.sh" check
}

check_revyl() {
    local status
    # 'revyl auth status' exits 0 even when signed out, so read what it says.
    status=$(revyl auth status 2>&1) || { echo "not signed in"; return 1; }
    case "$status" in
        *"Not authenticated"*) echo "not signed in"; return 1 ;;
    esac
    echo "signed in"
}

check_firstdraft() {
    # The CLI has no status command; 'firstdraft login' saves a token per
    # origin in this file (the token itself is never printed).
    local credentials="${XDG_CONFIG_HOME:-$HOME/.config}/firstdraft/credentials.json"
    grep -qF 'https://firstdraft.com' "$credentials" 2>/dev/null || { echo "not signed in"; return 1; }
    echo "signed in"
}


run_check() {
    local service=$1 detail
    if detail=$("check_${service//-/_}" 2>&1); then
        echo "[PASS] $service: $detail"
        return 0
    fi
    echo "[FAIL] $service: $detail"
    return 1
}

case "${1:-}" in
    check)
        if [ "${2:-all}" = all ]; then
            missing=0
            for service in $SERVICES; do
                run_check "$service" || missing=$((missing + 1))
            done
            exit "$missing"
        fi
        run_check "$2"
        ;;
    *)
        echo "usage: auth.sh check all|<service>"
        exit 2
        ;;
esac
