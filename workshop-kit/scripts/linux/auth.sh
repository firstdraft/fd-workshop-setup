#!/usr/bin/env bash
# auth.sh
#
# Authenticate phase: checks whether the attendee is signed in to each
# workshop service. Read-only; the workshop:auth skill does the signing in.
# Installed to ~/.workshop/auth.sh by handoff.sh and used by the 'workshop'
# launcher to decide which Claude session to start.
#
#   bash auth.sh check all            one line per service; exit code = number missing
#   bash auth.sh check <service>

set -uo pipefail

SERVICES="claude github github-ssh-key git-email render neon revyl firstdraft"

export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:$HOME/.revyl/bin:$PATH"
# Checks must never open a browser to start a sign-in.
export BROWSER=/bin/false
cd "$HOME"


check_claude() {
    claude auth status 2>/dev/null | grep -q '"loggedIn": *true' || { echo "not signed in"; return 1; }
    echo "signed in"
}

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

check_git_email() {
    local email login verified
    email=$(git config --global user.email) || { echo "git email not set"; return 1; }
    login=$(gh api user --jq .login 2>/dev/null) || { echo "needs GitHub sign-in first"; return 1; }
    case "$email" in
        *"+$login@users.noreply.github.com") echo "$email (GitHub no-reply address)"; return 0 ;;
    esac
    verified=$(gh api user/emails --jq '.[] | select(.verified) | .email' 2>/dev/null) \
        || { echo "cannot read GitHub emails (sign-in lacks the user:email permission)"; return 1; }
    printf '%s\n' "$verified" | grep -qixF "$email" || { echo "$email is not a verified email on GitHub account $login"; return 1; }
    echo "$email is verified on $login"
}

check_render() {
    render whoami --output text >/dev/null 2>&1 || { echo "not signed in"; return 1; }
    echo "signed in"
}

check_neon() {
    # 'neonctl me' starts a browser sign-in when signed out, so only ask it
    # when saved credentials exist, and never let it wait.
    [ -s "$HOME/.config/neon/credentials.json" ] || { echo "not signed in"; return 1; }
    timeout 20 neonctl me --output json </dev/null >/dev/null 2>&1 || { echo "sign-in expired"; return 1; }
    echo "signed in"
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
