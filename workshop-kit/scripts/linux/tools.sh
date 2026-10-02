#!/usr/bin/env bash
# tools.sh
#
# Install phase: the workshop's development tools. Runs inside Ubuntu as
# appdev, piped in by install-tools.ps1 (and by check-status.ps1 to check).
# Every component can be checked and installed separately, and installing
# is safe to repeat.
#
#   bash tools.sh check all           one line per component; exit code = number missing
#   bash tools.sh check <component>
#   bash tools.sh install <component>

set -uo pipefail

RUBY_VERSION=4.0.5
NODE_VERSION=24.21.0
POSTGRES_VERSION=18
REVYL_VERSION=v0.1.109
FIRSTDRAFT_CLI_MIN_VERSION=0.8.1   # first version with 'firstdraft login'

# Installed in this order; later components depend on earlier ones.
COMPONENTS="apt-repos apt-packages postgres mise ruby node claude npm-packages render neon-skills revyl"

APT_PACKAGES="build-essential rustc libssl-dev libyaml-dev zlib1g-dev libgmp-dev libffi-dev
    unzip curl git ca-certificates gnupg wslu gh cloudflared postgresql-$POSTGRES_VERSION libpq-dev"
NPM_PACKAGES="@firstdraft.com/cli @firstdraft.com/claude-code neonctl"

# Commands run by Claude do not read ~/.bashrc or ~/.profile, so set PATH here.
export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:$HOME/.revyl/bin:$PATH"
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


# --- postgres: server running, appdev can connect ---------------------------

check_postgres() {
    local version
    systemctl is-active --quiet postgresql || { echo "service not running"; return 1; }
    version=$(psql -d postgres -tAc 'show server_version' 2>&1) || { echo "appdev cannot connect: $version"; return 1; }
    case "$version" in
        "$POSTGRES_VERSION".*) ;;
        *) echo "server is version $version, expected $POSTGRES_VERSION"; return 1 ;;
    esac
    psql -d appdev -tAc 'select 1' >/dev/null 2>&1 || { echo "database 'appdev' missing"; return 1; }
    echo "PostgreSQL $version running; user appdev can connect"
}

install_postgres() {
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
    grep -qF 'mise activate bash' "$HOME/.bashrc" || { echo "not activated in ~/.bashrc"; return 1; }
    grep -qF 'mise/shims' "$HOME/.profile" || { echo "shims not on PATH in ~/.profile"; return 1; }
    echo "$(mise --version 2>/dev/null | head -n 1)"
}

install_mise() {
    [ -x "$HOME/.local/bin/mise" ] || curl -fsSL https://mise.run | sh
    # Interactive terminals get full activation; other shells (including
    # commands Claude runs) find Ruby and Node through the shims folder.
    add_line "$HOME/.bashrc" 'eval "$(~/.local/bin/mise activate bash)"'
    add_line "$HOME/.profile" 'export PATH="$HOME/.local/share/mise/shims:$PATH"'
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
    echo "$NPM_PACKAGES (First Draft CLI $version)"
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
    grep -qF '.revyl/bin' "$HOME/.profile" || { echo "not on PATH in ~/.profile"; return 1; }
    version=$(revyl --version 2>/dev/null | head -n 1)
    case "$version" in
        *"${REVYL_VERSION#v}"*) echo "$version" ;;
        *) echo "version '$version', expected $REVYL_VERSION"; return 1 ;;
    esac
}

install_revyl() {
    curl -fsSL "https://raw.githubusercontent.com/RevylAI/revyl-cli/$REVYL_VERSION/scripts/install.sh" | REVYL_VERSION=$REVYL_VERSION sh
    # The installer only adds itself to ~/.bashrc; login shells need it too.
    add_line "$HOME/.profile" 'export PATH="$HOME/.revyl/bin:$PATH"'
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
