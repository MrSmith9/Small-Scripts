#!/usr/bin/env bash
clear
echo "############################################################################"
echo "#                          wireguard Installer                             #"
echo "#               by Nico L and Kyle Smith (mrsmith9)                        #"
echo "#                   https://github.com/ipexadev/scripts                    #"
echo "#                          Last Update: 27.06.2022                         #"
echo "############################################################################"
sleep 3


set -Eeuo pipefail

error() { printf 'Error: %s\n' "$*" >&2; }
die() { error "$*"; exit 1; }
info() { printf '==> %s\n' "$*"; }
trap 'error "WireGuard setup failed at line $LINENO. Review the message above and rerun when resolved."' ERR

require_root() { [[ $EUID -eq 0 ]] || die "Run this installer as root: sudo bash wireguard.sh"; }
require_supported_os() {
    [[ -r /etc/os-release ]] || die "Cannot identify the operating system."
    . /etc/os-release
    [[ ${ID:-} == debian || ${ID:-} == ubuntu ]] || die "Only Debian and Ubuntu are supported (detected: ${ID:-unknown})."
}
is_port() { [[ $1 =~ ^[0-9]+$ ]] && (( $1 >= 1 && $1 <= 65535 )); }
valid_interface() { [[ $1 =~ ^[a-zA-Z0-9_.-]{1,15}$ ]]; }
valid_ipv4_cidr() {
    local ip prefix octet
    [[ $1 =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}/([0-9]|[12][0-9]|3[0-2])$ ]] || return 1
    ip="${1%/*}"
    IFS=. read -r -a octets <<<"$ip"
    for octet in "${octets[@]}"; do ((octet <= 255)) || return 1; done
}
valid_ipv4() {
    local octet
    [[ $1 =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1
    IFS=. read -r -a octets <<<"$1"
    for octet in "${octets[@]}"; do ((octet <= 255)) || return 1; done
}
valid_endpoint() {
    if [[ $1 =~ ^[0-9.]+$ ]]; then
        valid_ipv4 "$1"
    else
        [[ $1 =~ ^([A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?)(\.([A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?))*$ ]] &&
            ((${#1} <= 253))
    fi
}

require_root
require_supported_os

read -r -p "WireGuard interface name [wg0]: " interface
interface="${interface:-wg0}"
valid_interface "$interface" || die "Interface names may use letters, numbers, dots, underscores, and hyphens (15 characters maximum)."

read -r -p "Server tunnel IPv4 CIDR [10.66.66.1/24]: " server_cidr
server_cidr="${server_cidr:-10.66.66.1/24}"
valid_ipv4_cidr "$server_cidr" || die "Enter a valid IPv4 CIDR, such as 10.66.66.1/24."
prefix="${server_cidr#*/}"
((prefix >= 8 && prefix <= 30)) || die "Use a tunnel prefix between /8 and /30."
server_ip="${server_cidr%/*}"
IFS=. read -r first second third fourth <<<"$server_ip"
((fourth >= 1 && fourth < 254)) || die "Use a server address with a final octet from 1 through 253."
client_ip="$first.$second.$third.$((fourth + 1))"

read -r -p "UDP listen port [51820]: " listen_port
listen_port="${listen_port:-51820}"
is_port "$listen_port" || die "UDP port must be between 1 and 65535."

read -r -p "Public server hostname or IPv4 address for the client endpoint: " endpoint
valid_endpoint "$endpoint" || die "Enter a valid hostname or IPv4 address."

config_file="/etc/wireguard/$interface.conf"
[[ ! -e $config_file ]] || die "$config_file already exists; refusing to overwrite an existing WireGuard configuration."

cat <<EOF
WireGuard will create $config_file and generate a server and one client key. It will
not alter your firewall. Ensure UDP/$listen_port is allowed by your provider/firewall.
EOF
read -r -p "Type CONFIGURE to generate the configuration: " confirm
[[ $confirm == CONFIGURE ]] || die "No changes were made."

apt-get update
apt-get install -y --no-install-recommends wireguard

umask 077
server_private_key="$(wg genkey)"
server_public_key="$(printf '%s' "$server_private_key" | wg pubkey)"
client_private_key="$(wg genkey)"
client_public_key="$(printf '%s' "$client_private_key" | wg pubkey)"

install -d -m 700 /etc/wireguard
cat >"$config_file" <<EOF
[Interface]
Address = $server_cidr
ListenPort = $listen_port
PrivateKey = $server_private_key

[Peer]
PublicKey = $client_public_key
AllowedIPs = $client_ip/32
EOF
chmod 600 "$config_file"

read -r -p "Bring up and enable $interface now (this changes network configuration)? [y/N]: " activate
if [[ ${activate,,} == y || ${activate,,} == yes ]]; then
    systemctl enable --now "wg-quick@$interface"
    info "WireGuard interface $interface is enabled."
else
    info "Configuration saved but not activated. Start it with: sudo systemctl enable --now wg-quick@$interface"
fi

cat <<EOF

Save the following client configuration securely (it contains the client's private key):
[Interface]
PrivateKey = $client_private_key
Address = $client_ip/32
DNS = 1.1.1.1

[Peer]
PublicKey = $server_public_key
Endpoint = $endpoint:$listen_port
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
EOF
