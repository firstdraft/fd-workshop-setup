#!/usr/bin/env bash
# setup-user.sh
#
# Runs as root inside Ubuntu (piped in by setup-ubuntu.ps1). Creates the
# workshop user, lets it use sudo without a password prompt (Claude's shell
# cannot type one), and makes it the default WSL user. Safe to run again.

set -euo pipefail

USER_NAME=appdev
USER_PASSWORD=appdev

if id "$USER_NAME" >/dev/null 2>&1; then
    echo "[PASS] Linux user '$USER_NAME' already exists"
else
    useradd --create-home --shell /bin/bash "$USER_NAME"
    echo "[PASS] Created Linux user '$USER_NAME'"
fi

# Same groups Ubuntu's own first-run setup gives the first user.
for group in adm cdrom sudo dip plugdev users; do
    if getent group "$group" >/dev/null; then
        usermod -aG "$group" "$USER_NAME"
    fi
done

echo "$USER_NAME:$USER_PASSWORD" | chpasswd
echo "[PASS] Password set"

sudoers_file=/etc/sudoers.d/90-workshop-$USER_NAME
printf '%s ALL=(ALL) NOPASSWD:ALL\n' "$USER_NAME" > "$sudoers_file.tmp"
chmod 0440 "$sudoers_file.tmp"
visudo -cf "$sudoers_file.tmp" >/dev/null
mv "$sudoers_file.tmp" "$sudoers_file"
echo "[PASS] sudo works without a password prompt"

if [ -f /etc/wsl.conf ] && [ ! -f /etc/wsl.conf.before-workshop ]; then
    cp /etc/wsl.conf /etc/wsl.conf.before-workshop
fi
cat > /etc/wsl.conf <<EOF
[boot]
systemd=true

[user]
default=$USER_NAME
EOF
echo "[PASS] /etc/wsl.conf: default user '$USER_NAME', systemd on"
