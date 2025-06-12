#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Exit on error
set -e

# Function to print colored status messages
print_status() {
    echo -e "${BLUE}==>${NC} ${GREEN}$1${NC}"
}

# Function to print error messages
print_error() {
    echo -e "${RED}Error:${NC} $1" >&2
}

# Function to print warning messages
print_warning() {
    echo -e "${YELLOW}Warning:${NC} $1"
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

# Function to install Node.js and npm
install_nodejs() {
    print_status "Installing Node.js and npm..."
    
    # Check if Node.js is already installed
    if command_exists node; then
        current_version=$(node -v | grep -oP '\d+\.\d+\.\d+')
        if check_package_version node "16.0.0"; then
            print_status "Node.js $current_version is already installed and compatible"
            return 0
        else
            print_warning "Node.js $current_version is installed but needs update"
        fi
    fi

    # Add NodeSource repository
    curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
    
    # Install Node.js and npm
    if ! apt-get install -y nodejs; then
        print_error "Failed to install Node.js"
        return 1
    fi

    # Verify installation
    if ! command_exists node || ! command_exists npm; then
        print_error "Node.js or npm installation failed"
        return 1
    fi

    print_status "Node.js and npm installed successfully"
    return 0
}

# Function to install PHP
install_php() {
    print_status "Installing PHP..."
    
    # Check if PHP is already installed
    if command_exists php; then
        PHP_VERSION=$(php -r 'echo PHP_VERSION;')
        print_status "PHP $PHP_VERSION is already installed"
        
        # Check if version is at least 7.4
        if [[ $(php -r 'echo version_compare(PHP_VERSION, "7.4", ">=") ? "yes" : "no";') == "no" ]]; then
            print_warning "PHP version $PHP_VERSION is lower than required (7.4+). Upgrading..."
        else
            print_status "PHP version $PHP_VERSION meets requirements"
            return 0
        fi
    fi
    
    # Add repository for PHP 8.1
    add-apt-repository -y ppa:ondrej/php
    apt-get update
    
    # Install PHP 8.1 and required extensions
    apt-get install -y php8.1 php8.1-fpm php8.1-cli php8.1-common php8.1-pgsql php8.1-redis \
        php8.1-curl php8.1-mbstring php8.1-xml php8.1-zip php8.1-gd
    
    # Note: php8.1-json is now included in the core PHP package since PHP 8.0
    
    # Configure PHP
    configure_php
    
    # Restart PHP-FPM
    systemctl restart php8.1-fpm
    
    print_status "PHP 8.1 installed successfully"
    return 0
}

# Function to install PostgreSQL
install_postgresql() {
    print_status "Installing PostgreSQL..."
    
    # Check if PostgreSQL is already installed
    if command_exists psql; then
        current_version=$(psql --version | grep -oP '\d+\.\d+\.\d+')
        if check_package_version postgres "12.0.0"; then
            print_status "PostgreSQL $current_version is already installed and compatible"
            return 0
        else
            print_warning "PostgreSQL $current_version is installed but needs update"
        fi
    fi

    # Install PostgreSQL
    if ! apt-get install -y postgresql postgresql-contrib; then
        print_error "Failed to install PostgreSQL"
        return 1
    fi

    print_status "PostgreSQL installed successfully"
    return 0
}

# Function to install Redis
install_redis() {
    print_status "Installing Redis..."
    
    # Check if Redis is already installed
    if command_exists redis-cli; then
        current_version=$(redis-cli --version | grep -oP '\d+\.\d+\.\d+')
        if check_package_version redis-cli "6.0.0"; then
            print_status "Redis $current_version is already installed and compatible"
            return 0
        else
            print_warning "Redis $current_version is installed but needs update"
        fi
    fi

    # Install Redis
    if ! apt-get install -y redis-server; then
        print_error "Failed to install Redis"
        return 1
    fi

    print_status "Redis installed successfully"
    return 0
}

# Function to install Nginx
install_nginx() {
    print_status "Installing Nginx..."
    
    # Check if Nginx is already installed
    if command_exists nginx; then
        current_version=$(nginx -v 2>&1 | grep -oP '\d+\.\d+\.\d+')
        if check_package_version nginx "1.18.0"; then
            print_status "Nginx $current_version is already installed and compatible"
            return 0
        else
            print_warning "Nginx $current_version is installed but needs update"
        fi
    fi

    # Install Nginx
    if ! apt-get install -y nginx; then
        print_error "Failed to install Nginx"
        return 1
    fi

    print_status "Nginx installed successfully"
    return 0
}

# Function to install Fail2Ban
install_fail2ban() {
    print_status "Installing Fail2Ban..."

    if ! command_exists fail2ban-client; then
        apt-get install -y fail2ban || {
            print_error "Failed to install Fail2Ban"
            return 1
        }
        print_status "Fail2Ban installed successfully"
    else
        print_status "Fail2Ban is already installed"
    fi

    return 0
}

# Function to configure Nginx
configure_nginx() {
    print_status "Configuring Nginx..."
    
    # Create Nginx configuration
    cat > /etc/nginx/sites-available/weblyn << 'EOL'
server {
    listen 80;
    server_name _;
    root /var/www/html;
    index login.html;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; font-src 'self' data:; connect-src 'self';" always;
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;

    # Main PHP endpoints (api.php, auth.php, etc.)
    location ~ ^/(api|auth|config|csp-report|login|signup)\.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.1-fpm.sock;
        fastcgi_param SCRIPT_FILENAME $document_root/$fastcgi_script_name;
    }

    # Admin PHP endpoints
    location ~ ^/admin/(.*\.php)$ {
        alias /var/www/html/admin/$1;
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.1-fpm.sock;
        fastcgi_param SCRIPT_FILENAME /var/www/html/admin/$1;
    }

    # Default route: serve login.html
    location / {
        try_files $uri $uri/ /login.html;
    }

    # Serve static files
    location ~* \.(css|js|jpg|jpeg|png|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 30d;
        add_header Cache-Control "public, no-transform";
    }

    # Deny access to sensitive files
    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
    }

    location ~* \.(env|log|git|svn|htaccess|htpasswd|ini|phps|fla|psd|sh|sql|json|bak|backup|old|swp|tmp)$ {
        deny all;
    }

    # Error pages
    error_page 404 /404.html;
    error_page 500 502 503 504 /50x.html;
}
EOL

    # Enable the site
    ln -sf /etc/nginx/sites-available/weblyn /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default

    # Create error pages
    mkdir -p /var/www/html/public
    cat > /var/www/html/public/404.html << 'EOL'
