#!/usr/bin/env bash
clear
echo "############################################################################"
echo "#                          Server Health Installer                         #"
echo "#               by Nico L and Kyle Smith (mrsmith9)                        #"
echo "#                   https://github.com/ipexadev/scripts                    #"
echo "#                          Last Update: 27.06.2022                         #"
echo "############################################################################"
sleep 3

set -Eeuo pipefail

error() { printf 'Error: %s\n' "$*" >&2; }
die() { error "$*"; exit 1; }
heading() { printf '\n=== %s ===\n' "$*"; }
trap 'error "Health report stopped at line $LINENO. Review the output above."' ERR

require_root() { [[ $EUID -eq 0 ]] || die "Run this report as root for complete results: sudo bash server-health.sh"; }
require_supported_os() {
    [[ -r /etc/os-release ]] || die "Cannot identify the operating system."
    . /etc/os-release
    [[ ${ID:-} == debian || ${ID:-} == ubuntu ]] || die "Only Debian and Ubuntu are supported (detected: ${ID:-unknown})."
}

require_root
require_supported_os

heading "System"
if command -v hostnamectl >/dev/null; then
    hostnamectl
else
    hostname
fi
uptime

heading "Disk usage"
df -hT -x tmpfs -x devtmpfs

heading "Memory and swap"
free -h
swapon --show

heading "Failed services"
if ! systemctl --failed --no-legend; then
    printf 'Systemd service status is unavailable in this environment.\n'
fi

heading "Listening TCP and UDP ports"
ss -tulpn

heading "Firewall"
if command -v ufw >/dev/null; then
    ufw status verbose
else
    printf 'UFW is not installed.\n'
fi

heading "Docker"
if command -v docker >/dev/null && docker info >/dev/null 2>&1; then
    docker system df
    docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
else
    printf 'Docker is not installed or its daemon is unavailable.\n'
fi

heading "Recent high-priority journal entries"
if ! journalctl --no-pager -p warning -b | tail -n 50; then
    printf 'Boot journal entries are unavailable in this environment.\n'
fi
