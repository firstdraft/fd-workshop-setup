#!/usr/bin/env bash
# git-identity.sh
#
# Sets git's name and email from the signed-in GitHub account: the account's
# name (or its username, if no name is set) and its private no-reply address,
# <id>+<username>@users.noreply.github.com, so commits link to the account
# without exposing a real email. Run after the GitHub sign-in.
# Installed to ~/.workshop/git-identity.sh by handoff.sh; used by the
# workshop-signin skill.
#
#   bash git-identity.sh

set -uo pipefail

identity=$(gh api user --jq '"\(if (.name // "") == "" then .login else .name end)\t\(.id)+\(.login)@users.noreply.github.com"' 2>/dev/null) \
    || { echo "[FAIL] git-identity: not signed in to GitHub yet"; exit 1; }
name=${identity%%$'\t'*}
email=${identity#*$'\t'}

git config --global user.name "$name"
git config --global user.email "$email"
echo "[PASS] git-identity: $name <$email>"
