#!/usr/bin/env bash
# git-identity.sh
#
# Sets git's name and email from the signed-in GitHub account: the account's
# name (or its username, if no name is set) and its private no-reply address,
# <id>+<username>@users.noreply.github.com, so commits link to the account
# without exposing a real email. Run after the GitHub sign-in. On a Mac
# they apply only to repositories in the projects folder (see platform.sh).
# Installed to ~/.workshop/git-identity.sh by handoff.sh; used by the
# workshop-signin skill.
#
#   bash git-identity.sh

set -uo pipefail

. "$(dirname "${BASH_SOURCE[0]}")/platform.sh"

identity=$(gh api user --jq '"\(if (.name // "") == "" then .login else .name end)\t\(.id)+\(.login)@users.noreply.github.com"' 2>/dev/null) \
    || { echo "[FAIL] git-identity: not signed in to GitHub yet"; exit 1; }
name=${identity%%$'\t'*}
email=${identity#*$'\t'}

git config "${GIT_IDENTITY[@]}" user.name "$name"
git config "${GIT_IDENTITY[@]}" user.email "$email"
if [ "$WORKSHOP_PLATFORM" = mac ]; then
    git config --global "$GIT_INCLUDE" '~/.workshop/gitconfig'
    echo "[PASS] git-identity: $name <$email>, for repositories in $APPS_DIR"
else
    echo "[PASS] git-identity: $name <$email>"
fi
