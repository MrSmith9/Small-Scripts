#!/usr/bin/env bash
clear
echo "############################################################################"
echo "#                          unattended Upgrade Installer                    #"
echo "#               by Nico L and Kyle Smith (mrsmith9)                        #"
echo "#                   https://github.com/ipexadev/scripts                    #"
echo "#                          Last Update: 27.06.2022                         #"
echo "############################################################################"
sleep 3

set -Eeuo pipefail

readonly AUTO_UPGRADES_FILE="/etc/apt/apt.conf.d/20auto-upgrades"
readonly LOCAL_CONFIG_FILE="/etc/apt/apt.conf.d/52unattended-upgrades-small-scripts"

error() { printf 'Error: %s\n' "$*" >&2; }
die() { error "$*"; exit 1; }
info() { printf '==> %s\n' "$*"; }
trap 'error "Security-update configuration failed at line $LINENO. Review the message above and rerun when resolved."' ERR

require_root() { [[ $EUID -eq 0 ]] || die "Run this installer as root: sudo bash unattended-upgrade.sh"; }
require_supported_os() {
    [[ -r /etc/os-release ]] || die "Cannot identify the operating system."
    . /etc/os-release
    [[ ${ID:-} == debian || ${ID:-} == ubuntu ]] || die "Only Debian and Ubuntu are supported (detected: ${ID:-unknown})."
}
valid_email() {
    [[ $1 =~ ^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$ ]] &&
        [[ $1 != *'"'* && $1 != *\\* && $1 != *';'* ]]
}

require_root
require_supported_os

read -r -p "Notification email address (leave blank to disable email notices): " notification_email
[[ -z $notification_email ]] || valid_email "$notification_email" || die "Enter a valid email address or leave it blank."

read -r -p "Automatically reboot when a security update requires it? [y/N]: " reboot_choice
case "${reboot_choice,,}" in
    y|yes) automatic_reboot=true ;;
    ""|n|no) automatic_reboot=false ;;
    *) die "Answer yes or no." ;;
esac

cat <<EOF
This enables daily package-list refreshes and unattended upgrades using the distribution's
existing security-update policy. Automatic reboot: $automatic_reboot.
EOF
read -r -p "Type CONFIGURE to apply this security-update policy: " confirm
[[ $confirm == CONFIGURE ]] || die "No changes were made."

info "Installing unattended-upgrades from the configured APT repositories..."
apt-get update
apt-get install -y --no-install-recommends unattended-upgrades

cat >"$AUTO_UPGRADES_FILE" <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF

{
    printf 'Unattended-Upgrade::Automatic-Reboot "%s";\n' "$automatic_reboot"
    if [[ -n $notification_email ]]; then
        printf 'Unattended-Upgrade::Mail "%s";\n' "$notification_email"
        printf 'Unattended-Upgrade::MailReport "on-change";\n'
    fi
} >"$LOCAL_CONFIG_FILE"

info "Unattended security updates are configured. Review activity in /var/log/unattended-upgrades/."
