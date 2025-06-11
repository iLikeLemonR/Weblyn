#!/bin/bash

# Exit on error
set -e

# Function to print colored status messages
print_status() {
    echo -e "\e[1;34m==>\e[0m \e[1m$1\e[0m"
}

# Function to print error messages
print_error() {
    echo -e "\e[1;31mError:\e[0m $1" >&2
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check package version
check_package_version() {
    local package=$1
    local min_version=$2
    local current_version

    if ! command_exists $package; then
        return 1
    fi

    case $package in
        nginx)
            current_version=$(nginx -v 2>&1 | grep -oP '\d+\.\d+\.\d+')
            ;;
        php)
            current_version=$(php -v | grep -oP '\d+\.\d+\.\d+')
            ;;
        node)
            current_version=$(node -v | grep -oP '\d+\.\d+\.\d+')
            ;;
        npm)
            current_version=$(npm -v | grep -oP '\d+\.\d+\.\d+')
            ;;
        postgres)
            current_version=$(psql --version | grep -oP '\d+\.\d+\.\d+')
            ;;
        redis-cli)
            current_version=$(redis-cli --version | grep -oP '\d+\.\d+\.\d+')
            ;;
        *)
            return 0
            ;;
    esac

    if [ "$(printf '%s\n' "$min_version" "$current_version" | sort -V | head -n1)" = "$min_version" ]; then
        return 0
    else
        return 1
    fi
}

# Ensure the script runs with sudo privileges
if [ "$(id -u)" -ne 0 ]; then
    print_error "Please run as root using sudo."
    exit 1
fi

# Get the current user
CURRENT_USER=${SUDO_USER:-$(whoami)}

# Update system
print_status "Updating system..."
apt-get update
apt-get upgrade -y

# Install required packages
print_status "Installing required packages..."
apt-get install -y nginx-full nginx-common nginx-extras \
    php-fpm php-pgsql php-redis php-curl php-mbstring php-xml \
    postgresql postgresql-contrib \
    redis-server \
    nodejs npm \
    composer \
    certbot python3-certbot-nginx

# Check and install NGINX if needed
if ! check_package_version nginx "1.18.0"; then
    print_status "Installing/Updating NGINX..."
    apt-get install --reinstall -y nginx-full nginx-common nginx-extras
else
    print_status "NGINX is already installed and up to date."
fi

# Check and install PHP-FPM if needed
if ! check_package_version php "7.4.0"; then
    print_status "Installing/Updating PHP-FPM..."
    apt-get install -y php-fpm php-pgsql php-redis php-curl php-mbstring php-xml
else
    print_status "PHP-FPM is already installed and up to date."
fi

# Check and install PostgreSQL if needed
if ! check_package_version postgres "12.0"; then
    print_status "Installing/Updating PostgreSQL..."
    apt-get install -y postgresql postgresql-contrib
else
    print_status "PostgreSQL is already installed and up to date."
fi

# Check and install Redis if needed
if ! check_package_version redis-cli "6.0.0"; then
    print_status "Installing/Updating Redis..."
    apt-get install -y redis-server
else
    print_status "Redis is already installed and up to date."
fi

# Configure PostgreSQL
print_status "Configuring PostgreSQL..."
sudo -u postgres psql -c "CREATE DATABASE weblyn;"
sudo -u postgres psql -c "CREATE USER weblyn_user WITH ENCRYPTED PASSWORD 'weblyn_password';"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE weblyn TO weblyn_user;"

# Import database schema
print_status "Importing database schema..."
sudo -u postgres psql weblyn < /var/www/html/schema.sql

# Configure Redis
print_status "Configuring Redis..."
sed -i 's/# requirepass foobared/requirepass weblyn_redis_password/' /etc/redis/redis.conf
systemctl restart redis-server

# Create necessary directories
print_status "Creating necessary directories..."
mkdir -p /var/www/html
mkdir -p /var/www/html/public
mkdir -p /var/log/weblyn
chmod 755 /var/log/weblyn

# Set up environment files
print_status "Setting up environment files..."
cat > /var/www/html/config.php << 'EOL'
<?php
// Database configuration
define('DB_HOST', 'localhost');
define('DB_NAME', 'weblyn');
define('DB_USER', 'weblyn_user');
define('DB_PASS', 'weblyn_password');

// Redis configuration
define('REDIS_HOST', 'localhost');
define('REDIS_PORT', 6379);
define('REDIS_PASS', 'weblyn_redis_password');

// Session configuration
define('SESSION_LIFETIME', 3600); // 1 hour
define('SESSION_REFRESH_TIME', 300); // 5 minutes
define('SESSION_NAME', 'weblyn_session');

