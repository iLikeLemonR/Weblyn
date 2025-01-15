#!/bin/bash

# Ensure the script runs with sudo privileges
if [ "$(id -u)" -ne 0 ]; then
    echo "Please run as root using sudo."
    exit 1

# Prompt user for username and password for login
echo "Enter a username for the login page:"
read USERNAME
echo "Enter a password for the login page:"
read PASSWORD

# Save credentials to a .env file for later use (secure storage for simplicity)
echo "USERNAME=$USERNAME" > /var/www/html/.env
echo "PASSWORD=$(openssl passwd -1 $PASSWORD)" >> /var/www/html/.env
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
chmod 700 /var/www/html/session_tokens

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
NGINX_CONFIG="/etc/nginx/sites-available/remoteaccess"
if [ ! -f "$NGINX_CONFIG" ]; then
    echo "Setting up NGINX configuration for remote access..."

    cat > $NGINX_CONFIG <<EOF
server {
    listen 80;
    server_name localhost;

    root /var/www/html;
    index login.html;

    # Serve login.html when accessing the root URL
    location = / {
        try_files /login.html =404;
    }

    # Serve PHP files
    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php-fpm.sock;  # Adjust the path to your PHP-FPM socket file as needed
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }

    # Authorization check for dashboard.html
    location /dashboard.html {
        auth_request /auth.php;
        
        error_page 401 = @error401;

        # If authorized, serve the dashboard.html file
        try_files \$uri =404;
    }

    # Internal location for auth.php
    location = /auth.php {
        internal;
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php-fpm.sock;  # Adjust the path to your PHP-FPM socket file as needed
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }

    # Error page for unauthorized access
    location @error401 {
        return 302 /login.html;
    }

    location ~ /\.ht {
        deny all;
    }

    error_log /var/log/nginx/error.log;
    access_log /var/log/nginx/access.log;
}

EOF

# Set up the main NGINX configuration
MAIN_NGINX_CONFIG="/etc/nginx/nginx.conf"
cat > $MAIN_NGINX_CONFIG <<EOF
user www-data;
worker_processes auto;
pid /run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    server_names_hash_bucket_size 64;

    include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/sites-enabled/*;

    gzip on;
    gzip_disable "msie6";

    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_buffers 16 8k;
    gzip_http_version 1.1;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;

    upstream php-handler {
        server unix:/var/run/php/php-fpm.sock;  # Adjust this path to your PHP-FPM socket file
    }
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