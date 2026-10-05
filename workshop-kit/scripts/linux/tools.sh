#!/usr/bin/env bash
# tools.sh
#
# Install phase: the workshop's development tools. On a Windows laptop it
# runs inside Ubuntu as appdev, piped in by install-tools.ps1 (and by
# check-status.ps1 to check). On a Mac it runs as the attendee, from
# scripts/mac/setup.sh, under macOS's bash 3.2, and uses Homebrew instead
# of apt. Every component can be checked and installed separately, and
# installing is safe to repeat.
#
#   bash tools.sh check all           one line per component; exit code = number missing
#   bash tools.sh check <component>
#   bash tools.sh install <component>

set -uo pipefail

RUBY_VERSION=4.0.5
NODE_VERSION=24.21.0
POSTGRES_VERSION=18
REVYL_VERSION=v0.1.133
FIRSTDRAFT_CLI_MIN_VERSION=0.8.1   # first version with 'firstdraft login'

NPM_PACKAGES="@firstdraft.com/cli @firstdraft.com/claude-code neonctl"

# Installed in this order; later components depend on earlier ones.
if [ "$(uname -s)" = Darwin ]; then
    MAC=1
    COMPONENTS="xcode-clt homebrew brew-packages postgres mise ruby node claude npm-packages render neon-skills revyl"
    # The apt list's tools and build libraries; macOS and Apple's Command
    # Line Tools provide the compilers, zlib, libffi, curl, git and unzip.
    BREW_PACKAGES="gh cloudflared postgresql@$POSTGRES_VERSION openssl@3 libyaml gmp rust"
    # hw.optional.arm64 is 1 on Apple Silicon even under Rosetta.
    if [ "$(sysctl -n hw.optional.arm64 2>/dev/null)" = 1 ]; then BREW_PREFIX=/opt/homebrew; else BREW_PREFIX=/usr/local; fi
    BREW="$BREW_PREFIX/bin/brew"
    POSTGRES_BIN="$BREW_PREFIX/opt/postgresql@$POSTGRES_VERSION/bin"
    # zsh is macOS's login shell. Claude Desktop reads PATH from it, and
    # login and interactive shells read different files, so PATH lines go
    # in both.
    SHELL_NAME=zsh
    RC_FILE="$HOME/.zshrc"
    RC_NAME="~/.zshrc"
    PROFILE_FILES=("$HOME/.zprofile" "$HOME/.zshrc")
    PROFILE_NAMES="~/.zprofile and ~/.zshrc"
    export HOMEBREW_NO_ENV_HINTS=1
    # Commands run by Claude may not have read the startup files yet, so set PATH here.
    export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:$HOME/.revyl/bin:$POSTGRES_BIN:$BREW_PREFIX/bin:$PATH"
else
    MAC=""
    COMPONENTS="apt-repos apt-packages postgres mise ruby node claude npm-packages render neon-skills revyl"
    APT_PACKAGES="build-essential rustc libssl-dev libyaml-dev zlib1g-dev libgmp-dev libffi-dev
    unzip curl git ca-certificates gnupg wslu gh cloudflared postgresql-$POSTGRES_VERSION libpq-dev"
    SHELL_NAME=bash
    RC_FILE="$HOME/.bashrc"
    RC_NAME="~/.bashrc"
    PROFILE_FILES=("$HOME/.profile")
    PROFILE_NAMES="~/.profile"
    # Commands run by Claude do not read ~/.bashrc or ~/.profile, so set PATH here.
    export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:$HOME/.revyl/bin:$PATH"
fi
export MISE_YES=1
cd "$HOME"

apt_get() {
    # Waits (up to 10 minutes) while Ubuntu's automatic updates hold the apt lock.
    sudo DEBIAN_FRONTEND=noninteractive apt-get -y -o DPkg::Lock::Timeout=600 "$@"
}

# Appends a line to a shell startup file unless it is already there.
add_line() {
    local file=$1 line=$2
    if ! grep -qxF "$line" "$file" 2>/dev/null; then
        printf '\n# Added by workshop setup\n%s\n' "$line" >> "$file"
    fi
}

