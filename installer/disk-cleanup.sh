#!/usr/bin/env bash
set -Eeuo pipefail

error() { printf 'Error: %s\n' "$*" >&2; }
die() { error "$*"; exit 1; }
info() { printf '==> %s\n' "$*"; }
heading() { printf '\n=== %s ===\n' "$*"; }
trap 'error "Disk cleanup failed at line $LINENO. Review the output above before rerunning."' ERR

require_root() { [[ $EUID -eq 0 ]] || die "Run this cleanup as root: sudo bash disk-cleanup.sh"; }
require_supported_os() {
    [[ -r /etc/os-release ]] || die "Cannot identify the operating system."
    . /etc/os-release
    [[ ${ID:-} == debian || ${ID:-} == ubuntu ]] || die "Only Debian and Ubuntu are supported (detected: ${ID:-unknown})."
}
valid_days() { [[ $1 =~ ^[0-9]+$ ]] && (( $1 >= 1 && $1 <= 3650 )); }

require_root
require_supported_os
command -v apt-get >/dev/null || die "APT is unavailable."
command -v journalctl >/dev/null || die "journalctl is unavailable."
command -v systemd-tmpfiles >/dev/null || die "systemd-tmpfiles is unavailable."

heading "Current root filesystem usage"
df -hT /

heading "Known reclaimable areas"
for directory in /var/cache/apt /var/log /tmp /var/tmp; do
    [[ -d $directory ]] && du -sh "$directory"
done
journalctl --disk-usage

read -r -p "Keep archived system-journal entries for this many days [14]: " journal_days
journal_days="${journal_days:-14}"
valid_days "$journal_days" || die "Journal retention must be a whole number between 1 and 3650."

heading "Package removal preview"
apt-get --simulate autoremove --purge

cat <<EOF
This will remove packages APT identifies as no longer needed, clear the downloaded APT
package cache, remove archived journal entries older than $journal_days days, and run
systemd-tmpfiles cleanup according to the system's existing retention policy.

It will not remove Docker resources, databases, application data, or arbitrary files.
EOF
read -r -p "Type CLEANUP to perform these storage cleanup actions: " confirm
[[ $confirm == CLEANUP ]] || die "No storage cleanup actions were performed."

apt-get autoremove --purge -y
apt-get clean
journalctl --vacuum-time="${journal_days}d"
systemd-tmpfiles --clean

heading "Updated root filesystem usage"
df -hT /
info "Storage cleanup complete."
