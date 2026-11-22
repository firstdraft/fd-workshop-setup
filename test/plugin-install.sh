#!/usr/bin/env bash
# plugin-install.sh
#
# Checks how the kit installs First Draft, with stand-ins for claude, npm,
# mise and the plugin's CLI:
#   - on a Mac, tools.sh installs the plugin from First Draft's catalog with
#     Claude Code's own plugin commands, turns on the catalog's automatic
#     updates, and installs no First Draft npm package;
#   - in Ubuntu (WSL), tools.sh installs the plugin's npm package and no
#     other First Draft package, and handoff.sh links the Skill from it;
#   - on both, an earlier kit's First Draft packages go, and
#     ~/.workshop/firstdraft.sh runs the plugin's CLI, or says in one line
#     what to do when it finds none.
# It runs on Linux, which handoff.sh's Ubuntu path needs, with Node.js and
# Python 3; a stand-in uname makes the Mac path. From the repository's root:
#
#   docker run --rm -v "$PWD":/repo:ro node:24-bookworm bash /repo/test/plugin-install.sh

set -uo pipefail

kit=$(cd "$(dirname "${BASH_SOURCE[0]}")/../workshop-kit" && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
real_uname=$(command -v uname)
failures=0

expect() { if "${@:2}" >/dev/null 2>&1; then echo "ok   $1"; else echo "FAIL $1"; failures=$((failures + 1)); fi; }
refute() { if "${@:2}" >/dev/null 2>&1; then echo "FAIL $1"; failures=$((failures + 1)); else echo "ok   $1"; fi; }

# make_plugin <folder> <version>: a plugin folder with the published
# package's layout, whose CLI logs where it ran and answers --version and
# start as the real one does without a saved login.
cat > "$work/make-plugin.bash" <<'EOF'
make_plugin() {
    mkdir -p "$1/.claude-plugin" "$1/bin" "$1/skills/create-full-stack-app"
    printf '{"name":"@firstdraft.com/claude-code","version":"%s"}\n' "$2" > "$1/package.json"
    printf '{"name":"firstdraft","version":"%s"}\n' "$2" > "$1/.claude-plugin/plugin.json"
    echo "# create-full-stack-app" > "$1/skills/create-full-stack-app/SKILL.md"
    cat > "$1/bin/firstdraft" <<CLI
#!/bin/sh
echo "cli $1 \$*" >> "\$STUB_LOG"
case "\$1" in
    --version) echo $2 ;;
    start)
        echo "First Draft CLI $2 with plugin $2."
        echo "This computer has no saved login for https://firstdraft.com."
        printf '{\n  "error": "authentication_required",\n  "detail": "stub"\n}\n' >&2
        exit 1 ;;
esac
CLI
    chmod 755 "$1/bin/firstdraft"
}
EOF
. "$work/make-plugin.bash"

# new_home <name>: a home folder with the stand-ins in ~/.local/bin, which
# every helper puts first on its PATH, and an earlier kit's First Draft
# packages and Skill link.
new_home() {
    local home=$work/$1 bin root
    bin=$home/.local/bin
    root=$home/npm/lib/node_modules
    mkdir -p "$bin" "$home/.claude/skills" "$root/@firstdraft.com/cli"
    touch "$home/.bashrc"
    echo '{"name":"@firstdraft.com/cli","version":"0.9.0"}' > "$root/@firstdraft.com/cli/package.json"
    make_plugin "$root/@firstdraft.com/claude-code" 0.9.3
    ln -s "$root/@firstdraft.com/claude-code/skills/create-full-stack-app" "$home/.claude/skills/create-full-stack-app"

    cat > "$bin/uname" <<EOF
#!/bin/sh
if [ "\$1" = -s ]; then echo "\$STUB_UNAME"; else exec $real_uname "\$@"; fi
EOF
    cat > "$bin/mise" <<'EOF'
#!/bin/sh
echo "mise $*" >> "$STUB_LOG"
EOF
    cat > "$bin/npm" <<EOF
#!/usr/bin/env bash
echo "npm \$*" >> "\$STUB_LOG"
. $work/make-plugin.bash
root=$root
case "\$1" in
    root) echo "\$root" ;;
    ls) [ -f "\$root/\${*: -1}/package.json" ] ;;
    view) echo 0.10.0 ;;
    uninstall)
        shift
        for package in "\$@"; do rm -rf "\${root:?}/\$package"; done ;;
    install)
        shift
        for spec in "\$@"; do
            case "\$spec" in
                @firstdraft.com/claude-code@latest)
                    rm -rf "\$root/@firstdraft.com/claude-code"
                    make_plugin "\$root/@firstdraft.com/claude-code" 0.10.0 ;;
                -*) ;;
                *) mkdir -p "\$root/\${spec%@*}" ;;
            esac
        done ;;
