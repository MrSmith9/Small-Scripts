#!/usr/bin/env bash
clear
echo "############################################################################"
echo "#                          logrotate Installer                             #"
echo "#               by Nico L and Kyle Smith (mrsmith9)                        #"
echo "#                   https://github.com/ipexadev/scripts                    #"
echo "#                          Last Update: 27.06.2022                         #"
echo "############################################################################"
sleep 3

set -Eeuo pipefail

readonly CONFIG_FILE="/etc/logrotate.d/small-scripts-custom"

error() { printf 'Error: %s\n' "$*" >&2; }
die() { error "$*"; exit 1; }
info() { printf '==> %s\n' "$*"; }
trap 'error "Log rotation setup failed at line $LINENO. The new configuration was not installed."' ERR

require_root() { [[ $EUID -eq 0 ]] || die "Run this installer as root: sudo bash logrotate.sh"; }
require_supported_os() {
    [[ -r /etc/os-release ]] || die "Cannot identify the operating system."
    . /etc/os-release
    [[ ${ID:-} == debian || ${ID:-} == ubuntu ]] || die "Only Debian and Ubuntu are supported (detected: ${ID:-unknown})."
}
valid_retention() { [[ $1 =~ ^[0-9]+$ ]] && (( $1 >= 1 && $1 <= 3650 )); }
valid_size() { [[ $1 =~ ^[1-9][0-9]*[KMG]$ ]]; }
valid_log_directory() {
    [[ $1 =~ ^/[A-Za-z0-9._/-]+$ && $1 != /var/log && -d $1 && $1 != *..* ]]
}

require_root
require_supported_os

read -r -p "Application log directory (absolute path, not /var/log itself): " log_directory
valid_log_directory "$log_directory" ||
    die "Use an existing absolute application-log directory without spaces, and do not use /var/log itself."

read -r -p "Number of rotated archives to keep [14]: " retention
retention="${retention:-14}"
valid_retention "$retention" || die "Retention must be a whole number between 1 and 3650."

read -r -p "Rotate when a log reaches this size [100M]: " rotation_size
rotation_size="${rotation_size:-100M}"
valid_size "$rotation_size" || die "Use a whole positive size with K, M, or G suffix (for example 100M)."

cat <<EOF
This adds a logrotate rule for $log_directory/*.log. It uses copytruncate so applications
do not need a restart, compresses rotated logs, and retains $retention archives.
EOF
read -r -p "Type CONFIGURE to install this log rotation rule: " confirm
[[ $confirm == CONFIGURE ]] || die "No changes were made."

apt-get update
apt-get install -y --no-install-recommends logrotate

temporary_config="$(mktemp)"
trap 'rm -f "$temporary_config"' EXIT
cat >"$temporary_config" <<EOF
$log_directory/*.log {
    daily
    rotate $retention
    size $rotation_size
    missingok
    notifempty
    compress
    delaycompress
    copytruncate
}
EOF
logrotate --debug "$temporary_config"
install -m 644 "$temporary_config" "$CONFIG_FILE"

if systemctl list-unit-files --type=timer | grep -q '^logrotate\.timer'; then
    systemctl enable --now logrotate.timer
fi
info "Log rotation is configured. Review it safely with: sudo logrotate --debug $CONFIG_FILE"
