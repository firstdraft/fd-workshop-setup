#!/usr/bin/env bash
# configure.sh
#
# Configure phase: git identity and defaults, an SSH key, and GitHub's host
# key. Runs inside Ubuntu as appdev, piped in by configure.ps1. Uploading the
# SSH key to GitHub needs a GitHub login, so it happens in the Authenticate phase.
#
#   bash configure.sh check all        one line per item; exit code = number missing
#   bash configure.sh apply            name and email come from WORKSHOP_GIT_NAME
#                                      and WORKSHOP_GIT_EMAIL (passed in via WSLENV)

set -uo pipefail

ITEMS="git-identity git-defaults ssh-key github-host-key"

# GitHub's published ED25519 host key fingerprint:
# https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/githubs-ssh-key-fingerprints
GITHUB_ED25519_FINGERPRINT="SHA256:+DiY3wvvV6TuJJhbpZisF/zLDA0zPMSvHdkr4UvCOqU"

SSH_KEY="$HOME/.ssh/id_ed25519"
KNOWN_HOSTS="$HOME/.ssh/known_hosts"
export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:$PATH"
cd "$HOME"


check_git_identity() {
    local name email
    name=$(git config --global user.name) || { echo "name not set"; return 1; }
    email=$(git config --global user.email) || { echo "email not set"; return 1; }
    echo "$name <$email>"
}

check_git_defaults() {
    [ "$(git config --global init.defaultBranch)" = "main" ] || { echo "default branch is not main"; return 1; }
    [ "$(gh config get git_protocol 2>/dev/null)" = "ssh" ] || { echo "gh does not use SSH for git"; return 1; }
    echo "default branch main; gh uses SSH"
}

check_ssh_key() {
    [ -f "$SSH_KEY" ] && [ -f "$SSH_KEY.pub" ] || { echo "no key at ~/.ssh/id_ed25519"; return 1; }
    echo "$(ssh-keygen -lf "$SSH_KEY.pub" | awk '{print $2}')"
}

check_github_host_key() {
    ssh-keygen -F github.com -f "$KNOWN_HOSTS" >/dev/null 2>&1 || { echo "github.com not in known_hosts"; return 1; }
    echo "github.com trusted"
}


apply_git_identity() {
    local name=${WORKSHOP_GIT_NAME:-} email=${WORKSHOP_GIT_EMAIL:-}
    if [ -z "$name" ] || [ -z "$email" ]; then
        check_git_identity >/dev/null && return 0   # already set; nothing new given
        echo "name and email are required"; return 1
    fi
    git config --global user.name "$name"
    git config --global user.email "$email"
}

apply_git_defaults() {
    git config --global init.defaultBranch main
    gh config set git_protocol ssh
}

apply_ssh_key() {
    [ -f "$SSH_KEY" ] && return 0   # never replace an existing key
    install -d -m 700 "$HOME/.ssh"
    # No passphrase, so git never stops to ask for one.
    ssh-keygen -q -t ed25519 -N "" -C "$(git config --global user.email)" -f "$SSH_KEY"
}

apply_github_host_key() {
    local scanned fingerprint
    check_github_host_key >/dev/null && return 0
    scanned=$(ssh-keyscan -t ed25519 github.com 2>/dev/null)
    fingerprint=$(printf '%s\n' "$scanned" | ssh-keygen -lf - | awk '{print $2}')
    # Only trust the key if it matches the fingerprint GitHub publishes.
    if [ "$fingerprint" != "$GITHUB_ED25519_FINGERPRINT" ]; then
        echo "github.com key fingerprint '$fingerprint' does not match GitHub's published one"
        return 1
    fi
    install -d -m 700 "$HOME/.ssh"
    printf '%s\n' "$scanned" >> "$KNOWN_HOSTS"
    chmod 600 "$KNOWN_HOSTS"
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
        for item in $ITEMS; do
            # A subshell with -e so the first failing command stops this item.
            # (Not inside 'if': bash ignores -e in a condition.)
            (set -e; "apply_${item//-/_}")
            if [ $? -ne 0 ]; then
                echo "[FAIL] $item: could not be applied"
                exit 1
            fi
        done
        check_all
        ;;
    *)
        echo "usage: configure.sh check all | configure.sh apply"
        exit 2
        ;;
esac