esac
EOF
    cat > "$bin/claude" <<EOF
#!/usr/bin/env bash
echo "claude \$*" >> "\$STUB_LOG"
. $work/make-plugin.bash
settings=$home/.claude/settings.json
plugin=$home/.claude/plugins/cache/firstdraft-skills/firstdraft/0.10.0
case "\$*" in
    "plugin marketplace add firstdraft/skills --scope user")
        echo '{"extraKnownMarketplaces":{"firstdraft-skills":{"source":{"source":"github","repo":"firstdraft/skills"}}}}' > "\$settings" ;;
    "plugin install firstdraft@firstdraft-skills --scope user") make_plugin "\$plugin" 0.10.0 ;;
    "plugin list --json")
        if [ -d "\$plugin" ]; then
            printf '[{"id":"firstdraft@firstdraft-skills","version":"0.10.0","enabled":true,"installPath":"%s"}]\n' "\$plugin"
        else
            echo '[]'
        fi ;;
    *) echo "unexpected: claude \$*" >&2; exit 1 ;;
esac
EOF
    chmod 755 "$bin/"*
    echo "$home"
}

# run <home> <uname -s> <log> <command...>: runs a command in that home.
run() {
    env -u CLAUDE_CONFIG_DIR -u FIRSTDRAFT_PLUGIN_CATALOG -u FIRSTDRAFT_PLUGIN_PACKAGE \
        HOME="$1" STUB_UNAME="$2" STUB_LOG="$3" PATH="$1/.local/bin:$PATH" "${@:4}"
}

# Did firstdraft.sh give one line that says the CLI is unavailable, and 127?
says_unavailable() {
    [ "$1" -eq 127 ] && [ "$(printf '%s\n' "$2" | wc -l)" -eq 1 ] && [[ "$2" == "First Draft CLI is unavailable: "* ]]
}

# Did the log's npm installs name only this package?
installs_only() {
    [ "$(grep '^npm install' "$1")" = "npm install --global $2" ]
}


echo "== Mac"
home=$(new_home mac)
log=$work/mac.log
refute "an earlier kit's npm packages fail the firstdraft check" \
    run "$home" Darwin "$log" bash "$kit/scripts/linux/tools.sh" check firstdraft
out=$(run "$home" Darwin "$log" bash "$kit/scripts/linux/tools.sh" install firstdraft)
printf '%s\n' "$out" | sed 's/^/     /'
expect "the install passes its check" \
    grep -qxF '[PASS] firstdraft: firstdraft@firstdraft-skills 0.10.0 with CLI 0.10.0, automatic updates on' <<<"$out"
expect "it adds First Draft's catalog with Claude Code" \
    grep -qxF 'claude plugin marketplace add firstdraft/skills --scope user' "$log"
expect "it installs the plugin from that catalog" \
    grep -qxF 'claude plugin install firstdraft@firstdraft-skills --scope user' "$log"
expect "it turns on the catalog's automatic updates" node -e '
    const settings = JSON.parse(require("node:fs").readFileSync(process.argv[1], "utf8"));
    process.exit(settings.extraKnownMarketplaces["firstdraft-skills"].autoUpdate === true ? 0 : 1);
' "$home/.claude/settings.json"
expect "it removes the earlier kit's two npm packages" \
    grep -qxF 'npm uninstall --global @firstdraft.com/cli @firstdraft.com/claude-code' "$log"
