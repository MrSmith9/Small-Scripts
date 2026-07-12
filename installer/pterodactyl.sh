#!/bin/bash
set -euo pipefail
sleep 1
clear
echo "############################################################################"
echo "#                          Pterodactyl Installer                                 #"
echo "#               by Nico L and Kyle Smith (mrsmith9)                        #"
echo "#                   https://github.com/ipexadev/scripts                    #"
echo "#                          Last Update: 2026-06-28                         #"
echo "############################################################################"
sleep 1

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Functions
print_status() {
    echo -e "${GREEN}[*]${NC} $1"
}

print_error() {
    echo -e "${RED}[!]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    print_error "This script must be run as root"
    exit 1
fi

print_status "Starting Pterodactyl Panel Installation"

# Detect OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
else
    print_error "Cannot detect OS"
    exit 1
fi

print_status "Detected OS: $OS"

# Update system
print_status "Updating system packages..."
if [ "$OS" = "ubuntu" ] || [ "$OS" = "debian" ]; then
    apt-get update
    apt-get upgrade -y
    
    # Install dependencies
    print_status "Installing dependencies..."
    apt-get install -y curl wget git unzip tar zip \
        php8.1 php8.1-{cli,gd,mysql,pdo,mbstring,tokenizer,bcmath,xml,fpm,curl,zip} \
        nginx \
        mysql-server \
        redis-server \
        supervisor \
        curl \
        build-essential \
        certbot \
        python3-certbot-nginx
    
elif [ "$OS" = "centos" ] || [ "$OS" = "rhel" ]; then
    yum update -y
    
    print_status "Installing dependencies..."
    yum install -y curl wget git unzip tar zip \
        php php-cli php-gd php-mysql php-pdo php-mbstring \
        php-tokenizer php-bcmath php-xml php-fpm php-curl php-zip \
        nginx \
        mariadb-server \
        redis \
        supervisor \
        curl \
        gcc-c++ \
        make \
        certbot \
        python3-certbot-nginx
    
else
    print_error "Unsupported OS: $OS"
    exit 1
fi

# Create Pterodactyl directory
print_status "Creating Pterodactyl directories..."
mkdir -p /var/www/pterodactyl
cd /var/www/pterodactyl

# Download Pterodactyl Panel
print_status "Downloading Pterodactyl Panel..."
curl -L https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz | tar -xzv

# Set permissions
print_status "Setting permissions..."
chown -R www-data:www-data /var/www/pterodactyl
chmod -R 755 /var/www/pterodactyl
chmod -R 777 /var/www/pterodactyl/storage
chmod -R 777 /var/www/pterodactyl/bootstrap/cache

# Install Composer
print_status "Installing Composer..."
curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# Install PHP dependencies
print_status "Installing PHP dependencies..."
cd /var/www/pterodactyl
composer install --no-dev --optimize-autoloader

# Copy environment file
print_status "Setting up environment..."
cp .env.example .env

# Generate application key
print_status "Generating application key..."
php artisan key:generate --force

# Create database
print_status "Creating MySQL database..."
mysql -u root -e "CREATE DATABASE pterodactyl_panel;"
mysql -u root -e "CREATE USER 'pterodactyl'@'127.0.0.1' IDENTIFIED BY 'pterodactyl_password';"
mysql -u root -e "GRANT ALL PRIVILEGES ON pterodactyl_panel.* TO 'pterodactyl'@'127.0.0.1';"
mysql -u root -e "FLUSH PRIVILEGES;"

# Run migrations
print_status "Running database migrations..."
php artisan migrate --seed --force

# Create queue worker
print_status "Setting up queue worker..."
php artisan queue:failed-table

# Configure Supervisor
print_status "Configuring Supervisor..."
cat > /etc/supervisor/conf.d/pterodactyl.conf <<EOF
[program:pterodactyl-worker]
process_name=%(program_name)s_%(process_num)02d
command=php /var/www/pterodactyl/artisan queue:work --queue=default --sleep=3 --tries=3
autostart=true
autorestart=true
stopasgroup=true
stopwaitsecs=10
user=www-data
numprocs=4
redirect_stderr=true
stdout_logfile=/var/log/pterodactyl-worker.log
EOF

supervisorctl reread
supervisorctl update
supervisorctl start pterodactyl-worker:*

# Configure Nginx
print_status "Configuring Nginx..."
cat > /etc/nginx/sites-available/pterodactyl <<'EOF'
server {
    listen 80;
    server_name _;

    root /var/www/pterodactyl/public;
    index index.html index.htm index.php;

    charset utf-8;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ \.php$ {
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass unix:/run/php/php8.1-fpm.sock;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_param PATH_INFO $fastcgi_path_info;
        fastcgi_intercept_errors off;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF

ln -sf /etc/nginx/sites-available/pterodactyl /etc/nginx/sites-enabled/pterodactyl
rm -f /etc/nginx/sites-enabled/default

# Test and restart Nginx
print_status "Testing and starting Nginx..."
nginx -t && systemctl restart nginx

# Set up cron job for Pterodactyl tasks
print_status "Setting up cron jobs..."
cat > /etc/cron.d/pterodactyl <<EOF
* * * * * www-data cd /var/www/pterodactyl && php artisan schedule:run >> /dev/null 2>&1
EOF

# Enable and start services
print_status "Enabling and starting services..."
systemctl enable nginx mysql-server redis-server supervisor
systemctl restart nginx mysql-server redis-server supervisor

print_status "Pterodactyl Panel installation completed!"
print_status "Access your panel at: http://your-server-ip"
print_status ""
print_warning "IMPORTANT: Configure your .env file with database credentials and app URL"
print_warning "Database credentials - User: pterodactyl, Password: pterodactyl_password"
print_warning "Change these credentials in your .env file for production!"
print_warning "Run: php artisan tinker to create an admin user"

