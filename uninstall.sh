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

    read -p "$message (y/N): " response
    response=${response:-$default}
    [[ $response =~ ^[Yy]$ ]]
}

# Ensure the script runs with sudo privileges
if [ "$(id -u)" -ne 0 ]; then
    print_error "Please run as root using sudo."
    exit 1
fi

# Stop services
print_status "Stopping services..."
systemctl stop nginx php-fpm postgresql redis-server

# Remove web files
if prompt_user "Do you want to remove all web files?" "y"; then
    print_status "Removing web files..."
    rm -rf /var/www/html
fi

# Remove database
if prompt_user "Do you want to remove the PostgreSQL database and user?" "y"; then
    print_status "Removing database..."
    sudo -u postgres psql -c "DROP DATABASE IF EXISTS weblyn;"
    sudo -u postgres psql -c "DROP USER IF EXISTS weblyn_user;"
fi

# Remove Redis data
if prompt_user "Do you want to remove Redis data?" "y"; then
    print_status "Removing Redis data..."
    redis-cli FLUSHALL
fi

# Remove logs
if prompt_user "Do you want to remove log files?" "y"; then
    print_status "Removing log files..."
    rm -rf /var/log/weblyn
fi

# Remove SSL certificates
if prompt_user "Do you want to remove SSL certificates?" "y"; then
    print_status "Removing SSL certificates..."
    certbot delete --cert-name $(grep -oP 'server_name \K[^;]+' /etc/nginx/sites-available/default)
fi

# Remove packages
if prompt_user "Do you want to uninstall NGINX, PHP-FPM, PostgreSQL, Redis, and other packages?" "y"; then
    print_status "Uninstalling packages..."
    apt-get remove --purge -y nginx-full nginx-common nginx-extras \
        php-fpm php-pgsql php-redis php-curl php-mbstring php-xml \
        postgresql postgresql-contrib \
        redis-server \
        certbot python3-certbot-nginx \
        composer
    apt-get autoremove -y
    apt-get clean
fi

# Remove configuration files
if prompt_user "Do you want to remove all configuration files?" "y"; then
    print_status "Removing configuration files..."
    rm -rf /etc/nginx
    rm -rf /etc/php
    rm -rf /etc/postgresql
    rm -rf /etc/redis
    rm -rf /etc/letsencrypt
fi

# Remove Composer files
if prompt_user "Do you want to remove Composer files?" "y"; then
    print_status "Removing Composer files..."
    rm -rf ~/.composer
    rm -rf ~/.config/composer
fi

# Remove PostgreSQL data
if prompt_user "Do you want to remove PostgreSQL data directory?" "y"; then
    print_status "Removing PostgreSQL data..."
    rm -rf /var/lib/postgresql
fi

# Remove Redis data
if prompt_user "Do you want to remove Redis data directory?" "y"; then
    print_status "Removing Redis data..."
    rm -rf /var/lib/redis
fi

# Remove PHP session data
if prompt_user "Do you want to remove PHP session data?" "y"; then
    print_status "Removing PHP session data..."
    rm -rf /var/lib/php/sessions
fi

print_status "Uninstallation completed successfully!" 