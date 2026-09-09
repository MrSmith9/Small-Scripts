#!/usr/bin/env bash
set -Eeuo pipefail

PANEL_DIR="/var/www/pterodactyl"
PANEL_USER="www-data"
DB_NAME="pterodactyl"
DB_USER="pterodactyl"

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

status() { echo -e "${GREEN}[*]${NC} $*"; }
warning() { echo -e "${YELLOW}[!]${NC} $*"; }
error() { echo -e "${RED}[!]${NC} $*" >&2; }
die() { error "$*"; exit 1; }

trap 'error "Installation stopped at line $LINENO. Review the error above, correct it, and run the script again."' ERR

require_root() {
    [[ $EUID -eq 0 ]] || die "Run this installer as root: sudo bash pterodactyl.sh"
}

detect_os() {
    [[ -r /etc/os-release ]] || die "Unable to identify the operating system."
    # shellcheck disable=SC1091
    . /etc/os-release

    case "$ID" in
        debian|ubuntu)
            ;;
        *)
            die "This installer supports Debian and Ubuntu only. Detected: $ID."
            ;;
    esac
}

prompt_configuration() {
    echo
    read -r -p "Panel domain or public IP address: " PANEL_HOST
    [[ -n "$PANEL_HOST" ]] || die "A domain or public IP address is required."
    [[ "$PANEL_HOST" =~ ^[A-Za-z0-9.-]+$ ]] || die "The domain or IP address contains unsupported characters."

    read -r -p "Enable a free Let's Encrypt certificate? [y/N]: " enable_tls
    enable_tls="${enable_tls,,}"

    if [[ "$enable_tls" == "y" || "$enable_tls" == "yes" ]]; then
        [[ ! "$PANEL_HOST" =~ ^[0-9.]+$ ]] || die "Let's Encrypt requires a domain name, not an IP address."
        read -r -p "Email address for certificate expiry notices: " CERT_EMAIL
        [[ "$CERT_EMAIL" == *@*.* ]] || die "A valid email address is required for Let's Encrypt."
        APP_URL="https://$PANEL_HOST"
        ENABLE_TLS=true
    else
        APP_URL="http://$PANEL_HOST"
        ENABLE_TLS=false
        warning "The panel will use HTTP. Use HTTPS for a production panel."
    fi
}

install_dependencies() {
    status "Updating packages and installing panel dependencies..."
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get install -y --no-install-recommends \
        ca-certificates composer cron curl mariadb-server nginx openssl \
        php php-bcmath php-cli php-curl php-fpm php-gd php-intl php-mbstring \
        php-mysql php-redis php-xml php-zip redis-server supervisor tar unzip

    if [[ "$ENABLE_TLS" == true ]]; then
        apt-get install -y --no-install-recommends certbot python3-certbot-nginx
    fi

    PHP_VERSION="$(php -r 'echo PHP_MAJOR_VERSION . "." . PHP_MINOR_VERSION;')"
    case "$PHP_VERSION" in
        8.2|8.3)
            ;;
        *)
            die "Pterodactyl requires PHP 8.2 or 8.3; this system installed PHP $PHP_VERSION."
            ;;
    esac
    PHP_FPM_SERVICE="php${PHP_VERSION}-fpm"
    PHP_FPM_SOCKET="/run/php/php${PHP_VERSION}-fpm.sock"
}

