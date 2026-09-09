#!/usr/bin/env bash
clear
echo "############################################################################"
echo "#                          ssh-hardening Installer                         #"
echo "#               by Nico L and Kyle Smith (mrsmith9)                        #"
echo "#                   https://github.com/ipexadev/scripts                    #"
echo "#                          Last Update: 27.06.2022                         #"
echo "############################################################################"
sleep 3

set -Eeuo pipefail

readonly HARDENING_FILE="/etc/ssh/sshd_config.d/99-small-scripts-hardening.conf"

error() { printf 'Error: %s\n' "$*" >&2; }
die() { error "$*"; exit 1; }
info() { printf '==> %s\n' "$*"; }
trap 'error "SSH hardening failed at line $LINENO. The existing SSH configuration was not reloaded."' ERR

require_root() { [[ $EUID -eq 0 ]] || die "Run this installer as root: sudo bash ssh-hardening.sh"; }
require_supported_os() {
    [[ -r /etc/os-release ]] || die "Cannot identify the operating system."
    . /etc/os-release
    [[ ${ID:-} == debian || ${ID:-} == ubuntu ]] || die "Only Debian and Ubuntu are supported (detected: ${ID:-unknown})."
}
is_port() { [[ $1 =~ ^[0-9]+$ ]] && (( $1 >= 1 && $1 <= 65535 )); }
valid_user() { [[ $1 =~ ^[a-z_][a-z0-9_-]*[$]?$ ]]; }
valid_public_key() {
    [[ $1 =~ ^(ssh-ed25519|ecdsa-sha2-nistp(256|384|521)|sk-ssh-ed25519@openssh.com|sk-ecdsa-sha2-nistp256@openssh.com|ssh-rsa)[[:space:]]+[A-Za-z0-9+/=]+([[:space:]].*)?$ ]]
}

require_root
require_supported_os
command -v sshd >/dev/null || die "OpenSSH server is not installed."
grep -Eq '^[[:space:]]*Include[[:space:]]+/etc/ssh/sshd_config\.d/\*\.conf' /etc/ssh/sshd_config ||
    die "The SSH configuration does not include /etc/ssh/sshd_config.d/*.conf; refusing to add an ineffective hardening file."
sshd -t

default_user="${SUDO_USER:-}"
if [[ -z $default_user || $default_user == root ]]; then
    default_user="root"
fi
read -r -p "Account that will receive the verified SSH public key [$default_user]: " login_user
login_user="${login_user:-$default_user}"
valid_user "$login_user" && id "$login_user" >/dev/null 2>&1 || die "Enter an existing local account name."

read -r -p "Paste the SSH public key for $login_user: " public_key
valid_public_key "$public_key" || die "Enter a complete OpenSSH public key (for example, ssh-ed25519 AAAA...)."

current_port="$(sshd -T | awk '$1 == "port" { print $2; exit }')"
current_port="${current_port:-22}"
read -r -p "SSH port [$current_port]: " ssh_port
ssh_port="${ssh_port:-$current_port}"
is_port "$ssh_port" || die "SSH port must be between 1 and 65535."

if [[ $ssh_port != "$current_port" ]] && ss -ltnH | awk '{print $4}' | grep -Eq "(^|:)$ssh_port$"; then
    die "TCP port $ssh_port is already in use. Choose an unused port."
fi

cat <<EOF
The installer will install the supplied public key, require public-key authentication,
disable password and keyboard-interactive authentication, and set PermitRootLogin to
prohibit-password. It will not change firewall rules.

If UFW or an external firewall is active, allow TCP/$ssh_port before reconnecting.
EOF
read -r -p "Type HARDEN to validate and reload this SSH configuration: " confirm
[[ $confirm == HARDEN ]] || die "No changes were made."

user_home="$(getent passwd "$login_user" | cut -d: -f6)"
[[ -n $user_home && -d $user_home ]] || die "Cannot determine a valid home directory for $login_user."
install -d -m 700 -o "$login_user" -g "$(id -gn "$login_user")" "$user_home/.ssh"
touch "$user_home/.ssh/authorized_keys"
chmod 600 "$user_home/.ssh/authorized_keys"
chown "$login_user:$(id -gn "$login_user")" "$user_home/.ssh/authorized_keys"
grep -qxF "$public_key" "$user_home/.ssh/authorized_keys" ||
    printf '%s\n' "$public_key" >>"$user_home/.ssh/authorized_keys"

install -d -m 755 /etc/ssh/sshd_config.d
cat >"$HARDENING_FILE" <<EOF
Port $ssh_port
PermitRootLogin prohibit-password
PubkeyAuthentication yes
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitEmptyPasswords no
EOF

sshd -t
if systemctl list-unit-files --type=service | grep -q '^ssh\.service'; then
    systemctl reload ssh
else
    systemctl reload sshd
fi

info "SSH has been reloaded. Keep this session open and confirm a second login to $login_user on TCP/$ssh_port before disconnecting."
