#!/usr/bin/env bash
# firstdraft.sh
#
# Runs the CLI inside the First Draft plugin from a plain shell, such as a
# terminal or these helpers. The plugin holds the First Draft Skill and the
# CLI it was tested with, and nothing installs the CLI by itself. In an agent
# session, the First Draft Skill runs the same CLI through its own helper.
# Installed to ~/.workshop/firstdraft.sh by handoff.sh.
#
#   bash firstdraft.sh <arguments>    for example: bash firstdraft.sh start
#
# On a Mac, Claude Code installed the plugin from First Draft's catalog, and
# its folder changes with every plugin update, so this asks Claude Code where
# the plugin is now. In Ubuntu (WSL) the kit installed the plugin's npm
# package and linked its Skill into ~/.claude/skills, which needs no plugin
# install, so it does not depend on whether a WSL session loads plugins; the
# CLI is in the package beside the Skill.

set -uo pipefail

export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:$PATH"

if [ "$(uname -s)" = Darwin ]; then
    # A plugin from a local catalog, which maintainers use to try a plugin,
    # loads in place from readFromFolder rather than from its installPath.
    plugin_root=$(claude plugin list --json 2>/dev/null | node -e '
        let text = "";
        process.stdin.on("data", (chunk) => (text += chunk)).on("end", () => {
            let plugins = [];
            try { plugins = JSON.parse(text); } catch {}
            const plugin = plugins.find((entry) => entry.id === "firstdraft@firstdraft-skills");
            if (plugin) console.log(plugin.readFromFolder || plugin.installPath);
        });' 2>/dev/null)
    missing="First Draft CLI is unavailable: Claude Code has no First Draft plugin installed. Run the laptop kit again: open its workshop-kit folder in Claude Desktop and type continue."
else
    plugin_root=""
    skill="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills/create-full-stack-app"
    if [ -f "$skill/SKILL.md" ]; then
        # The link's physical target is the package's skills/create-full-stack-app.
        plugin_root=$(cd -P "$skill/../.." 2>/dev/null && pwd)
    fi
    missing="First Draft CLI is unavailable: the First Draft Skill is not linked into ~/.claude/skills from its package. Run the laptop kit again: open its workshop-kit folder in a Claude Desktop Local session and type continue."
fi

if [ -z "$plugin_root" ] || [ ! -f "$plugin_root/.claude-plugin/plugin.json" ] || [ ! -x "$plugin_root/bin/firstdraft" ]; then
    echo "$missing" >&2
    exit 127
fi
exec "$plugin_root/bin/firstdraft" "$@"
