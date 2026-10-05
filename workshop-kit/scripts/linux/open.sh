#!/usr/bin/env bash
# open.sh
#
# Opens a link in the attendee's default browser: with 'open' on a Mac, and
# through Windows (wslview) on a Windows laptop.
# Installed to ~/.workshop/open.sh by handoff.sh; used by the sign-in skill
# and the app-session notes.
#
#   bash open.sh <link>     prints OPENED or NOT OPENED

set -uo pipefail

. "$(dirname "${BASH_SOURCE[0]}")/platform.sh"

link=${1:?usage: open.sh <link>}

if open_link "$link"; then
    echo "OPENED: $link in the default browser"
else
    echo "NOT OPENED: the attendee must click this link: $link"
fi
