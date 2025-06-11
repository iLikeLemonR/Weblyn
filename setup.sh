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

# Create necessary directories
print_status "Creating necessary directories..."
mkdir -p /var/www/html
mkdir -p /var/www/html/public
mkdir -p /var/www/html/session_tokens

# Set up environment files
print_status "Setting up environment files..."
touch /var/www/html/.env
touch /var/www/html/.env2
echo "/var/www/html/session_tokens/" > "/var/www/html/.env2"

# Set proper permissions
chmod 700 /var/www/html/session_tokens
chmod 600 /var/www/html/.env
chmod 600 /var/www/html/.env2
chown -R www-data:www-data /var/www/html/

# Prompt for credentials
print_status "Setting up login credentials..."
echo "Enter a username for the login page:"
read USERNAME
echo "Enter a password for the login page:"
read -s PASSWORD

# Save credentials securely
echo "USERNAME=$USERNAME" > /var/www/html/.env
echo "PASSWORD=$(openssl passwd -6 $PASSWORD)" >> /var/www/html/.env
print_status "Credentials saved successfully!"

# Update system
print_status "Updating system..."
apt-get update

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
    apt-get install -y php-fpm
else
    print_status "PHP-FPM is already installed and up to date."
fi

# Check and install Node.js if needed
if ! check_package_version node "14.0.0"; then
    print_status "Installing/Updating Node.js..."
    apt-get install -y nodejs
else
    print_status "Node.js is already installed and up to date."
fi

# Check and install npm if needed
if ! check_package_version npm "6.0.0"; then
    print_status "Installing/Updating npm..."
    apt-get install -y npm
else
    print_status "npm is already installed and up to date."
fi

# Install Node.js dependencies if needed
print_status "Checking Node.js dependencies..."
if [ ! -f "/var/www/html/package.json" ] || [ ! -d "/var/www/html/node_modules" ]; then
    print_status "Installing Node.js dependencies..."
    cd /var/www/html
    npm init -y
    npm install express node-pty ws cors systeminformation express-rate-limit
else
    print_status "Node.js dependencies are already installed."
fi

# Download web files if they don't exist
print_status "Checking web files..."
WEB_FILES=(
    "login.html"
    "login.php"
    "auth.php"
    "statsPuller.js"
    "dashboard.html"
    "dashcss.css"
    "dashjs.js"
)

for file in "${WEB_FILES[@]}"; do
    if [ ! -f "/var/www/html/$file" ]; then
        print_status "Downloading $file..."
        wget -q -O "/var/www/html/$file" "https://raw.githubusercontent.com/iLikeLemonR/Weblyn/refs/heads/main/Webpage/$file"
    else
        print_status "$file already exists."
    fi
done

# Configure NGINX if needed
print_status "Checking NGINX configuration..."
if [ ! -f "/etc/nginx/sites-available/default" ]; then
    print_status "Configuring NGINX..."
    NGINX_CONFIG="/etc/nginx/sites-available/default"

    # Detect PHP-FPM socket
    PHP_FPM_SOCK=$(find /var/run/php/ -name "php*-fpm.sock" | head -n 1)

    if [ -z "$PHP_FPM_SOCK" ]; then
        print_error "PHP-FPM is not installed or running. Please install PHP-FPM and try again."
        exit 1
    fi

    # Create NGINX configuration
    cat > $NGINX_CONFIG <<EOF
server {
    listen 80;
    server_name localhost;

    root /var/www/html;
    index login.html;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN";
    add_header X-XSS-Protection "1; mode=block";
    add_header X-Content-Type-Options "nosniff";
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

    location / {
        try_files \$uri \$uri/ =404;
    }

    location /dashboard.html {
        auth_request /auth.php;
    }

    location /auth.php {
        internal;
        fastcgi_pass unix:$PHP_FPM_SOCK;
        fastcgi_param SCRIPT_FILENAME /var/www/html/auth.php;
        include fastcgi_params;
    }

    location /metrics {
        proxy_pass http://localhost:8080/metrics;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }

    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:$PHP_FPM_SOCK;
    }
}
EOF
else
    print_status "NGINX configuration already exists."
fi

# Create systemd service for statsPuller if needed
print_status "Checking statsPuller service..."
if [ ! -f "/etc/systemd/system/statsPuller.service" ]; then
    print_status "Creating systemd service for statsPuller..."
    cat > /etc/systemd/system/statsPuller.service <<EOF
[Unit]
Description=Stats Puller NodeJS Service
After=network.target

[Service]
ExecStart=node /var/www/html/statsPuller.js
WorkingDirectory=/var/www/html
User=www-data
Restart=always
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
EOF
else
    print_status "statsPuller service already exists."
fi

# Reload systemd and start services
print_status "Starting services..."
systemctl daemon-reload
systemctl enable statsPuller.service
systemctl start statsPuller.service
systemctl restart nginx

# Verify services are running
if systemctl is-active --quiet nginx && systemctl is-active --quiet statsPuller.service; then
    print_status "All services are running successfully!"
else
    print_error "One or more services failed to start. Please check the logs."
    exit 1
fi

print_status "Setup completed successfully!"
print_status "You can now access the dashboard at http://localhost"
