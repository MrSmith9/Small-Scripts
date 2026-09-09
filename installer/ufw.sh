#!/usr/bin/env bash
set -Eeuo pipefail

error() { printf 'Error: %s\n' "$*" >&2; }
die() { error "$*"; exit 1; }
info() { printf '==> %s\n' "$*"; }
trap 'error "Firewall setup failed at line $LINENO. Review the message above before reconnecting."' ERR

require_root() { [[ $EUID -eq 0 ]] || die "Run this installer as root: sudo bash ufw.sh"; }
require_supported_os() {
    [[ -r /etc/os-release ]] || die "Cannot identify the operating system."
    . /etc/os-release
    [[ ${ID:-} == debian || ${ID:-} == ubuntu ]] || die "Only Debian and Ubuntu are supported (detected: ${ID:-unknown})."
}
is_port() { [[ $1 =~ ^[0-9]+$ ]] && (( $1 >= 1 && $1 <= 65535 )); }

require_root
require_supported_os

read -r -p "SSH port that must remain reachable [22]: " ssh_port
ssh_port="${ssh_port:-22}"
is_port "$ssh_port" || die "SSH port must be between 1 and 65535."

read -r -p "Additional TCP ports to allow (comma-separated, or blank for none): " extra_ports
declare -a ports=("$ssh_port")
if [[ -n $extra_ports ]]; then
    IFS=',' read -r -a requested_ports <<<"$extra_ports"
    for port in "${requested_ports[@]}"; do
        port="${port//[[:space:]]/}"
        is_port "$port" || die "Invalid TCP port: $port"
        ports+=("$port")
    done
fi

printf 'UFW will allow SSH on TCP/%s' "$ssh_port"
if ((${#ports[@]} > 1)); then
    for port in "${ports[@]:1}"; do
        printf ' and TCP/%s' "$port"
    done
fi
printf '. It will then enable a default-deny incoming firewall policy.\n'
read -r -p "Type ENABLE to apply these firewall rules: " confirm
[[ $confirm == ENABLE ]] || die "No firewall changes were made."

info "Installing UFW from the configured APT repositories..."
apt-get update
apt-get install -y --no-install-recommends ufw

ufw default deny incoming
ufw default allow outgoing
for port in "${ports[@]}"; do
    ufw allow "${port}/tcp" comment "Small-Scripts installer"
done

# The SSH rule is in place before UFW is activated to preserve remote access.
ufw --force enable
ufw status verbose
info "UFW is enabled. Confirm a second SSH session can connect before ending this one."
