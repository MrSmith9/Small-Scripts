#!/usr/bin/env bash
set -Eeuo pipefail

readonly CONFIG_DIR="/etc/small-scripts"
readonly CONFIG_FILE="$CONFIG_DIR/restic-backup.conf"
readonly PASSWORD_FILE="$CONFIG_DIR/restic-password"
readonly RUNNER="/usr/local/sbin/small-scripts-restic-backup"
readonly CRON_FILE="/etc/cron.d/small-scripts-restic-backup"

error() { printf 'Error: %s\n' "$*" >&2; }
die() { error "$*"; exit 1; }
info() { printf '==> %s\n' "$*"; }
trap 'error "Restic backup setup failed at line $LINENO. Review repository access and the message above."' ERR

require_root() { [[ $EUID -eq 0 ]] || die "Run this installer as root: sudo bash restic-backup.sh"; }
require_supported_os() {
    [[ -r /etc/os-release ]] || die "Cannot identify the operating system."
    . /etc/os-release
    [[ ${ID:-} == debian || ${ID:-} == ubuntu ]] || die "Only Debian and Ubuntu are supported (detected: ${ID:-unknown})."
}
valid_retention() { [[ $1 =~ ^[0-9]+$ ]] && (( $1 >= 1 && $1 <= 3650 )); }
valid_repository() {
    [[ -n $1 && $1 != *[[:space:]]* ]] &&
        ([[ $1 == /* ]] || [[ $1 =~ ^(sftp|rest|s3|b2|rclone|azure|gs):.+$ ]])
}

run_backup() {
    [[ -r $CONFIG_FILE && -r $PASSWORD_FILE ]] || die "Restic configuration is missing under $CONFIG_DIR."
    . "$CONFIG_FILE"
    restic --repo "$RESTIC_REPOSITORY" --password-file "$PASSWORD_FILE" backup "${RESTIC_SOURCES[@]}"
    restic --repo "$RESTIC_REPOSITORY" --password-file "$PASSWORD_FILE" forget --prune --keep-last "$RESTIC_RETENTION"
}

if [[ ${1:-} == --run ]]; then
    require_root
    run_backup
    exit 0
fi

require_root
require_supported_os

cat <<'EOF'
Restic creates encrypted backups. Configure remote repository credentials separately using
root-owned SSH keys or your supported cloud-provider credential mechanism; never put a
credential in the repository URL.
EOF
read -r -p "Restic repository (absolute local path, sftp:, rest:, s3:, b2:, rclone:, azure:, or gs:): " RESTIC_REPOSITORY
valid_repository "$RESTIC_REPOSITORY" || die "Enter a supported repository without whitespace or embedded credentials."

read -r -p "Directories to back up, separated by spaces [/etc /home /var/www]: " source_input
source_input="${source_input:-/etc /home /var/www}"
read -r -a RESTIC_SOURCES <<<"$source_input"
((${#RESTIC_SOURCES[@]})) || die "Select at least one source directory."
for source_dir in "${RESTIC_SOURCES[@]}"; do
    [[ $source_dir == /* && -d $source_dir && $source_dir != / ]] ||
        die "Each source must be an existing absolute directory other than /: $source_dir"
done

read -r -p "Number of snapshots to retain [7]: " RESTIC_RETENTION
RESTIC_RETENTION="${RESTIC_RETENTION:-7}"
valid_retention "$RESTIC_RETENTION" || die "Retention must be a whole number between 1 and 3650."

read -r -p "Nightly backup hour in UTC (0-23) [3]: " backup_hour
backup_hour="${backup_hour:-3}"
[[ $backup_hour =~ ^([0-9]|1[0-9]|2[0-3])$ ]] || die "Backup hour must be from 0 through 23."

read -r -s -p "New Restic repository password: " restic_password
printf '\n'
[[ ${#restic_password} -ge 16 ]] || die "Use a repository password of at least 16 characters."
read -r -s -p "Confirm Restic repository password: " password_confirmation
printf '\n'
[[ $restic_password == "$password_confirmation" ]] || die "The repository passwords did not match."
unset password_confirmation

read -r -p "Is this a new, empty repository that should be initialized? [y/N]: " new_repository_choice
case "${new_repository_choice,,}" in
    y|yes) new_repository=true ;;
    ""|n|no) new_repository=false ;;
    *) die "Answer yes or no." ;;
esac

printf 'Repository: %s\nSources: %s\nRetention: %s snapshot(s)\nSchedule: daily at %s:00 UTC\n' \
    "$RESTIC_REPOSITORY" "${RESTIC_SOURCES[*]}" "$RESTIC_RETENTION" "$backup_hour"
read -r -p "Type CONFIGURE to initialize or use this repository and schedule backups: " confirm
[[ $confirm == CONFIGURE ]] || die "No changes were made."

apt-get update
apt-get install -y --no-install-recommends cron restic
systemctl enable --now cron
install -d -m 700 "$CONFIG_DIR"
printf '%s\n' "$restic_password" >"$PASSWORD_FILE"
chmod 600 "$PASSWORD_FILE"
unset restic_password

{
    printf 'RESTIC_REPOSITORY=%q\n' "$RESTIC_REPOSITORY"
    printf 'RESTIC_RETENTION=%q\n' "$RESTIC_RETENTION"
    printf 'RESTIC_SOURCES=('
    printf '%q ' "${RESTIC_SOURCES[@]}"
    printf ')\n'
} >"$CONFIG_FILE"
chmod 600 "$CONFIG_FILE"

if [[ $new_repository == true ]]; then
    info "Initializing the Restic repository..."
    restic --repo "$RESTIC_REPOSITORY" --password-file "$PASSWORD_FILE" init
else
    restic --repo "$RESTIC_REPOSITORY" --password-file "$PASSWORD_FILE" cat config >/dev/null
fi
run_backup

install -m 700 "$0" "$RUNNER"
printf '0 %s * * * root %s --run >> /var/log/small-scripts-restic-backup.log 2>&1\n' "$backup_hour" "$RUNNER" >"$CRON_FILE"
chmod 644 "$CRON_FILE"
info "Encrypted Restic backups are scheduled daily. Keep $PASSWORD_FILE secure; losing it prevents restoration."
