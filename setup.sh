#!/bin/bash

# Ensure the script runs with sudo privileges
if [ "$(id -u)" -ne 0 ]; then
    echo "Please run as root using sudo."
    exit 1
fi

# Prompt user for username and password for login
echo "Enter a username for the login page:"
read USERNAME
echo "Enter a password for the login page:"
read PASSWORD

# Save credentials to a .env file for later use (secure storage for simplicity)
echo "USERNAME=$USERNAME" > /var/www/html/.env
echo "PASSWORD=$(openssl passwd -6 $PASSWORD)" >> /var/www/html/.env
echo "Saved user and pass!"

# Reinstall and fully set up NGINX with PHP-FPM
echo "Reinstalling NGINX and ensuring correct setup..."
apt-get update
apt-get install --reinstall -y nginx-full nginx-common nginx-extras
apt-get install -y php-fpm

# Ensure necessary NGINX directories exist
echo "Ensuring necessary NGINX directories exist..."
mkdir -p /var/www/html
mkdir -p /etc/nginx/sites-available
mkdir -p /etc/nginx/sites-enabled
mkdir -p /var/log/nginx
mkdir -p /var/www/html/session_tokens
sudo chmod 700 /var/www/html/session_tokens
sudo chmod 600 /var/www/html/.env
sudo chown -R www-data:www-data /var/www/html/

# Pull the login.html, login.php, auth.php, and dashboard.html pages to the correct directory
echo "Pulling login.html, login.php, auth.php, and dashboard.html..."
wget -q -O /var/www/html/login.html https://raw.githubusercontent.com/iLikeLemonR/General-Server-Setup/refs/heads/main/Webpage/login.html
wget -q -O /var/www/html/login.php https://raw.githubusercontent.com/iLikeLemonR/General-Server-Setup/refs/heads/main/Webpage/login.php
wget -q -O /var/www/html/auth.php https://raw.githubusercontent.com/iLikeLemonR/General-Server-Setup/refs/heads/main/Webpage/auth.php
wget -q -O /var/www/html/dashboard.html https://raw.githubusercontent.com/iLikeLemonR/General-Server-Setup/refs/heads/main/Webpage/dashboard.html

# Ensure the NGINX service exists and is running
echo "Ensuring NGINX service is set up and running..."
if ! systemctl is-enabled --quiet nginx; then
    echo "NGINX service does not exist. Creating and enabling the service..."
    systemctl enable nginx
fi

# Get local IP address function
get_local_ip() {
  ip addr show | grep -E 'inet.*brd' | awk '{print $2}' | cut -d/ -f1 | head -n 1
}

# Get the local IP
LOCAL_IP=$(get_local_ip)

# Update the index.html file dynamically with the local IP
sed -i "s|http://localhost:8080/metrics|http://$LOCAL_IP:8080/metrics|g" /var/www/html/dashboard.html

# Set up NGINX to serve login.html, login.php, and dashboard.html with authentication
NGINX_CONFIG="/etc/nginx/sites-available/default"
if [ ! -f "$NGINX_CONFIG" ]; then
    echo "Setting up NGINX configuration for remote access..."

    cat > $NGINX_CONFIG <<EOF
server {
    listen 80;
    server_name yourdomain.com;

    root /var/www/html;
    index login.html;

    location / {
        try_files $uri $uri/ =404;
    }

    location /dashboard.html {
        auth_request /auth.php; # Calls auth.php to check authorization
    }

    location /auth.php {
        internal;
        fastcgi_pass unix:/var/run/php/php7.4-fpm.sock; # Adjust PHP version if needed
        fastcgi_param SCRIPT_FILENAME /var/www/html/auth.php;
        include fastcgi_params;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php7.4-fpm.sock; # Adjust PHP version if needed
    }
}


EOF

# Set up the main NGINX configuration
MAIN_NGINX_CONFIG="/etc/nginx/nginx.conf"
cat > $MAIN_NGINX_CONFIG <<EOF
user www-data;
worker_processes auto;
pid /run/nginx.pid;

events {
    worker_connections 768;
    # multi_accept on;
}

http {
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;

    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;

    gzip on;
    gzip_disable "msie6";

    include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/sites-enabled/*;
}


EOF

# Restart and enable NGINX service
systemctl restart nginx

# Check if NGINX is running
if systemctl is-active --quiet nginx; then
    echo "NGINX is running."
else
    echo "NGINX failed to start. Please check the logs."
    exit 1
fi
fi