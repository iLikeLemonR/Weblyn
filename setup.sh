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

# Function to get latest PHP version from apt
get_latest_php_version() {
    apt-cache search php | grep -E '^php[0-9]+\.[0-9]+-fpm' | sort -V | tail -n1 | cut -d' ' -f1 | cut -d'-' -f1
}

# Function to fix nginx security.conf if location is outside server block
fix_nginx_security_conf() {
    local conf_file="/etc/nginx/conf.d/security.conf"
    if [ -f "$conf_file" ]; then
        # Check if there is a location block outside a server block
        if grep -qE '^[[:space:]]*location\\b' "$conf_file" && ! grep -qE '^[[:space:]]*server\\b' "$conf_file"; then
            print_status "Automatically fixing $conf_file: Wrapping in server block."
            cp "$conf_file" "$conf_file.bak"
            { echo "server {"; cat "$conf_file"; echo "}"; } > "${conf_file}.tmp"
            mv "${conf_file}.tmp" "$conf_file"
        fi
    fi
}

# Function to write default nginx configuration
write_default_nginx_config() {
    print_status "Writing default nginx configuration..."
    
    # Main nginx.conf
    cat > /etc/nginx/nginx.conf <<EOL
user www-data;
worker_processes auto;
pid /run/nginx.pid;

include /etc/nginx/modules-enabled/*.conf;

events {
    worker_connections 1024;
    multi_accept on;
}

http {
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 4096;

    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    server_tokens off;

    # Logging
    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types text/plain text/css text/xml application/json application/javascript application/xml+rss application/atom+xml image/svg+xml;

    # Security headers (applied globally)
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; font-src 'self' data:; connect-src 'self';" always;
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;

    # File upload limit (optional)
    client_max_body_size 10M;

    # FastCGI timeout tuning (optional for PHP apps)
    fastcgi_read_timeout 60;

    # Include additional configs
    include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/sites-enabled/*;
}
EOL


    # Default site configuration
    mkdir -p /etc/nginx/sites-available /etc/nginx/sites-enabled
    cat > /etc/nginx/sites-available/default <<EOL
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;

    root /var/www/html;
    index login.html;

    # Serve static files and HTML from /public
    location /public/ {
        alias /var/www/html/public/;
        try_files $uri $uri/ =404;
    }

    # Admin PHP endpoints
    location ~ ^/admin/(.*\.php)$ {
        alias /var/www/html/admin/$1;
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php-fpm.sock;
        fastcgi_param SCRIPT_FILENAME /var/www/html/admin/$1;
    }

    # Main PHP endpoints (api.php, auth.php, etc.)
    location ~ ^/(api|auth|config|csp-report|login|signup)\.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php-fpm.sock;
        fastcgi_param SCRIPT_FILENAME /var/www/html/$fastcgi_script_name;
    }

    # Default route: serve login.html
    location / {
        try_files /public/login.html =404;
    }

    # Security: deny access to hidden and sensitive files
    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
    }
    location ~* \.(env|log|git|svn|htaccess|htpasswd|ini|phps|fla|psd|sh|sql|json|bak|backup|old|swp|tmp)$ {
        deny all;
    }
}
EOL

    # Create symbolic link
    ln -sf /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default

    # Create log directory
    mkdir -p /var/log/nginx
    chown -R www-data:www-data /var/log/nginx

    # Test configuration
    nginx -t
}

# Function to overwrite nginx security.conf with secure settings
write_nginx_security_conf() {
    print_status "Writing secure nginx security.conf..."
    cat > /etc/nginx/conf.d/security.conf <<EOL
server {
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; font-src 'self' data:; connect-src 'self';" always;
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;

    # Disable server tokens
    server_tokens off;

    # Prevent access to hidden files
    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
    }

    # Prevent access to sensitive files
    location ~* \.(env|log|git|svn|htaccess|htpasswd|ini|phps|fla|psd|sh|sql|json)$ {
        deny all;
    }
}
EOL
}

# Function to install required packages
install_required_packages() {
    print_status "Installing required packages..."
    
    # Check if running on a Debian-based system
    if ! command_exists apt-get; then
        print_error "This script requires a Debian-based system (Ubuntu, Debian, etc.)"
        exit 1
    fi
    
    # Update package lists
    if ! apt-get update; then
        print_error "Failed to update package lists"
        exit 1
    fi
    
    # Get latest PHP version
PHP_VERSION=$(get_latest_php_version)
if [ -z "$PHP_VERSION" ]; then
    print_error "Could not determine latest PHP version"
    exit 1
fi

print_status "Detected PHP version: $PHP_VERSION"

# Prevent Nginx from auto-starting during install
print_status "Temporarily masking nginx to avoid premature start..."
systemctl mask nginx

# Install required packages
if ! apt-get install -y \
    nginx \
    "$PHP_VERSION-fpm" \
    "$PHP_VERSION-pgsql" \
    "$PHP_VERSION-redis" \
    "$PHP_VERSION-curl" \
    "$PHP_VERSION-gd" \
    "$PHP_VERSION-mbstring" \
    "$PHP_VERSION-xml" \
    "$PHP_VERSION-zip" \
    postgresql \
    postgresql-contrib \
    redis-server \
    fail2ban \
    curl \
    openssl; then
    print_error "Failed to install required packages"
    exit 1
fi

# Install Composer manually (in case package version is outdated)
print_status "Installing Composer..."
curl -sS https://getcomposer.org/installer | php
mv composer.phar /usr/local/bin/composer
chmod +x /usr/local/bin/composer

# Unmask Nginx and write config BEFORE starting it
print_status "Unmasking nginx and writing configuration..."
systemctl unmask nginx

# Call your config write function now (move this here in the script!)
write_default_nginx_config

# Test Nginx config BEFORE starting service
if ! nginx -t; then
    print_error "Nginx configuration test failed. Please check /etc/nginx/nginx.conf."
    exit 1
fi

# Start and enable all services
if command_exists systemctl; then
    for service in nginx "${PHP_VERSION}-fpm" postgresql redis-server fail2ban; do
        print_status "Enabling and starting $service..."
        systemctl enable "$service"
        systemctl restart "$service"
    done
else
    for service in nginx "${PHP_VERSION}-fpm" postgresql redis-server fail2ban; do
        print_status "Starting $service with legacy init system..."
        service "$service" restart
    done
fi

print_status "Required packages installed successfully"


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

# Function to generate secure random password
generate_secure_password() {
    openssl rand -base64 32 | tr -dc 'a-zA-Z0-9!@#$%^&*()_+' | head -c 32
}

# Function to create environment files
create_env_files() {
    print_status "Creating secure environment configuration files..."
    
    # Create necessary directories
    mkdir -p /var/www/html
    
    # Generate secure passwords
    DB_PASSWORD=$(generate_secure_password)
    REDIS_PASSWORD=$(generate_secure_password)
    SESSION_SECRET=$(generate_secure_password)
    JWT_SECRET=$(generate_secure_password)
    
    # Create .env file with secure values
    cat > /var/www/html/.env << EOL
# Database Configuration
DB_HOST=localhost
DB_NAME=weblyn
DB_USER=weblyn_user
DB_PASS=${DB_PASSWORD}

# Redis Configuration
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_PASS=${REDIS_PASSWORD}

# Application Settings
APP_NAME=Weblyn
APP_ENV=production
APP_DEBUG=false
APP_URL=https://${DOMAIN_NAME:-localhost}
APP_KEY=$(openssl rand -base64 32)

# Security Settings
SESSION_LIFETIME=3600
SESSION_NAME=weblyn_session
SESSION_SECRET=${SESSION_SECRET}
JWT_SECRET=${JWT_SECRET}
PASSWORD_MIN_LENGTH=12
PASSWORD_REQUIRE_SPECIAL=true
PASSWORD_REQUIRE_NUMBERS=true
PASSWORD_REQUIRE_UPPERCASE=true
PASSWORD_REQUIRE_LOWERCASE=true

# MFA Settings
MFA_ENABLED=true
MFA_ISSUER=Weblyn
MFA_ALGORITHM=sha1
MFA_DIGITS=6
MFA_PERIOD=30

# Rate Limiting
LOGIN_ATTEMPTS_LIMIT=5
LOGIN_ATTEMPTS_WINDOW=300
API_RATE_LIMIT=60
API_RATE_WINDOW=60

# Security Headers
CSP_ENABLED=true
CSP_REPORT_URI=/csp-report.php
HSTS_ENABLED=true
HSTS_MAX_AGE=31536000
X_FRAME_OPTIONS=SAMEORIGIN
X_CONTENT_TYPE_OPTIONS=nosniff
X_XSS_PROTECTION=1; mode=block
REFERRER_POLICY=strict-origin-when-cross-origin

# Logging
AUDIT_LOG_ENABLED=true
AUDIT_LOG_PATH=/var/log/weblyn/audit.log
ERROR_LOG_PATH=/var/log/weblyn/error.log
ACCESS_LOG_PATH=/var/log/weblyn/access.log
EOL

    # Set proper permissions
    chmod 600 /var/www/html/.env
    
    # Store passwords securely for later use
    echo "DB_PASSWORD=${DB_PASSWORD}" > /root/weblyn_credentials
    echo "REDIS_PASSWORD=${REDIS_PASSWORD}" >> /root/weblyn_credentials
    chmod 600 /root/weblyn_credentials
}

# Function to configure security settings
configure_security() {
    print_status "Configuring security settings..."
    
    # Get PHP version
    PHP_VERSION=$(get_latest_php_version)
    if [ -z "$PHP_VERSION" ]; then
        print_error "Could not determine PHP version"
        exit 1
    fi
    
    # Configure PHP security
    cat > "/etc/php/${PHP_VERSION#php}/fpm/conf.d/99-security.ini" << 'EOL'
expose_php = Off
display_errors = Off
display_startup_errors = Off
log_errors = On
error_log = /var/log/weblyn/php_errors.log
allow_url_fopen = Off
allow_url_include = Off
session.cookie_httponly = 1
session.cookie_secure = 1
session.use_strict_mode = 1
session.cookie_samesite = "Strict"
EOL

    # Configure NGINX global security headers (no location blocks)
    cat > /etc/nginx/conf.d/security.conf << 'EOL'
server {
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; font-src 'self' data:; connect-src 'self';" always;
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;

    # Disable server tokens
    server_tokens off;

    # Prevent access to hidden files
    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
    }

    # Prevent access to sensitive files
    location ~* \.(env|log|git|svn|htaccess|htpasswd|ini|phps|fla|psd|sh|sql|json)$ {
        deny all;
    }
}
EOL

    # Configure fail2ban
    cat > /etc/fail2ban/jail.local << 'EOL'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3

[nginx-http-auth]
enabled = true
filter = nginx-http-auth
port = http,https
logpath = /var/log/nginx/error.log

[php-url-fopen]
enabled = true
port = http,https
filter = php-url-fopen
logpath = /var/log/weblyn/error.log
EOL

    # Restart services
    if command_exists systemctl; then
        systemctl restart "${PHP_VERSION}-fpm"
        systemctl restart nginx
        systemctl restart fail2ban
    else
        service "${PHP_VERSION}-fpm" restart
        service nginx restart
        service fail2ban restart
    fi
}

# Function to download and setup files
download_and_setup_files() {
    print_status "Downloading and setting up application files..."
    
    # Create necessary directories
    mkdir -p /var/www/html/public
    mkdir -p /var/www/html/admin
    mkdir -p /var/log/weblyn
    
    # Set proper permissions
    chown -R www-data:www-data /var/www/html
    chmod -R 755 /var/www/html
    chmod -R 775 /var/log/weblyn
    
    # Download files
    BASE_URL="https://raw.githubusercontent.com/iLikeLemonR/Weblyn/EnhancedDEMV1.0/Webpage"
    
    # Download PHP files
    for file in auth.php config.php login.php signup.php csp-report.php api.php; do
        curl -s "${BASE_URL}/${file}" -o "/var/www/html/${file}"
    done
    
    # Download HTML files
    for file in login.html signup.html dashboard.html; do
        curl -s "${BASE_URL}/${file}" -o "/var/www/html/public/${file}"
    done
    
    # Download admin files
    mkdir -p /var/www/html/admin
    for file in handle-signup.php notifications.php mark-read.php; do
        curl -s "${BASE_URL}/admin/${file}" -o "/var/www/html/admin/${file}"
    done
    
    # Download static files
    for file in dashcss.css dashjs.js statsPuller.js api.js; do
        curl -s "${BASE_URL}/${file}" -o "/var/www/html/public/${file}"
    done
    
    # Set proper permissions
    chown -R www-data:www-data /var/www/html
    find /var/www/html -type f -exec chmod 644 {} \;
    find /var/www/html -type d -exec chmod 755 {} \;
}

# Function to prompt for domain configuration
configure_domain() {
    print_status "Configuring domain settings..."
    
    read -p "Do you want to use a domain name? (y/N): " use_domain
    if [[ $use_domain =~ ^[Yy]$ ]]; then
        read -p "Enter your domain name (e.g., example.com): " domain_name
        DOMAIN_NAME=$domain_name
    else
        DOMAIN_NAME="localhost"
    fi
    
    # Update nginx configuration
    if [ "$DOMAIN_NAME" != "localhost" ]; then
        # Configure for domain
        cat > /etc/nginx/sites-available/default <<EOL
server {
    listen 80;
    listen [::]:80;
    server_name ${DOMAIN_NAME};
    root /var/www/html;
    index index.html index.htm index.php;
    
    location / {
        try_files \$uri \$uri/ =404;
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
    else
        # Configure for localhost
        cat > /etc/nginx/sites-available/default <<EOL
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    root /var/www/html;
    index index.html index.htm index.php;
    server_name _;
    
    location / {
        try_files \$uri \$uri/ =404;
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
    fi
    
    # Test and reload nginx
    nginx -t && systemctl reload nginx
}

# Function to initialize database
initialize_database() {
    print_status "Initializing database..."
    
    # Create database and user
    sudo -u postgres psql -c "CREATE DATABASE weblyn;"
    sudo -u postgres psql -c "CREATE USER weblyn_user WITH PASSWORD '${DB_PASSWORD}';"
    sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE weblyn TO weblyn_user;"
    
    # Create tables
    sudo -u postgres psql weblyn <<EOL
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role VARCHAR(20) NOT NULL DEFAULT 'user',
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE sessions (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id),
    session_token VARCHAR(255) NOT NULL,
    refresh_token VARCHAR(255) NOT NULL,
    ip_address VARCHAR(45) NOT NULL,
    user_agent TEXT NOT NULL,
    is_valid BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP NOT NULL,
    last_activity TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE notifications (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id),
    message TEXT NOT NULL,
    is_read BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
EOL
}

# Function to create admin user
create_admin_user() {
    print_status "Creating admin user..."
    
    read -p "Enter admin username: " admin_username
    read -p "Enter admin email: " admin_email
    read -s -p "Enter admin password: " admin_password
    echo
    
    # Hash the password
    password_hash=$(php -r "echo password_hash('${admin_password}', PASSWORD_DEFAULT);")
    
    # Insert admin user
    sudo -u postgres psql weblyn <<EOL
INSERT INTO users (username, email, password_hash, role, is_active)
VALUES ('${admin_username}', '${admin_email}', '${password_hash}', 'admin', true);
EOL
}

# Function to verify services
verify_services() {
    print_status "Verifying services..."
    
    # Check nginx
    if ! systemctl is-active --quiet nginx; then
        print_error "Nginx is not running"
        systemctl start nginx
    fi
    
    # Check PHP-FPM
    PHP_VERSION=$(get_latest_php_version)
    if ! systemctl is-active --quiet "${PHP_VERSION}-fpm"; then
        print_error "PHP-FPM is not running"
        systemctl start "${PHP_VERSION}-fpm"
    fi
    
    # Check database
    if ! sudo -u postgres psql -lqt | cut -d \| -f 1 | grep -qw weblyn; then
        print_error "Database 'weblyn' does not exist"
        initialize_database
    fi
    
    # Check Redis
    if ! systemctl is-active --quiet redis-server; then
        print_error "Redis is not running"
        systemctl start redis-server
    fi
    
    # Test web access
    if curl -s http://localhost > /dev/null; then
        print_status "Web server is accessible"
    else
        print_error "Web server is not accessible"
    fi
}

# Main installation process
main() {
    print_status "Starting Weblyn installation..."
    
    # Check if running as root
    if [ "$EUID" -ne 0 ]; then
        print_error "Please run as root"
        exit 1
    fi
    
    # Install required packages
    install_required_packages
    
    # Write default nginx config and secure security.conf
    write_default_nginx_config
    write_nginx_security_conf
    
    # Create environment files
    create_env_files
    
    # Configure domain
    configure_domain
    
    # Initialize database
    initialize_database
    
    # Create admin user
    create_admin_user
    
    # Configure PHP and fail2ban security
    configure_security
    
    # Download and setup files
    download_and_setup_files
    
    # Verify services
    verify_services
    
    # Set proper permissions
    chown -R www-data:www-data /var/www/html
    find /var/www/html -type d -exec chmod 755 {} \;
    find /var/www/html -type f -exec chmod 644 {} \;
    chmod -R 775 /var/log/weblyn
    chown -R www-data:www-data /var/log/weblyn
    
    print_status "Final verification..."
    nginx -t && print_status "Nginx config OK" || print_error "Nginx config error!"
    systemctl status nginx --no-pager | grep -q running && print_status "Nginx running" || print_error "Nginx not running!"
    systemctl status postgresql --no-pager | grep -q running && print_status "PostgreSQL running" || print_error "PostgreSQL not running!"
    systemctl status redis-server --no-pager | grep -q running && print_status "Redis running" || print_error "Redis not running!"
    print_status "Installation completed successfully!"
    print_status "Access your site at: http://localhost or your configured domain."
}

# Run main function
main
