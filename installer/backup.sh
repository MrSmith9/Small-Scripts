#!/usr/bin/env bash
clear
echo "############################################################################"
echo "#                          Backup Installer                                #"
sleep 1
clear
echo "############################################################################"
echo "#                          Adguard Home Installer                          #"
echo "#               by Nico L and Kyle Smith (mrsmith9)                        #"
echo "#                   https://github.com/ipexadev/scripts                    #"
echo "#                          Last Update: 27.06.2022                         #"
echo "############################################################################"
sleep 3

set -Eeuo pipefail

readonly CONFIG_DIR="/etc/small-scripts"
readonly CONFIG_FILE="$CONFIG_DIR/backup.conf"
readonly RUNNER="/usr/local/sbin/small-scripts-backup"
readonly CRON_FILE="/etc/cron.d/small-scripts-backup"

error() { printf 'Error: %s\n' "$*" >&2; }
die() { error "$*"; exit 1; }
info() { printf '==> %s\n' "$*"; }
trap 'error "Backup setup failed at line $LINENO. Review the message above and rerun when resolved."' ERR

require_root() { [[ $EUID -eq 0 ]] || die "Run this installer as root: sudo bash backup.sh"; }
require_supported_os() {
    [[ -r /etc/os-release ]] || die "Cannot identify the operating system."
    . /etc/os-release
    [[ ${ID:-} == debian || ${ID:-} == ubuntu ]] || die "Only Debian and Ubuntu are supported (detected: ${ID:-unknown})."
}
valid_retention() { [[ $1 =~ ^[0-9]+$ ]] && (( $1 >= 1 && $1 <= 3650 )); }

create_backup() {
    local timestamp archive
    timestamp="$(date --utc +%Y%m%dT%H%M%SZ)"
    archive="$BACKUP_DESTINATION/server-backup-$timestamp.tar.gz"
    tar --create --gzip --file="$archive" -- "${BACKUP_SOURCES[@]}"

    # Installer-owned archives have fixed names, so sorted newline-delimited paths are safe here.
    mapfile -t old_archives < <(find "$BACKUP_DESTINATION" -maxdepth 1 -type f -name 'server-backup-*.tar.gz' -printf '%T@ %p\n' |
        sort -rn | tail -n "+$((BACKUP_RETENTION + 1))" | cut -d' ' -f2-)
    if ((${#old_archives[@]})); then
        rm -- "${old_archives[@]}"
    fi
    printf 'Created %s\n' "$archive"
}

run_scheduled_backup() {
    require_root
    [[ -r $CONFIG_FILE ]] || die "Backup configuration is missing: $CONFIG_FILE"
    # This root-owned installer-generated file contains quoted local paths and a numeric retention count.
    . "$CONFIG_FILE"
    create_backup
}

if [[ ${1:-} == --run ]]; then
    run_scheduled_backup
    exit 0
fi

require_root
require_supported_os

read -r -p "Local backup destination (absolute path): " BACKUP_DESTINATION
[[ $BACKUP_DESTINATION == /* && $BACKUP_DESTINATION != / ]] || die "Use an absolute destination path other than /."
if [[ -e $BACKUP_DESTINATION && ! -d $BACKUP_DESTINATION ]]; then
    die "Backup destination exists but is not a directory."
fi

read -r -p "Directories to archive, separated by spaces [/etc /home /var/www]: " source_input
source_input="${source_input:-/etc /home /var/www}"
read -r -a BACKUP_SOURCES <<<"$source_input"
((${#BACKUP_SOURCES[@]})) || die "Select at least one source directory."
for index in "${!BACKUP_SOURCES[@]}"; do
    BACKUP_SOURCES[index]="${BACKUP_SOURCES[index]%/}"
    source_dir="${BACKUP_SOURCES[index]}"
    [[ $source_dir == /* && -d $source_dir && $source_dir != / ]] ||
        die "Each backup source must be an existing absolute directory other than /: $source_dir"
    case "$BACKUP_DESTINATION/" in
        "$source_dir/"*) die "The backup destination must not be inside a source directory: $source_dir" ;;
    esac
done

read -r -p "Number of archives to retain [7]: " BACKUP_RETENTION
BACKUP_RETENTION="${BACKUP_RETENTION:-7}"
valid_retention "$BACKUP_RETENTION" || die "Retention must be a whole number between 1 and 3650."

read -r -p "Nightly backup hour in UTC (0-23) [2]: " backup_hour
backup_hour="${backup_hour:-2}"
[[ $backup_hour =~ ^([0-9]|1[0-9]|2[0-3])$ ]] || die "Backup hour must be from 0 through 23."

printf 'Archives from: %s\nDestination: %s\nRetention: %s archive(s)\nSchedule: daily at %s:00 UTC\n' \
    "${BACKUP_SOURCES[*]}" "$BACKUP_DESTINATION" "$BACKUP_RETENTION" "$backup_hour"
read -r -p "Create an initial archive and install this scheduled backup? [y/N]: " confirm
[[ ${confirm,,} == y || ${confirm,,} == yes ]] || die "No changes were made."

info "Installing and enabling the cron scheduler..."
apt-get update
apt-get install -y --no-install-recommends cron
systemctl enable --now cron

install -d -m 700 "$BACKUP_DESTINATION" "$CONFIG_DIR"
{
    printf 'BACKUP_DESTINATION=%q\n' "$BACKUP_DESTINATION"
    printf 'BACKUP_RETENTION=%q\n' "$BACKUP_RETENTION"
    printf 'BACKUP_SOURCES=('
    printf '%q ' "${BACKUP_SOURCES[@]}"
    printf ')\n'
} >"$CONFIG_FILE"
chmod 600 "$CONFIG_FILE"

create_backup
install -m 700 "$0" "$RUNNER"
printf '0 %s * * * root %s --run >> /var/log/small-scripts-backup.log 2>&1\n' "$backup_hour" "$RUNNER" >"$CRON_FILE"
chmod 644 "$CRON_FILE"
info "Backups are scheduled daily. Configuration: $CONFIG_FILE"