// Security configuration
define('PASSWORD_MIN_LENGTH', 12);
define('PASSWORD_REQUIRE_SPECIAL', true);
define('PASSWORD_REQUIRE_NUMBERS', true);
define('PASSWORD_REQUIRE_UPPERCASE', true);
define('PASSWORD_REQUIRE_LOWERCASE', true);

// Rate limiting
define('LOGIN_ATTEMPTS_LIMIT', 5);
define('LOGIN_ATTEMPTS_WINDOW', 300); // 5 minutes

// MFA configuration
define('MFA_ENABLED', true);
define('MFA_ISSUER', 'Weblyn');
define('MFA_ALGORITHM', 'sha1');
define('MFA_DIGITS', 6);
define('MFA_PERIOD', 30);

// CSP configuration
define('CSP_ENABLED', true);
define('CSP_REPORT_URI', '/csp-report.php');

// Audit logging
define('AUDIT_LOG_ENABLED', true);
define('AUDIT_LOG_PATH', '/var/log/weblyn/audit.log');
EOL

# Install PHP dependencies
print_status "Installing PHP dependencies..."
cd /var/www/html
composer require robthree/twofactorauth

# Configure NGINX
print_status "Configuring NGINX..."
read -p "Do you have a domain name? (y/N): " HAS_DOMAIN

if [[ $HAS_DOMAIN =~ ^[Yy]$ ]]; then
    read -p "Enter your domain name: " DOMAIN_NAME
    cat > /etc/nginx/sites-available/default << EOL
server {
    listen 80;
    server_name $DOMAIN_NAME;
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $DOMAIN_NAME;

    ssl_certificate /etc/letsencrypt/live/$DOMAIN_NAME/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN_NAME/privkey.pem;
    ssl_session_timeout 1d;
    ssl_session_cache shared:SSL:50m;
    ssl_session_tickets off;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;

    # HSTS (uncomment if you're sure)
    # add_header Strict-Transport-Security "max-age=63072000" always;

    root /var/www/html;
    index login.html;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;

    location / {
        try_files \$uri \$uri/ =404;
    }

    location /dashboard.html {
        auth_request /auth.php;
        auth_request_set \$auth_resp_jwt \$upstream_http_authorization;
        add_header Authorization \$auth_resp_jwt;
    }

    location /auth.php {
        internal;
        fastcgi_pass unix:/var/run/php/php-fpm.sock;
        fastcgi_param SCRIPT_FILENAME /var/www/html/auth.php;
        include fastcgi_params;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php-fpm.sock;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOL

    # Get SSL certificate
    print_status "Setting up SSL certificate..."
    certbot --nginx -d $DOMAIN_NAME --non-interactive --agree-tos --email admin@$DOMAIN_NAME
else
    cat > /etc/nginx/sites-available/default << EOL
server {
    listen 80;
    server_name _;

    root /var/www/html;
    index login.html;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;

    location / {
        try_files \$uri \$uri/ =404;
    }

    location /dashboard.html {
        auth_request /auth.php;
        auth_request_set \$auth_resp_jwt \$upstream_http_authorization;
        add_header Authorization \$auth_resp_jwt;
    }

    location /auth.php {
        internal;
        fastcgi_pass unix:/var/run/php/php-fpm.sock;
        fastcgi_param SCRIPT_FILENAME /var/www/html/auth.php;
        include fastcgi_params;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php-fpm.sock;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOL
    DOMAIN_NAME="localhost"
fi

# Restart services
print_status "Restarting services..."
systemctl restart nginx
systemctl restart php-fpm
systemctl restart postgresql
systemctl restart redis-server

# Set proper permissions
print_status "Setting proper permissions..."
chown -R www-data:www-data /var/www/html
chmod -R 755 /var/www/html
chmod 600 /var/www/html/config.php

# Create initial admin user
print_status "Creating initial admin user..."
read -p "Enter admin username: " ADMIN_USER
read -s -p "Enter admin password: " ADMIN_PASS
echo

# Hash the password
ADMIN_PASS_HASH=$(php -r "echo password_hash('$ADMIN_PASS', PASSWORD_DEFAULT);")

# Insert admin user into database
sudo -u postgres psql weblyn << EOF
INSERT INTO users (username, password_hash, email, mfa_enabled, is_active)
VALUES ('$ADMIN_USER', '$ADMIN_PASS_HASH', 'admin@$DOMAIN_NAME', false, true);
EOF

print_status "Setup completed successfully!"
if [[ $HAS_DOMAIN =~ ^[Yy]$ ]]; then
    print_status "You can now access your dashboard at https://$DOMAIN_NAME"
else
    print_status "You can now access your dashboard at http://localhost"
fi
print_status "Please make sure to change the default passwords in config.php"
