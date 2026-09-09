#!/usr/bin/env bash
clear
echo "############################################################################"
echo "#                          fail2ban Installer                              #"
echo "#               by Nico L and Kyle Smith (mrsmith9)                        #"
echo "#                   https://github.com/ipexadev/scripts                    #"
echo "#                          Last Update: 27.06.2022                         #"
echo "############################################################################"
sleep 3
set -Eeuo pipefail

readonly JAIL_FILE="/etc/fail2ban/jail.d/sshd.local"

error() { printf 'Error: %s\n' "$*" >&2; }
die() { error "$*"; exit 1; }
info() { printf '==> %s\n' "$*"; }
trap 'error "Installation failed at line $LINENO. Review the message above and rerun when resolved."' ERR

require_root() { [[ $EUID -eq 0 ]] || die "Run this installer as root: sudo bash fail2ban.sh"; }
require_supported_os() {
    [[ -r /etc/os-release ]] || die "Cannot identify the operating system."
    . /etc/os-release
    [[ ${ID:-} == debian || ${ID:-} == ubuntu ]] || die "Only Debian and Ubuntu are supported (detected: ${ID:-unknown})."
}
is_port() { [[ $1 =~ ^[0-9]+$ ]] && (( $1 >= 1 && $1 <= 65535 )); }

require_root
require_supported_os

read -r -p "SSH port to protect [22]: " ssh_port
ssh_port="${ssh_port:-22}"
is_port "$ssh_port" || die "SSH port must be between 1 and 65535."

read -r -p "Install and enable Fail2ban protection for SSH on port $ssh_port? [y/N]: " confirm
[[ ${confirm,,} == y || ${confirm,,} == yes ]] || die "No changes were made."

info "Installing Fail2ban from the configured APT repositories..."
apt-get update
apt-get install -y --no-install-recommends fail2ban

install -d -m 755 /etc/fail2ban/jail.d
cat >"$JAIL_FILE" <<EOF
[sshd]
enabled = true
port = $ssh_port
maxretry = 5
findtime = 10m
bantime = 1h
EOF

fail2ban-client -t
systemctl enable --now fail2ban
info "Fail2ban is active. Inspect SSH bans with: sudo fail2ban-client status sshd"
