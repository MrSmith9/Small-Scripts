#!/usr/bin/env bash
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

readonly NETDATA_CONFIG="/etc/netdata/netdata.conf"

error() { printf 'Error: %s\n' "$*" >&2; }
die() { error "$*"; exit 1; }
info() { printf '==> %s\n' "$*"; }
trap 'error "Monitoring installation failed at line $LINENO. Review the APT and service output above."' ERR

require_root() { [[ $EUID -eq 0 ]] || die "Run this installer as root: sudo bash monitoring.sh"; }
require_supported_os() {
    [[ -r /etc/os-release ]] || die "Cannot identify the operating system."
    . /etc/os-release
    [[ ${ID:-} == debian || ${ID:-} == ubuntu ]] || die "Only Debian and Ubuntu are supported (detected: ${ID:-unknown})."
}

require_root
require_supported_os

cat <<'EOF'
This installs Netdata from your distribution's signed APT repositories. The dashboard
will bind only to localhost by default; no firewall rule will be added.
EOF
read -r -p "Install and enable local-only Netdata monitoring? [y/N]: " confirm
[[ ${confirm,,} == y || ${confirm,,} == yes ]] || die "No changes were made."

info "Installing Netdata from the configured APT repositories..."
apt-get update
apt-get install -y --no-install-recommends netdata

install -d -m 755 /etc/netdata
cat >"$NETDATA_CONFIG" <<'EOF'
[web]
    bind to = 127.0.0.1
EOF

systemctl enable --now netdata
info "Netdata is available locally at http://127.0.0.1:19999 (use an SSH tunnel for remote access)."