# Adds a PATH line to the login shell's startup files (PROFILE_FILES).
add_to_profiles() {
    local file
    for file in "${PROFILE_FILES[@]}"; do add_line "$file" "$1"; done
}

# Do all of the login shell's startup files mention this text?
profiles_have() {
    local file
    for file in "${PROFILE_FILES[@]}"; do grep -qF "$1" "$file" 2>/dev/null || return 1; done
}


# --- apt-repos: PostgreSQL, Cloudflare and GitHub CLI package sources -------

check_apt_repos() {
    local missing=""
    for list in pgdg cloudflared github-cli; do
        [ -f "/etc/apt/sources.list.d/$list.list" ] || missing="$missing $list"
    done
    [ -z "$missing" ] && echo "PostgreSQL, Cloudflare, GitHub sources added" && return 0
    echo "missing:$missing"; return 1
}

install_apt_repos() {
    local codename arch
    codename=$(. /etc/os-release && echo "$VERSION_CODENAME")
    arch=$(dpkg --print-architecture)
    sudo install -d -m 0755 /etc/apt/keyrings

    curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo tee /etc/apt/keyrings/postgresql.asc >/dev/null
    echo "deb [signed-by=/etc/apt/keyrings/postgresql.asc] https://apt.postgresql.org/pub/repos/apt $codename-pgdg main" \
        | sudo tee /etc/apt/sources.list.d/pgdg.list >/dev/null

    curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg | sudo tee /etc/apt/keyrings/cloudflare-main.gpg >/dev/null
    echo "deb [signed-by=/etc/apt/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared any main" \
        | sudo tee /etc/apt/sources.list.d/cloudflared.list >/dev/null

    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null
    echo "deb [arch=$arch signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null

    sudo chmod go+r /etc/apt/keyrings/*
    apt_get update
}


# --- apt-packages: compilers, libraries, gh, cloudflared, PostgreSQL ------

check_apt_packages() {
    local missing="" package
    for package in $APT_PACKAGES; do
        dpkg-query -W -f='${Status}' "$package" 2>/dev/null | grep -q 'install ok installed' || missing="$missing $package"
    done
    [ -z "$missing" ] && echo "all installed" && return 0
    echo "missing:$missing"; return 1
}

install_apt_packages() {
    apt_get update
    # shellcheck disable=SC2086
    apt_get install $APT_PACKAGES
}


# --- xcode-clt, homebrew (Mac): Apple's compilers and git, and Homebrew ------

check_xcode_clt() {
    # Checked in this order because the /usr/bin tools ask to install the
    # Command Line Tools (a dialog) when they are missing.
    xcode-select -p >/dev/null 2>&1 || { echo "not installed"; return 1; }
    xcrun clang --version >/dev/null 2>&1 || { echo "installed but clang does not run (has the Xcode license been accepted?)"; return 1; }
    echo "$(xcode-select -p)"
}

check_homebrew() {
    [ -x "$BREW" ] || { echo "not installed"; return 1; }
    profiles_have 'brew shellenv' || { echo "not on PATH in $PROFILE_NAMES"; return 1; }
    echo "$("$BREW" --version 2>/dev/null | head -n 1)"
}

# Homebrew's installer needs the attendee's Mac password, typed into a
# terminal, so it runs in a Terminal window that the attendee watches. It
# also installs the Command Line Tools when they are missing. This waits up
# to 30 minutes for the window to finish.
install_in_terminal() {
    local script="$HOME/.workshop/install-homebrew.command" result="$HOME/.workshop/logs/homebrew.result"
    local log="$HOME/.workshop/logs/homebrew.log"
    mkdir -p "$HOME/.workshop/logs"
    rm -f "$result"
    # Written here rather than shipped in the zip: Gatekeeper blocks a
    # downloaded .command file, but not one created on this Mac.
    cat > "$script" <<EOF
#!/bin/bash
clear
echo "Installing Homebrew and Apple's Command Line Tools for the workshop."
echo
echo "- When it asks for your Password, type your Mac password and press Return."
echo "  Nothing shows while you type. That is normal."
echo "- When it says 'Press RETURN', press Return."
echo "- Leave this window open until it says you can close it."
echo
installer=\$(mktemp)
if curl -fsSL -o "\$installer" https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh; then
    /bin/bash "\$installer" 2>&1 | tee "$log"
    status=\${PIPESTATUS[0]}
else
    echo "Could not download Homebrew's installer. Check the Wi-Fi." | tee "$log"
    status=1
fi
rm -f "\$installer"
echo "\$status" > "$result"
echo
if [ "\$status" -eq 0 ]; then
    echo "Done. You can close this window and go back to Claude."
else
    echo "Homebrew was not installed. Go back to Claude."
fi
echo "(Skip any 'Next steps' commands above: Claude does them.)"
EOF
    chmod 755 "$script"
    open -a Terminal "$script"
    echo "OPENED: a Terminal window with Homebrew's installer. Waiting for it (up to 30 minutes)..."
    for _ in $(seq 1 360); do
        [ -f "$result" ] && break
        sleep 5
    done
    [ -f "$result" ] || { echo "Homebrew's installer has not finished after 30 minutes"; return 1; }
    if [ "$(cat "$result")" != 0 ]; then
        echo "Homebrew's installer stopped (exit code $(cat "$result")). Its last lines:"
        tail -n 15 "$log" 2>/dev/null
        return 1
    fi
}

install_xcode_clt() {
    install_in_terminal
}

install_homebrew() {
    if [ ! -x "$BREW" ] || ! check_xcode_clt >/dev/null; then
        install_in_terminal
    fi
    add_to_profiles "eval \"\$($BREW shellenv)\""
}


# --- brew-packages (Mac): gh, cloudflared, PostgreSQL, build libraries -------

check_brew_packages() {
    local missing="" package
    for package in $BREW_PACKAGES; do
        "$BREW" list --formula --versions "$package" >/dev/null 2>&1 || missing="$missing $package"
    done
    [ -z "$missing" ] && echo "all installed" && return 0
    echo "missing:$missing"; return 1
}

install_brew_packages() {
    # shellcheck disable=SC2086
    "$BREW" install $BREW_PACKAGES
}


# --- postgres: server running, the user can connect ---------------------------

check_postgres() {
    local version
    [ -n "$MAC" ] && { check_postgres_mac; return; }
    systemctl is-active --quiet postgresql || { echo "service not running"; return 1; }
    version=$(psql -d postgres -tAc 'show server_version' 2>&1) || { echo "appdev cannot connect: $version"; return 1; }
    case "$version" in
        "$POSTGRES_VERSION".*) ;;
        *) echo "server is version $version, expected $POSTGRES_VERSION"; return 1 ;;
    esac
    psql -d appdev -tAc 'select 1' >/dev/null 2>&1 || { echo "database 'appdev' missing"; return 1; }
    echo "PostgreSQL $version running; user appdev can connect"
}

# Homebrew's PostgreSQL runs as the attendee, whose role and database it
# creates under their macOS user name.
check_postgres_mac() {
    local version
    "$BREW" services info "postgresql@$POSTGRES_VERSION" --json 2>/dev/null | grep -q '"running": *true' \
        || { echo "service not running"; return 1; }
    profiles_have "postgresql@$POSTGRES_VERSION/bin" || { echo "not on PATH in $PROFILE_NAMES"; return 1; }
    version=$(psql -d postgres -tAc 'show server_version' 2>&1) || { echo "$USER cannot connect: $version"; return 1; }
    case "$version" in
        "$POSTGRES_VERSION".*) ;;
        *) echo "server is version $version, expected $POSTGRES_VERSION"; return 1 ;;
    esac
    psql -d "$USER" -tAc 'select 1' >/dev/null 2>&1 || { echo "database '$USER' missing"; return 1; }
    echo "PostgreSQL $version running; user $USER can connect"
}

install_postgres_mac() {
    # The formula is keg-only (a versioned formula), so its psql and
    # pg_config are not linked into Homebrew's bin folder.
    add_to_profiles "export PATH=\"$POSTGRES_BIN:\$PATH\""
    "$BREW" services start "postgresql@$POSTGRES_VERSION"
    for _ in $(seq 1 30); do
        pg_isready -q -d postgres && break
        sleep 1
    done
    if ! psql -d postgres -tAc "select 1 from pg_database where datname = '$USER'" | grep -q 1; then
        createdb "$USER"
    fi
}

install_postgres() {
    [ -n "$MAC" ] && { install_postgres_mac; return; }
    sudo systemctl enable --now postgresql
    if ! (cd /tmp && sudo -u postgres psql -tAc "select 1 from pg_roles where rolname = 'appdev'" | grep -q 1); then
        (cd /tmp && sudo -u postgres createuser --superuser appdev)
    fi
    if ! psql -d postgres -tAc "select 1 from pg_database where datname = 'appdev'" | grep -q 1; then
        createdb appdev
    fi
}


# --- mise: version manager for Ruby and Node --------------------------------

check_mise() {
    [ -x "$HOME/.local/bin/mise" ] || { echo "not installed"; return 1; }
    grep -qF "mise activate $SHELL_NAME" "$RC_FILE" || { echo "not activated in $RC_NAME"; return 1; }
    profiles_have 'mise/shims' || { echo "shims not on PATH in $PROFILE_NAMES"; return 1; }
    if [ -n "$MAC" ]; then
        profiles_have '.local/bin' || { echo "~/.local/bin not on PATH in $PROFILE_NAMES"; return 1; }
    fi
    echo "$(mise --version 2>/dev/null | head -n 1)"
}

install_mise() {
    [ -x "$HOME/.local/bin/mise" ] || curl -fsSL https://mise.run | sh
    # Ubuntu's ~/.profile already puts ~/.local/bin (mise, claude, render)
    # on PATH; macOS's does not.
    [ -z "$MAC" ] || add_to_profiles 'export PATH="$HOME/.local/bin:$PATH"'
    # Interactive terminals get full activation; other shells (including
    # commands Claude runs) find Ruby and Node through the shims folder.
    add_line "$RC_FILE" "eval \"\$(~/.local/bin/mise activate $SHELL_NAME)\""
    add_to_profiles 'export PATH="$HOME/.local/share/mise/shims:$PATH"'
}


# --- ruby / node --------------------------------------------------------------

check_ruby() {
    local version
    version=$(ruby -e 'print RUBY_VERSION' 2>/dev/null) || { echo "not installed"; return 1; }
    [ "$version" = "$RUBY_VERSION" ] || { echo "version $version, expected $RUBY_VERSION"; return 1; }
    echo "Ruby $version"
}

install_ruby() {
    mise use --global "ruby@$RUBY_VERSION"
    gem update --system --no-document
}

check_node() {
    local version
    version=$(node -p 'process.versions.node' 2>/dev/null) || { echo "not installed"; return 1; }
    [ "$version" = "$NODE_VERSION" ] || { echo "version $version, expected $NODE_VERSION"; return 1; }
    echo "Node $version"
}

install_node() {
    mise use --global "node@$NODE_VERSION"
}


# --- CLIs ----------------------------------------------------------------------

check_claude() {
    command -v claude >/dev/null || { echo "not installed"; return 1; }
    echo "$(claude --version 2>/dev/null | head -n 1)"
}

install_claude() {
    curl -fsSL https://claude.ai/install.sh | bash
}

check_npm_packages() {
    local missing="" package
    for package in $NPM_PACKAGES; do
        npm ls --global --depth=0 "$package" >/dev/null 2>&1 || missing="$missing $package"
    done
    [ -z "$missing" ] || { echo "missing:$missing"; return 1; }

    # An older First Draft CLI (e.g. installed as pre-work) cannot sign in.
    local version
    version=$(firstdraft --version 2>/dev/null)
    if [ "$(printf '%s\n%s\n' "$FIRSTDRAFT_CLI_MIN_VERSION" "$version" | sort -V | head -n 1)" != "$FIRSTDRAFT_CLI_MIN_VERSION" ]; then
        echo "First Draft CLI '$version' is older than $FIRSTDRAFT_CLI_MIN_VERSION"; return 1
    fi

    # install_npm_packages installs @latest, but a laptop set up earlier
    # keeps what it got then, so compare with npm. An unreachable registry
    # only warns: setup must not depend on it. The result stays on one
    # line because callers parse each check's [PASS]/[FAIL] line.
    local root label installed latest stale="" unchecked=""
    root=$(npm root --global 2>/dev/null)
    for package in @firstdraft.com/cli @firstdraft.com/claude-code; do
        case "$package" in
            @firstdraft.com/cli) label="First Draft CLI" ;;
            *) label="First Draft plugin" ;;
        esac
        installed=$(node -p 'require(process.argv[1]).version' "$root/$package/package.json" 2>/dev/null)
        latest=$(npm view "$package" version --fetch-retries=0 --fetch-timeout=10000 2>/dev/null)
        if [ -z "$installed" ] || [ -z "$latest" ]; then
            unchecked="$unchecked $package"
        elif [ "$installed" != "$latest" ] &&
             [ "$(printf '%s\n%s\n' "$installed" "$latest" | sort -V | head -n 1)" = "$installed" ]; then
            stale="$stale; $label $installed is older than $latest"
        fi
    done
    [ -z "$stale" ] || { echo "${stale#; }"; return 1; }
    if [ -n "$unchecked" ]; then
        echo "$NPM_PACKAGES (First Draft CLI $version; WARNING: could not compare with npm's latest:$unchecked)"
    else
        echo "$NPM_PACKAGES (First Draft CLI $version, up to date)"
    fi
}

install_npm_packages() {
    local package packages=""
    for package in $NPM_PACKAGES; do packages="$packages $package@latest"; done
    # shellcheck disable=SC2086
    npm install --global $packages
    mise reshim
}

check_render() {
    command -v render >/dev/null || { echo "not installed"; return 1; }
    echo "$(render --version 2>/dev/null | head -n 1)"
}

install_render() {
    curl -fsSL https://raw.githubusercontent.com/render-oss/cli/refs/heads/main/bin/install.sh | sh
}

check_neon_skills() {
    local missing="" skill
    for skill in neon neon-postgres; do
        [ -d "$HOME/.claude/skills/$skill" ] || missing="$missing $skill"
    done
    [ -z "$missing" ] && echo "neon, neon-postgres in ~/.claude/skills" && return 0
    echo "missing:$missing"; return 1
}

install_neon_skills() {
    # Run from the home folder: the installer writes to ./.claude/skills,
    # which here is the user-wide skills folder for Claude Code.
    npx --yes neon@latest skills -s neon -s neon-postgres -y
}

check_revyl() {
    local version
    command -v revyl >/dev/null || { echo "not installed"; return 1; }
    profiles_have '.revyl/bin' || { echo "not on PATH in $PROFILE_NAMES"; return 1; }
    version=$(revyl --version 2>/dev/null | head -n 1)
    case "$version" in
        *"${REVYL_VERSION#v}"*) echo "$version" ;;
        *) echo "version '$version', expected $REVYL_VERSION"; return 1 ;;
    esac
}

install_revyl() {
    curl -fsSL "https://raw.githubusercontent.com/RevylAI/revyl-cli/$REVYL_VERSION/scripts/install.sh" | REVYL_VERSION=$REVYL_VERSION sh
    # The installer only adds itself to ~/.bashrc (~/.zshrc on a Mac); login
    # shells need it too.
    add_to_profiles 'export PATH="$HOME/.revyl/bin:$PATH"'
}


# --- main ----------------------------------------------------------------------

run_check() {
    local component=$1 detail
    if detail=$("check_${component//-/_}" 2>&1); then
        echo "[PASS] $component: $detail"
        return 0
    fi
    echo "[FAIL] $component: $detail"
    return 1
}

action=${1:-}
target=${2:-all}

case "$action" in
    check)
        if [ "$target" = all ]; then
            missing=0
            for component in $COMPONENTS; do
                run_check "$component" || missing=$((missing + 1))
            done
            exit "$missing"
        fi
        run_check "$target"
        ;;
    install)
        # A subshell with -e so the first failing command stops the install.
        # (Not inside 'if': bash ignores -e in a condition.)
        (set -e; "install_${target//-/_}")
        if [ $? -ne 0 ]; then
            echo "[FAIL] $target: install command failed"
            exit 1
        fi
        run_check "$target"
        ;;
    *)
        echo "usage: tools.sh check all|<component> | tools.sh install <component>"
        exit 2
        ;;
esac
