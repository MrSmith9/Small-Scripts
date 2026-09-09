#!/usr/bin/env bash
set -Eeuo pipefail

error() { printf 'Error: %s\n' "$*" >&2; }
die() { error "$*"; exit 1; }
info() { printf '==> %s\n' "$*"; }
trap 'error "Docker cleanup failed at line $LINENO. Review Docker's output above."' ERR

require_root() { [[ $EUID -eq 0 ]] || die "Run this cleanup as root: sudo bash docker-cleanup.sh"; }
require_supported_os() {
    [[ -r /etc/os-release ]] || die "Cannot identify the operating system."
    . /etc/os-release
    [[ ${ID:-} == debian || ${ID:-} == ubuntu ]] || die "Only Debian and Ubuntu are supported (detected: ${ID:-unknown})."
}

require_root
require_supported_os

command -v docker >/dev/null || die "Docker is not installed or is unavailable in PATH."
docker info >/dev/null || die "The Docker daemon is not running or cannot be reached."

info "Current Docker disk usage:"
docker system df
cat <<'EOF'

This removes all stopped containers, unused networks, dangling and unused images,
and unused build cache. It does not remove named volumes unless separately approved.
EOF
read -r -p "Type CLEANUP to remove these unused Docker resources: " confirm
[[ $confirm == CLEANUP ]] || die "No Docker resources were removed."

docker container prune --force
docker network prune --force
docker image prune --all --force
docker builder prune --all --force

read -r -p "Type VOLUMES to also delete ALL unused Docker volumes: " volume_confirm
if [[ $volume_confirm == VOLUMES ]]; then
    docker volume prune --force
else
    info "Unused volumes were preserved."
fi

info "Docker cleanup complete."
docker system df