<!DOCTYPE html>
<html>
<head>
    <title>404 Not Found</title>
    <style>
        body { font-family: Arial, sans-serif; text-align: center; padding: 50px; }
        h1 { color: #333; }
    </style>
</head>
<body>
    <h1>404 - Page Not Found</h1>
    <p>The page you are looking for does not exist.</p>
    <a href="/">Return to Home</a>
</body>
</html>
EOL

    cat > /var/www/html/public/50x.html << 'EOL'
<!DOCTYPE html>
<html>
<head>
    <title>Server Error</title>
    <style>
        body { font-family: Arial, sans-serif; text-align: center; padding: 50px; }
        h1 { color: #333; }
    </style>
</head>
<body>
    <h1>500 - Server Error</h1>
    <p>Something went wrong on our end. Please try again later.</p>
    <a href="/">Return to Home</a>
</body>
</html>
EOL

    # Test configuration
    if ! nginx -t; then
        print_error "Nginx configuration test failed"
        return 1
    fi

    print_status "Nginx configured successfully"
    return 0
}

# Function to configure PHP
configure_php() {
    print_status "Configuring PHP..."
    
    # Create PHP configuration
    cat > /etc/php/8.1/fpm/conf.d/99-weblyn.ini << 'EOL'
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

    print_status "PHP configured successfully"
    return 0
}

# Function to configure PostgreSQL
configure_postgresql() {
    print_status "Configuring PostgreSQL..."

    DB_PASSWORD=$(generate_secure_password)

    # Check if user exists
    if ! su - postgres -c "psql -tAc \"SELECT 1 FROM pg_roles WHERE rolname='weblyn'\"" | grep -q 1; then
        su - postgres -c "psql -c \"CREATE USER weblyn WITH PASSWORD '$DB_PASSWORD';\""
    else
        print_warning "Role 'weblyn' already exists"
        su - postgres -c "psql -c \"ALTER USER weblyn WITH PASSWORD '$DB_PASSWORD';\""
    fi

    # Check if database exists
    if ! su - postgres -c "psql -tAc \"SELECT 1 FROM pg_database WHERE datname='weblyn'\"" | grep -q 1; then
        su - postgres -c "psql -c \"CREATE DATABASE weblyn OWNER weblyn;\""
    else
        print_warning "Database 'weblyn' already exists"
    fi

    # Store password securely
    echo "DB_PASSWORD=$DB_PASSWORD" > /root/weblyn_db_credentials
    chmod 600 /root/weblyn_db_credentials

    print_status "PostgreSQL configured successfully"
    return 0
}


# Function to configure Redis
configure_redis() {
    print_status "Configuring Redis..."
    
    # Generate secure password
    REDIS_PASSWORD=$(generate_secure_password)
    
    # Configure Redis
    sed -i "s/# requirepass foobared/requirepass $REDIS_PASSWORD/" /etc/redis/redis.conf
    
    # Store password securely
    echo "REDIS_PASSWORD=$REDIS_PASSWORD" > /root/weblyn_redis_credentials
    chmod 600 /root/weblyn_redis_credentials
    
    print_status "Redis configured successfully"
    return 0
}

# Function to configure fail2ban
configure_fail2ban() {
    print_status "Configuring fail2ban..."
    
    # Create fail2ban configuration
    mkdir -p /etc/fail2ban
    touch /etc/fail2ban/jail.local
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

    print_status "fail2ban configured successfully"
    return 0
}

# Function to create necessary directories and set permissions
setup_directories() {
    print_status "Setting up directories and permissions..."
    
    # Create directories
    mkdir -p /var/www/html/public
    mkdir -p /var/www/html/admin
    mkdir -p /var/log/weblyn
    
    # Set permissions
    chown -R www-data:www-data /var/www/html
    chmod -R 755 /var/www/html
    chmod -R 775 /var/log/weblyn
    
    print_status "Directories and permissions set up successfully"
    return 0
}

setup_project_files() {
    print_status "Setting up project files..."
    
    # Create necessary directories
    mkdir -p /var/www/html/public
    mkdir -p /var/www/html/admin
    mkdir -p /var/log/weblyn

    # Download files
    BASE_URL="https://raw.githubusercontent.com/iLikeLemonR/Weblyn/EnhancedDEMV1.0/Webpage"
    
    # Download PHP files
    for file in auth.php config.php login.php signup.php csp-report.php api.php schema.sql; do
        print_status "Downloading $file..."
        if ! curl -s "${BASE_URL}/${file}" -o "/var/www/html/${file}"; then
            print_error "Failed to download $file"
            return 1
        fi
    done
    
    # Download HTML files
    for file in dashboard.html; do
        print_status "Downloading dashboard.html"
        if ! curl -s "${BASE_URL}/dashboard.html" -o "/var/www/html/public/dashboard.html"; then
            print_error "Failed to download dashboard.html"
            return 1
        fi
        if ! curl -s "${BASE_URL}/login.html" -o "/var/www/html/login.html"; then
            print_error "Failed to download login.html"
            return 1
        fi
        if ! curl -s "${BASE_URL}/signup.html" -o "/var/www/html/signup.html"; then
            print_error "Failed to download signup.html"
            return 1
        fi
    done
    
    # Download admin files
    mkdir -p /var/www/html/admin
    for file in handle-signup.php notifications.php mark-read.php; do
        print_status "Downloading admin/$file..."
        if ! curl -s "${BASE_URL}/admin/${file}" -o "/var/www/html/admin/${file}"; then
            print_error "Failed to download admin/$file"
            return 1
        fi
    done
    
    # Download static files
    for file in dashcss.css dashjs.js statsPuller.js api.js; do
        print_status "Downloading $file..."
        if ! curl -s "${BASE_URL}/${file}" -o "/var/www/html/public/${file}"; then
            print_error "Failed to download $file"
            return 1
        fi
    done
    
    # Set proper permissions
    chown -R www-data:www-data /var/www/html
    find /var/www/html -type f -exec chmod 644 {} \;
    find /var/www/html -type d -exec chmod 755 {} \;

}

# Function to create environment files
create_env_files() {
    print_status "Creating environment files..."
    
    # Load stored credentials
    source /root/weblyn_db_credentials
    source /root/weblyn_redis_credentials
    
    # Create .env file
    cat > /var/www/html/.env << EOL
# Database Configuration
DB_HOST=localhost
DB_NAME=weblyn
DB_USER=weblyn
DB_PASS=${DB_PASSWORD}

# Redis Configuration
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_PASS=${REDIS_PASSWORD}

# Application Settings
APP_NAME=Weblyn
APP_ENV=production
APP_DEBUG=false
APP_URL=http://localhost
APP_KEY=$(openssl rand -base64 32)

# Security Settings
SESSION_LIFETIME=3600
SESSION_NAME=weblyn_session
SESSION_SECRET=$(openssl rand -base64 32)
JWT_SECRET=$(openssl rand -base64 32)
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
    chown www-data:www-data /var/www/html/.env
    
    print_status "Environment files created successfully"
    return 0
}

# Function to initialize database
initialize_database() {
    print_status "Initializing database..."
    
    # Load stored credentials
    source /root/weblyn_db_credentials
    
    # Import schema
    if ! PGPASSWORD=$DB_PASSWORD psql -h localhost -U weblyn -d weblyn -f /var/www/html/schema.sql; then
        print_error "Failed to import database schema"
        return 1
    fi
    
    print_status "Database initialized successfully"
    return 0
}

# Function to create admin user
create_admin_user() {
    print_status "Creating admin user..."
    
    # Prompt for admin credentials
    read -p "Enter admin username: " ADMIN_USERNAME
    read -s -p "Enter admin password: " ADMIN_PASSWORD
    echo
    read -p "Enter admin email: " ADMIN_EMAIL
    
    # Load stored credentials
    source /root/weblyn_db_credentials
    
    # Create admin user
    ADMIN_PASSWORD_HASH=$(php -r "echo password_hash('$ADMIN_PASSWORD', PASSWORD_DEFAULT);")
    
    if ! PGPASSWORD=$DB_PASSWORD psql -h localhost -U weblyn -d weblyn -c "INSERT INTO users (username, password_hash, email, is_admin) VALUES ('$ADMIN_USERNAME', '$ADMIN_PASSWORD_HASH', '$ADMIN_EMAIL', true);"; then
        print_error "Failed to create admin user"
        return 1
    fi
    
    print_status "Admin user created successfully"
    return 0
}

# Function to start and enable services
start_services() {
    print_status "Starting and enabling services..."
    
    # Start and enable services
    systemctl enable nginx
    systemctl enable php8.1-fpm
    systemctl enable postgresql
    systemctl enable redis-server
    systemctl enable fail2ban
    
    systemctl restart nginx
    systemctl restart php8.1-fpm
    systemctl restart postgresql
    systemctl restart redis-server
    systemctl restart fail2ban
    
    print_status "Services started and enabled successfully"
    return 0
}

# Main function
main() {
    print_status "Starting Weblyn installation..."
    
    # Check if running as root
    if [ "$EUID" -ne 0 ]; then
        print_error "Please run as root"
        exit 1
    fi
    
    # Update package lists
    apt-get update
    
    # Install required packages
    install_nodejs
    install_php
    install_postgresql
    install_redis
    install_nginx
    install_fail2ban
    
    # Configure services
    configure_nginx
    configure_php
    configure_postgresql
    configure_redis
    configure_fail2ban
    
    # Setup directories and permissions
    setup_directories
    
    # Setup project files
    setup_project_files
    
    # Create environment files
    create_env_files
    
    # Initialize database
    initialize_database
    
    # Create admin user
    create_admin_user
    
    # Start and enable services
    start_services
    
    print_status "Installation completed successfully!"
    print_status "Access your site at: http://localhost"
}

# Run main function
main