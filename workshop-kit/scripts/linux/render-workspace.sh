#!/usr/bin/env bash
# render-workspace.sh
#
# Sets the Render CLI's workspace after the Render sign-in. 'render login'
# does not choose one, and most render commands then stop with "no workspace
# set". Keeps a workspace that is already set; otherwise sets the account's
# only workspace, or lists them (ASK) when there are several. Any workspace
# makes the CLI usable: before each app's first deploy, the app-session notes
# have the attendee create a workspace for that app and set it.
# Installed to ~/.workshop/render-workspace.sh by handoff.sh; used by the
# workshop-signin skill.
#
#   bash render-workspace.sh            keep the workspace, or set the only one
#   bash render-workspace.sh <ID>       set the workspace the attendee chose

set -uo pipefail

export PATH="$HOME/.local/bin:$PATH"

choice=${1:-}
if [ -z "$choice" ]; then
    if current=$(render workspace current --output text </dev/null 2>/dev/null); then
        echo "[PASS] render-workspace: ${current#Active Workspace: }"
        exit 0
    fi
    # Workspace IDs start with tea- (team) or usr- (user).
    ids=$(render workspaces --output json </dev/null 2>/dev/null | grep -oE '"id": *"(tea|usr)-[^"]+"' | grep -oE '(tea|usr)-[^"]+') \
        || { echo "[FAIL] render-workspace: could not list Render workspaces (is Render signed in?)"; exit 1; }
    if [ "$(printf '%s\n' "$ids" | wc -l)" -ne 1 ]; then
        echo "ASK: this Render account has several workspaces. Ask the attendee which one to use for now (each app's deploy sets its own), then run:"
        echo "  bash ~/.workshop/render-workspace.sh <ID>"
        render workspaces --output text </dev/null
        exit 40
    fi
    choice=$ids
fi

result=$(render workspace set "$choice" --output text </dev/null 2>&1) \
    || { echo "[FAIL] render-workspace: $result"; exit 1; }
echo "[PASS] render-workspace: ${result#Workspace set to: }"
