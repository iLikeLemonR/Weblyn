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
    
    # Install required packages
    if ! apt-get install -y \
        nginx \
        php7.4-fpm \
        php7.4-mysql \
        php7.4-redis \
        php7.4-curl \
        php7.4-gd \
        php7.4-mbstring \
        php7.4-xml \
        php7.4-zip \
        fail2ban \
        curl \
        openssl; then
        print_error "Failed to install required packages"
        exit 1
    fi
    
    # Check if system is using systemd
    if command_exists systemctl; then
        # Enable and start services using systemd
        for service in nginx php7.4-fpm fail2ban; do
            if ! systemctl enable "$service"; then
                print_error "Failed to enable $service"
                exit 1
            fi
            if ! systemctl start "$service"; then
                print_error "Failed to start $service"
                exit 1
            fi
        done
    else
        # Use service command for non-systemd systems
        for service in nginx php7.4-fpm fail2ban; do
            if ! service "$service" start; then
                print_error "Failed to start $service"
                exit 1
            fi
        done
    fi
    
    print_status "Required packages installed successfully"
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
    
    # Configure PHP security
    cat > /etc/php/7.4/fpm/conf.d/99-security.ini << 'EOL'
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

    # Configure NGINX security
    cat > /etc/nginx/conf.d/security.conf << 'EOL'
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
    systemctl restart php7.4-fpm
    systemctl restart nginx
    systemctl restart fail2ban
}

# Function to download and setup files
download_and_setup_files() {
    print_status "Downloading and setting up application files..."
    
    # Create necessary directories
    mkdir -p /var/www/html/public
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
    
    # Create environment files
    create_env_files
    
    # Configure security
    configure_security
    
    # Download and setup files
    download_and_setup_files
    
    print_status "Installation completed successfully!"
    print_status "Please check /root/weblyn_credentials for database and Redis passwords"
}

# Run main function
main