refute "it installs no npm package" grep -q '^npm install' "$log"
out=$(run "$home" Darwin "$log" bash "$kit/scripts/linux/firstdraft.sh" start 2>&1)
expect "firstdraft.sh runs the CLI where Claude Code installed the plugin" \
    grep -qxF "cli $home/.claude/plugins/cache/firstdraft-skills/firstdraft/0.10.0 start" "$log"
expect "and passes on its lines" grep -qxF 'This computer has no saved login for https://firstdraft.com.' <<<"$out"
rm -rf "$home/.claude/plugins"
out=$(run "$home" Darwin "$log" bash "$kit/scripts/linux/firstdraft.sh" start 2>&1)
expect "without the plugin, it says what to do in one line" says_unavailable "$?" "$out"
out=$(run "$home" Darwin "$log" bash "$kit/scripts/linux/handoff.sh" check)
expect "the handoff check finds the earlier kit's Skill link" \
    grep -qF '[FAIL] firstdraft-skill: an earlier kit' <<<"$out"
mkdir -p "$home/dotfiles/create-full-stack-app"
ln -sfn "$home/dotfiles/create-full-stack-app" "$home/.claude/skills/create-full-stack-app"
out=$(run "$home" Darwin "$log" bash "$kit/scripts/linux/handoff.sh" check)
expect "and leaves a link of the attendee's own alone" \
    grep -qxF '[PASS] firstdraft-skill: /firstdraft:create-full-stack-app, from the plugin' <<<"$out"


echo "== Ubuntu (WSL)"
home=$(new_home wsl)
log=$work/wsl.log
root=$home/npm/lib/node_modules
refute "the earlier kit's separate CLI package fails the firstdraft check" \
    run "$home" Linux "$log" bash "$kit/scripts/linux/tools.sh" check firstdraft
out=$(run "$home" Linux "$log" bash "$kit/scripts/linux/tools.sh" install firstdraft)
printf '%s\n' "$out" | sed 's/^/     /'
expect "the install passes its check" \
    grep -qxF '[PASS] firstdraft: First Draft plugin 0.10.0 with CLI 0.10.0, up to date' <<<"$out"
expect "it removes the separate CLI package" grep -qxF 'npm uninstall --global @firstdraft.com/cli' "$log"
expect "it installs the plugin's npm package and no other First Draft package" \
    installs_only "$log" @firstdraft.com/claude-code@latest
refute "it runs no Claude Code plugin command" grep -q '^claude ' "$log"
# The earlier kit's link has the same target, so start as a new laptop does.
rm "$home/.claude/skills/create-full-stack-app"
out=$(run "$home" Linux "$log" env WORKSHOP_APP_NAME=fam WORKSHOP_KIT_DIR="$kit" bash "$kit/scripts/linux/handoff.sh" apply)
expect "the handoff links the Skill from the plugin's package" \
    test "$(readlink "$home/.claude/skills/create-full-stack-app")" = "$root/@firstdraft.com/claude-code/skills/create-full-stack-app"
expect "and its check passes" \
    grep -qxF '[PASS] firstdraft-skill: /create-full-stack-app, linked from the plugin'"'"'s npm package' <<<"$out"
expect "and it installs ~/.workshop/firstdraft.sh" test -f "$home/.workshop/firstdraft.sh"
out=$(run "$home" Linux "$log" bash "$home/.workshop/firstdraft.sh" start 2>&1)
expect "firstdraft.sh runs the package's CLI through the link" grep -qxF "cli $root/@firstdraft.com/claude-code start" "$log"
expect "and passes on its lines" grep -qxF 'This computer has no saved login for https://firstdraft.com.' <<<"$out"
out=$(run "$home" Linux "$log" bash "$home/.workshop/auth.sh" check firstdraft)
expect "auth.sh reads them" test "$out" = "[FAIL] firstdraft: This computer has no saved login for https://firstdraft.com."
rm "$home/.claude/skills/create-full-stack-app"
out=$(run "$home" Linux "$log" bash "$home/.workshop/firstdraft.sh" start 2>&1)
expect "without the link, it says what to do in one line" says_unavailable "$?" "$out"
refute "and the handoff check fails" run "$home" Linux "$log" bash "$kit/scripts/linux/handoff.sh" check


echo
if [ "$failures" -eq 0 ]; then echo "All checks passed."; else echo "$failures failed."; fi
exit "$failures"
