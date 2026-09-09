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

error() { printf 'Error: %s\n' "$*" >&2; }
die() { error "$*"; exit 1; }
info() { printf '==> %s\n' "$*"; }
trap 'error "Certificate setup failed at line $LINENO. Check DNS, web-server configuration, and port 80."' ERR

require_root() { [[ $EUID -eq 0 ]] || die "Run this installer as root: sudo bash certbot.sh"; }
require_supported_os() {
    [[ -r /etc/os-release ]] || die "Cannot identify the operating system."
    . /etc/os-release
    [[ ${ID:-} == debian || ${ID:-} == ubuntu ]] || die "Only Debian and Ubuntu are supported (detected: ${ID:-unknown})."
}
valid_domain() {
    [[ $1 =~ ^([A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?\.)+[A-Za-z]{2,63}$ ]] &&
        ((${#1} <= 253))
}
valid_email() { [[ $1 =~ ^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$ ]]; }

require_root
require_supported_os

read -r -p "Web server to configure (nginx/apache): " web_server
web_server="${web_server,,}"
[[ $web_server == nginx || $web_server == apache ]] || die "Choose either nginx or apache."

read -r -p "Domain name for the certificate: " domain
domain="${domain,,}"
valid_domain "$domain" || die "Enter a valid fully qualified domain name, such as example.com."

read -r -p "Email address for expiry notices: " email
valid_email "$email" || die "Enter a valid email address."

read -r -p "Certbot will update the $web_server configuration for $domain and redirect HTTP to HTTPS. Continue? [y/N]: " confirm
[[ ${confirm,,} == y || ${confirm,,} == yes ]] || die "No changes were made."

info "Installing Certbot and its $web_server plugin from the configured APT repositories..."
apt-get update
if [[ $web_server == nginx ]]; then
    command -v nginx >/dev/null || die "Nginx is not installed. Install and configure its HTTP server block first."
    apt-get install -y --no-install-recommends certbot python3-certbot-nginx
    certbot --nginx --non-interactive --agree-tos --email "$email" --redirect -d "$domain"
else
    command -v apache2 >/dev/null || die "Apache is not installed. Install and configure its HTTP virtual host first."
    apt-get install -y --no-install-recommends certbot python3-certbot-apache
    certbot --apache --non-interactive --agree-tos --email "$email" --redirect -d "$domain"
fi

systemctl enable --now certbot.timer
info "Certificate installed for $domain. Renewal is managed by certbot.timer."
