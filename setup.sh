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

# Function to generate secure random password
generate_secure_password() {
    openssl rand -base64 32 | tr -dc 'a-zA-Z0-9!@#$%^&*()_+' | head -c 32
}

# Function to create environment files
create_env_files() {
    print_status "Creating secure environment configuration files..."
    
    # Generate secure passwords
    DB_PASSWORD=$(generate_secure_password)
    REDIS_PASSWORD=$(generate_secure_password)
    SESSION_SECRET=$(generate_secure_password)
    JWT_SECRET=$(generate_secure_password)
    
    # Create .env.example with placeholder values
    cat > /var/www/html/.env.example << 'EOL'
# Database Configuration
DB_HOST=localhost
DB_NAME=weblyn
DB_USER=your_db_user
DB_PASS=your_db_password

# Redis Configuration
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_PASS=your_redis_password

# Application Settings
APP_NAME=Weblyn
APP_ENV=production
APP_DEBUG=false
APP_URL=http://localhost
APP_KEY=your_app_key

# Security Settings
SESSION_LIFETIME=3600
SESSION_NAME=weblyn_session
SESSION_SECRET=your_session_secret
JWT_SECRET=your_jwt_secret
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

    # Create actual .env file with secure values
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
    chmod 644 /var/www/html/.env.example
    
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
    access_log off;
    log_not_found off;
}

# Rate limiting
limit_req_zone $binary_remote_addr zone=login:10m rate=5r/s;
limit_req_zone $binary_remote_addr zone=api:10m rate=60r/s;

# SSL configuration
ssl_protocols TLSv1.2 TLSv1.3;
ssl_prefer_server_ciphers on;
ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384;
ssl_session_timeout 1d;
ssl_session_cache shared:SSL:50m;
ssl_session_tickets off;
ssl_stapling on;
ssl_stapling_verify on;
resolver 8.8.8.8 8.8.4.4 valid=300s;
resolver_timeout 5s;
EOL

    # Configure Redis security
    sed -i 's/# requirepass foobared/requirepass '"${REDIS_PASSWORD}"'/' /etc/redis/redis.conf
    sed -i 's/# bind 127.0.0.1/bind 127.0.0.1/' /etc/redis/redis.conf
    sed -i 's/# protected-mode yes/protected-mode yes/' /etc/redis/redis.conf
    
    # Configure PostgreSQL security
    cat > /etc/postgresql/12/main/conf.d/security.conf << 'EOL'
listen_addresses = 'localhost'
ssl = on
ssl_cert_file = '/etc/ssl/certs/ssl-cert-snakeoil.pem'
ssl_key_file = '/etc/ssl/private/ssl-cert-snakeoil.key'
password_encryption = scram-sha-256
EOL

    # Set up fail2ban
    apt-get install -y fail2ban
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

[nginx-botsearch]
enabled = true
filter = nginx-botsearch
port = http,https
logpath = /var/log/nginx/access.log
EOL

    systemctl enable fail2ban
    systemctl start fail2ban
}

