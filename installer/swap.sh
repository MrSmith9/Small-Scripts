#!/usr/bin/env bash
clear
echo "############################################################################"
echo "#                          swap Installer                                  #"
echo "#               by Nico L and Kyle Smith (mrsmith9)                        #"
echo "#                   https://github.com/ipexadev/scripts                    #"
echo "#                          Last Update: 27.06.2022                         #"
echo "############################################################################"
sleep 3

set -Eeuo pipefail

readonly SWAP_FILE="/swapfile"

error() { printf 'Error: %s\n' "$*" >&2; }
die() { error "$*"; exit 1; }
info() { printf '==> %s\n' "$*"; }
trap 'error "Swap setup failed at line $LINENO. Review the message above and rerun when resolved."' ERR

require_root() { [[ $EUID -eq 0 ]] || die "Run this installer as root: sudo bash swap.sh"; }
require_supported_os() {
    [[ -r /etc/os-release ]] || die "Cannot identify the operating system."
    . /etc/os-release
    [[ ${ID:-} == debian || ${ID:-} == ubuntu ]] || die "Only Debian and Ubuntu are supported (detected: ${ID:-unknown})."
}
valid_size() { [[ $1 =~ ^[1-9][0-9]*[KMG]$ ]]; }

require_root
require_supported_os

read -r -p "Swap size (for example 2G; minimum 512M) [2G]: " swap_size
swap_size="${swap_size:-2G}"
valid_size "$swap_size" || die "Use a whole positive size with K, M, or G suffix (for example 2G)."
requested_bytes="$(numfmt --from=iec "$swap_size")"
((requested_bytes >= 512 * 1024 * 1024)) || die "Swap size must be at least 512M."
available_bytes="$(df --output=avail -B1 / | tail -n 1 | tr -d ' ')"
((available_bytes > requested_bytes)) || die "Not enough free disk space on /. Available: $available_bytes bytes."

[[ ! -e $SWAP_FILE ]] || die "$SWAP_FILE already exists; refusing to overwrite it."
if swapon --show --noheadings | grep -q .; then
    info "An existing swap device is active:"
    swapon --show
fi

read -r -p "Create $SWAP_FILE, activate it, and persist it in /etc/fstab? [y/N]: " confirm
[[ ${confirm,,} == y || ${confirm,,} == yes ]] || die "No changes were made."

if ! fallocate -l "$swap_size" "$SWAP_FILE"; then
    info "fallocate is unavailable on this filesystem; creating the swap file with dd."
    dd if=/dev/zero of="$SWAP_FILE" bs=1M count="$((requested_bytes / 1024 / 1024))" status=progress
fi
chmod 600 "$SWAP_FILE"
mkswap "$SWAP_FILE"
swapon "$SWAP_FILE"
grep -qF "$SWAP_FILE none swap sw 0 0" /etc/fstab || printf '%s\n' "$SWAP_FILE none swap sw 0 0" >>/etc/fstab
swapon --show
info "Swap is active and will persist after reboot."
