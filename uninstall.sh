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

# Function to prompt user
prompt_user() {
    local message=$1
    local default=$2
    local response

    while true; do
        read -p "$message (y/n) [$default]: " response
        response=${response:-$default}
        case "$response" in
            [Yy]* ) return 0;;
            [Nn]* ) return 1;;
            * ) echo "Please answer yes or no.";;
        esac
    done
}

# Ensure the script runs with sudo privileges
if [ "$(id -u)" -ne 0 ]; then
    print_error "Please run as root using sudo."
    exit 1
fi

# Stop and disable services
if prompt_user "Do you want to stop and disable services (NGINX and statsPuller)?" "y"; then
    print_status "Stopping and disabling services..."
    systemctl stop statsPuller.service || true
    systemctl disable statsPuller.service || true
    systemctl stop nginx || true
    systemctl disable nginx || true
fi

# Remove systemd service file
if prompt_user "Do you want to remove the statsPuller systemd service?" "y"; then
    print_status "Removing systemd service file..."
    rm -f /etc/systemd/system/statsPuller.service
    systemctl daemon-reload
fi

# Remove NGINX configuration
if prompt_user "Do you want to remove NGINX configuration?" "y"; then
    print_status "Removing NGINX configuration..."
    rm -f /etc/nginx/sites-available/default
    rm -f /etc/nginx/sites-enabled/default
fi

# Remove web files
if prompt_user "Do you want to remove all web files?" "y"; then
    print_status "Removing web files..."
    rm -rf /var/www/html/*
fi

# Remove Node.js modules
if prompt_user "Do you want to remove Node.js modules?" "y"; then
    print_status "Removing Node.js modules..."
    if [ -d "/var/www/html/node_modules" ]; then
        rm -rf /var/www/html/node_modules
    fi
    if [ -f "/var/www/html/package.json" ]; then
        rm -f /var/www/html/package.json
    fi
    if [ -f "/var/www/html/package-lock.json" ]; then
        rm -f /var/www/html/package-lock.json
    fi
fi

# Uninstall packages
if prompt_user "Do you want to uninstall NGINX, PHP-FPM, Node.js, and npm?" "y"; then
    print_status "Uninstalling packages..."
    apt-get remove --purge -y nginx-full nginx-common nginx-extras php-fpm nodejs npm
    apt-get autoremove -y
    apt-get clean
fi

# Remove configuration files
if prompt_user "Do you want to remove all NGINX configuration files?" "y"; then
    print_status "Removing configuration files..."
    rm -rf /etc/nginx
    rm -rf /var/log/nginx
    rm -rf /var/cache/nginx
    rm -rf /var/lib/nginx
fi

# Remove PHP-FPM configuration
if prompt_user "Do you want to remove PHP-FPM configuration?" "y"; then
    print_status "Removing PHP-FPM configuration..."
    rm -rf /etc/php
    rm -rf /var/log/php*
    rm -rf /var/lib/php
fi

# Remove Node.js and npm
if prompt_user "Do you want to remove Node.js and npm completely?" "y"; then
    print_status "Removing Node.js and npm..."
    rm -rf /usr/local/bin/npm
    rm -rf /usr/local/bin/node
    rm -rf /usr/local/lib/node_modules
    rm -rf ~/.npm
    rm -rf ~/.node-gyp
fi

# Remove any remaining web server files
if prompt_user "Do you want to remove all remaining web server files?" "y"; then
    print_status "Removing remaining web server files..."
    rm -rf /var/www/html
    rm -rf /var/www
fi

# Clean up any remaining session tokens
if prompt_user "Do you want to clean up session tokens?" "y"; then
    print_status "Cleaning up session tokens..."
    rm -rf /var/www/html/session_tokens
fi

# Remove environment files
if prompt_user "Do you want to remove environment files?" "y"; then
    print_status "Removing environment files..."
    rm -f /var/www/html/.env
    rm -f /var/www/html/.env2
fi

# Clean up package manager
if prompt_user "Do you want to clean up the package manager?" "y"; then
    print_status "Cleaning up package manager..."
    apt-get update
    apt-get autoremove -y
    apt-get clean
    apt-get autoclean
fi

print_status "Uninstallation completed!"
print_status "You may need to restart your system for all changes to take effect." 