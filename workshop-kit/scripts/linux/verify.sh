#!/usr/bin/env bash
# verify.sh
#
# Runs inside Ubuntu as the default user (piped in by verify.ps1), or on a
# Mac as the attendee (scripts/mac/setup.sh). Prints one line per check and
# exits with the number of failed checks.

failures=0
pass() { echo "[PASS] $1"; }
warn() { echo "[WARN] $1"; }
fail() { echo "[FAIL] $1"; failures=$((failures + 1)); }

https_check() {
    if ! command -v curl >/dev/null; then
        warn "curl is not installed; skipped the HTTPS check"
    elif curl -fsS -o /dev/null --max-time 20 https://github.com; then
        pass "HTTPS downloads work"
    else
        fail "HTTPS download failed (a proxy or 'SSL inspection' on this network can cause this)"
    fi
}

if [ "$(uname -s)" = Darwin ]; then
    version=$(sw_vers -productVersion)
    # Homebrew supports the three newest macOS versions; on older ones it
    # may build tools from source, which is slow.
    if [ "${version%%.*}" -ge 14 ]; then pass "macOS $version"; else warn "macOS $version is older than 14; installs may be slow"; fi

    # tools.sh adds the tools to zsh's startup files.
    if [ "$(basename "${SHELL:-}")" = zsh ]; then pass "Login shell is zsh"; else fail "Login shell is '${SHELL:-}', expected zsh"; fi

    if cd ~ && touch .workshop-write-test && rm .workshop-write-test; then pass "Home folder $HOME is writable"; else fail "Cannot write to $HOME"; fi

    free_kb=$(df -Pk "$HOME" | awk 'NR==2 {print $4}')
    if [ "$free_kb" -ge 5242880 ]; then pass "$((free_kb / 1048576)) GB free"; else fail "Only $((free_kb / 1048576)) GB free (need 5)"; fi

    if dscacheutil -q host -a name github.com | grep -q '^ip_address'; then pass "DNS works"; else fail "DNS lookup failed (no internet, VPN, or firewall)"; fi

    https_check
    exit "$failures"
fi

. /etc/os-release
if [ "$VERSION_ID" = "24.04" ]; then pass "Ubuntu $VERSION_ID"; else fail "Ubuntu version is $VERSION_ID, expected 24.04"; fi

if [ "$(whoami)" = "appdev" ]; then pass "Running as appdev"; else fail "Running as $(whoami), expected appdev"; fi

if cd ~ && touch .workshop-write-test && rm .workshop-write-test; then pass "Home folder $HOME is writable"; else fail "Cannot write to $HOME"; fi

if sudo -n true 2>/dev/null; then pass "sudo works without a password prompt"; else fail "sudo asks for a password"; fi

if [ "$(ps -p 1 -o comm=)" = "systemd" ]; then pass "systemd is running"; else warn "systemd is not running (PID 1 is $(ps -p 1 -o comm=))"; fi

free_kb=$(df -Pk / | awk 'NR==2 {print $4}')
if [ "$free_kb" -ge 5242880 ]; then pass "$((free_kb / 1048576)) GB free in Linux"; else fail "Only $((free_kb / 1048576)) GB free in Linux (need 5)"; fi

if getent hosts archive.ubuntu.com >/dev/null; then pass "DNS works"; else fail "DNS lookup failed (no internet, VPN, or firewall)"; fi

https_check

if command -v cmd.exe >/dev/null; then pass "Can run Windows programs from Linux"; else warn "Windows programs are not on the Linux PATH"; fi

exit "$failures"