download_panel() {
    [[ ! -e "$PANEL_DIR" ]] || [[ -z "$(find "$PANEL_DIR" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]] ||
        die "$PANEL_DIR is not empty. Refusing to overwrite an existing installation."

    status "Downloading the latest Pterodactyl Panel..."
    install -d -m 755 "$PANEL_DIR"
    curl --fail --location --show-error --silent \
        "https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz" |
        tar --extract --gzip --file - --directory "$PANEL_DIR"
}

set_env() {
    local key="$1"
    local value="$2"
    local escaped_value

    escaped_value="$(printf '%s' "$value" | sed 's/[\/&|]/\\&/g')"
    sed -i -E "s|^${key}=.*|${key}=${escaped_value}|" "$PANEL_DIR/.env"
}

configure_panel() {
    status "Configuring the panel..."
    DB_PASSWORD="$(openssl rand -hex 24)"

    systemctl enable --now mariadb redis-server

    cp "$PANEL_DIR/.env.example" "$PANEL_DIR/.env"
    set_env "APP_ENV" "production"
    set_env "APP_DEBUG" "false"
    set_env "APP_URL" "$APP_URL"
    set_env "DB_CONNECTION" "mysql"
    set_env "DB_HOST" "127.0.0.1"
    set_env "DB_PORT" "3306"
    set_env "DB_DATABASE" "$DB_NAME"
    set_env "DB_USERNAME" "$DB_USER"
    set_env "DB_PASSWORD" "$DB_PASSWORD"
    set_env "CACHE_DRIVER" "redis"
    set_env "SESSION_DRIVER" "redis"
    set_env "QUEUE_CONNECTION" "redis"
    set_env "REDIS_HOST" "127.0.0.1"
    set_env "REDIS_PORT" "6379"

    cd "$PANEL_DIR"
    composer install --no-dev --optimize-autoloader --no-interaction
    php artisan key:generate --force

    status "Creating the database..."
    mysql --execute "
        CREATE DATABASE IF NOT EXISTS \`$DB_NAME\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
        CREATE USER IF NOT EXISTS '$DB_USER'@'127.0.0.1' IDENTIFIED BY '$DB_PASSWORD';
        ALTER USER '$DB_USER'@'127.0.0.1' IDENTIFIED BY '$DB_PASSWORD';
        GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'127.0.0.1';
        FLUSH PRIVILEGES;"

    php artisan migrate --seed --force
    php artisan optimize

    chown -R "$PANEL_USER:$PANEL_USER" "$PANEL_DIR/storage" "$PANEL_DIR/bootstrap/cache"
    chmod -R 775 "$PANEL_DIR/storage" "$PANEL_DIR/bootstrap/cache"
}

configure_services() {
    status "Configuring the queue worker, web server, and scheduler..."
    cat > /etc/supervisor/conf.d/pterodactyl.conf <<EOF
[program:pterodactyl-worker]
process_name=%(program_name)s_%(process_num)02d
command=/usr/bin/php $PANEL_DIR/artisan queue:work redis --sleep=3 --tries=3 --max-time=3600
autostart=true
autorestart=true
stopasgroup=true
killasgroup=true
user=$PANEL_USER
numprocs=1
redirect_stderr=true
stdout_logfile=/var/log/pterodactyl-worker.log
EOF

    cat > /etc/nginx/sites-available/pterodactyl.conf <<EOF
server {
    listen 80;
    server_name $PANEL_HOST;
    root $PANEL_DIR/public;
    index index.php;

    client_max_body_size 100m;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php$ {
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$realpath_root\$fastcgi_script_name;
        fastcgi_param DOCUMENT_ROOT \$realpath_root;
        fastcgi_pass unix:$PHP_FPM_SOCKET;
        fastcgi_index index.php;
    }

    location ~ /\.(?!well-known).* {
        deny all;
    }
}
EOF

    ln -sfn /etc/nginx/sites-available/pterodactyl.conf /etc/nginx/sites-enabled/pterodactyl.conf
    rm -f /etc/nginx/sites-enabled/default
    printf '* * * * * %s cd %s && /usr/bin/php artisan schedule:run >> /dev/null 2>&1\n' \
        "$PANEL_USER" "$PANEL_DIR" > /etc/cron.d/pterodactyl
    chmod 644 /etc/cron.d/pterodactyl

    nginx -t
    systemctl enable --now mariadb redis-server supervisor "$PHP_FPM_SERVICE" nginx cron
    supervisorctl reread
    supervisorctl update
}

install_certificate() {
    [[ "$ENABLE_TLS" == true ]] || return

    status "Requesting the Let's Encrypt certificate..."
    certbot --nginx --non-interactive --agree-tos --redirect \
        --email "$CERT_EMAIL" --domain "$PANEL_HOST"
}

main() {
    clear
    echo "======================================================"
    echo "             Pterodactyl Panel Installer"
    echo "======================================================"
    echo

    require_root
    detect_os
    prompt_configuration
    install_dependencies
    download_panel
    configure_panel
    configure_services
    install_certificate

    echo
    status "Pterodactyl Panel installation is complete."
    status "Open $APP_URL and create the first administrator account with:"
    echo "    cd $PANEL_DIR && php artisan p:user:make"
}

main "$@"