# Function to download and extract application files
download_and_setup_files() {
    print_status "Starting secure file installation process..."
    
    # Base URL for raw GitHub content
    BASE_URL="https://raw.githubusercontent.com/iLikeLemonR/Weblyn/refs/heads/EnhancedDEMV1.0"
    
    # Create base directory structure
    print_status "Creating secure directory structure..."
    mkdir -p /var/www/html
    mkdir -p /var/www/html/public
    mkdir -p /var/www/html/public/css
    mkdir -p /var/www/html/public/js
    mkdir -p /var/www/html/public/images
    mkdir -p /var/log/weblyn
    mkdir -p /etc/weblyn
    
    # Function to download a single file
    download_file() {
        local url=$1
        local dest=$2
        local dir=$(dirname "$dest")
        
        # Create directory if it doesn't exist
        mkdir -p "$dir"
        
        print_status "Downloading: $(basename "$dest")"
        if curl -s -f -o "$dest" "$url"; then
            print_status "Successfully installed: $(basename "$dest")"
            return 0
        else
            print_error "Failed to download: $(basename "$dest")"
            return 1
        fi
    }
    
    # Download and install each file independently
    
    # Webpage files
    print_status "Installing webpage files..."
    download_file "${BASE_URL}/Webpage/dashboard.html" "/var/www/html/public/dashboard.html"
    download_file "${BASE_URL}/Webpage/login.html" "/var/www/html/public/login.html"
    download_file "${BASE_URL}/Webpage/signup.html" "/var/www/html/public/signup.html"
    download_file "${BASE_URL}/Webpage/index.html" "/var/www/html/public/index.html"
    
    # PHP files
    print_status "Installing PHP files..."
    download_file "${BASE_URL}/auth.php" "/var/www/html/auth.php"
    download_file "${BASE_URL}/signup.php" "/var/www/html/signup.php"
    download_file "${BASE_URL}/login.php" "/var/www/html/login.php"
    download_file "${BASE_URL}/dashboard.php" "/var/www/html/dashboard.php"
    download_file "${BASE_URL}/csp-report.php" "/var/www/html/csp-report.php"
    download_file "${BASE_URL}/api.php" "/var/www/html/api.php"
    
    # CSS files
    print_status "Installing CSS files..."
    download_file "${BASE_URL}/Webpage/css/style.css" "/var/www/html/public/css/style.css"
    download_file "${BASE_URL}/Webpage/css/dashboard.css" "/var/www/html/public/css/dashboard.css"
    download_file "${BASE_URL}/Webpage/css/login.css" "/var/www/html/public/css/login.css"
    
    # JavaScript files
    print_status "Installing JavaScript files..."
    download_file "${BASE_URL}/Webpage/js/dashboard.js" "/var/www/html/public/js/dashboard.js"
    download_file "${BASE_URL}/Webpage/js/login.js" "/var/www/html/public/js/login.js"
    download_file "${BASE_URL}/Webpage/js/signup.js" "/var/www/html/public/js/signup.js"
    download_file "${BASE_URL}/Webpage/js/api.js" "/var/www/html/public/js/api.js"
    
    # Configuration files
    print_status "Installing configuration files..."
    download_file "${BASE_URL}/schema.sql" "/var/www/html/schema.sql"
    
    # Create environment files
    create_env_files
    
    # Configure security settings
    configure_security
    
    # Set proper permissions
    print_status "Setting secure file permissions..."
    chown -R www-data:www-data /var/www/html
    find /var/www/html -type d -exec chmod 755 {} \;
    find /var/www/html -type f -exec chmod 644 {} \;
    chmod 600 /var/www/html/.env
    chmod 755 /var/www/html/public
    chmod 755 /var/www/html/public/css
    chmod 755 /var/www/html/public/js
    chmod 755 /var/www/html/public/images
    
    # Create and secure log files
    touch /var/log/weblyn/audit.log
    touch /var/log/weblyn/error.log
    touch /var/log/weblyn/access.log
    touch /var/log/weblyn/php_errors.log
    chown -R www-data:www-data /var/log/weblyn
    chmod -R 640 /var/log/weblyn
    chmod 750 /var/log/weblyn
    
    print_status "Secure file installation completed"
}

# Function to setup systemd services
setup_services() {
    print_status "Setting up systemd services..."
    
    # Create service files
    cat > /etc/systemd/system/weblyn.service << EOL
[Unit]
Description=Weblyn Application Service
After=network.target postgresql.service redis.service

[Service]
Type=simple
User=www-data
Group=www-data
WorkingDirectory=/var/www/html
ExecStart=/usr/bin/php -S localhost:8000 -t public
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOL

    # Enable and start services
    systemctl daemon-reload
    systemctl enable weblyn
    systemctl start weblyn
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
    certbot python3-certbot-nginx \
    git \
    curl \
    unzip

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

# Download and setup application files
download_and_setup_files

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

# Install PHP dependencies
print_status "Installing PHP dependencies..."
cd /var/www/html
composer install --no-interaction
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

    root /var/www/html/public;
    index index.php;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
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

    root /var/www/html/public;
    index index.php;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
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

# Setup systemd services
setup_services

# Restart services
print_status "Restarting services..."
systemctl restart nginx
systemctl restart php-fpm
systemctl restart postgresql
systemctl restart redis-server

# Create initial admin user
print_status "Creating initial admin user..."
read -p "Enter admin username: " ADMIN_USER
read -s -p "Enter admin password: " ADMIN_PASS
echo

# Hash the password
ADMIN_PASS_HASH=$(php -r "echo password_hash('$ADMIN_PASS', PASSWORD_DEFAULT);")

# Insert admin user into database
sudo -u postgres psql weblyn << EOF
INSERT INTO users (username, password_hash, email, mfa_enabled, is_active, is_admin)
VALUES ('$ADMIN_USER', '$ADMIN_PASS_HASH', 'admin@$DOMAIN_NAME', false, true, true);
EOF

# Setup cron jobs for maintenance
print_status "Setting up maintenance cron jobs..."
(crontab -l 2>/dev/null; echo "0 0 * * * /usr/bin/php /var/www/html/artisan schedule:run >> /var/log/weblyn/cron.log 2>&1") | crontab -

print_status "Setup completed successfully!"
if [[ $HAS_DOMAIN =~ ^[Yy]$ ]]; then
    print_status "You can now access your dashboard at https://$DOMAIN_NAME"
else
    print_status "You can now access your dashboard at http://localhost"
fi
print_status "Please make sure to change the default passwords in .env file"
print_status "The application will automatically start on system boot"
