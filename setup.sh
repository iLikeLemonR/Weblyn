#!/bin/bash

# Ensure the script runs with sudo privileges
if [ "$(id -u)" -ne 0 ]; then
    echo "Please run as root."
    exit 1
fi

# 5. Prompt user for username and password for login
echo "Enter a username for the login page:"
read USERNAME
echo "Enter a password for the login page:"
read -s PASSWORD

# Save credentials to a .env file for later use (secure storage for simplicity)
echo "USERNAME=$USERNAME" > /var/www/html/.env
echo "PASSWORD=$(openssl passwd -1 $PASSWORD)" >> /var/www/html/.env
echo "saved user and pass!"

# 1. Reinstall and fully set up NGINX
echo "Reinstalling NGINX and ensuring correct setup..."
sudo apt-get update
sudo apt-get install --reinstall -y nginx-full nginx-common
sudo apt-get install php-fpm

# 2. Ensure necessary NGINX directories exist
echo "Ensuring necessary NGINX directories exist..."
mkdir -p /var/www/html
mkdir -p /etc/nginx/sites-available
mkdir -p /etc/nginx/sites-enabled
mkdir -p /var/log/nginx
mkdir -p /var/www/html/session_tokens
chmod 700 /var/www/html/session_tokens

# 3. Set up NGINX to serve login.html and dashboard.html with authentication
NGINX_CONFIG="/etc/nginx/sites-available/remoteaccess"
if [ ! -f "$NGINX_CONFIG" ]; then
    echo "Setting up NGINX configuration for remote access..."

    cat > $NGINX_CONFIG <<EOF
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
    keepalive_timeout 65;
    types_hash_max_size 2048;
    server_names_hash_bucket_size 64;

    include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/sites-enabled/*;

    upstream php-handler {
        server unix:/var/run/php/php7.4-fpm.sock;  # Adjust the path to your PHP-FPM socket file as needed
    }

    server {
        listen 80;
        server_name your_domain.com;  # Replace with your domain name or IP address

        root /var/www/html;
        index index.php index.html index.htm;

        location / {
            # Redirect all requests to login.php if not logged in
            set $session_token "";
            if ($http_cookie ~* "session_token=([^;]+)(;|$)") {
                set $session_token $1;
            }
            access_by_lua_block {
                local session_token = ngx.var.cookie_session_token
                local token_file = "/var/www/html/session_tokens/" .. ngx.md5(session_token)
                local file = io.open(token_file, "r")
                if not file then
                    return ngx.redirect("/login.php", 302)
                else
                    file:close()
                end
            }

            try_files $uri $uri/ =404;
        }

        location /login.php {
            try_files $uri =404;
            include snippets/fastcgi-php.conf;
            fastcgi_pass php-handler;
            fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
            include fastcgi_params;
        }

        location ~ \.php$ {
            try_files $uri =404;
            include snippets/fastcgi-php.conf;
            fastcgi_pass php-handler;
            fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
            include fastcgi_params;
        }

        # Location for metrics, served from localhost:8080/metrics
        location /metrics {
            proxy_pass http://localhost:8080/metrics;
        }
        
        location ~ /\.ht {
            deny all;
        }

        error_log /var/log/nginx/error.log;
        access_log /var/log/nginx/access.log;
    }
}






EOF

# 4. Ensure the NGINX service exists and is running
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

# Restart and enable NGINX service
systemctl restart nginx

# Check if NGINX is running
if systemctl is-active --quiet nginx; then
    echo "NGINX is running."
else
    echo "NGINX failed to start. Please check the logs."
    exit 1
fi

# 6. Pull the login.html and dashboard.html pages to the correct directory
echo "Pulling login.html and dashboard.html..."
wget -q -O /var/www/html/login.html https://raw.githubusercontent.com/iLikeLemonR/General-Server-Setup/refs/heads/main/Webpage/login.html
wget -q -O /var/www/html/dashboard.html https://raw.githubusercontent.com/iLikeLemonR/General-Server-Setup/refs/heads/main/Webpage/dashboard.html

# 7. Pull login.php from GitHub
echo "Pulling login.php from GitHub..."
wget -q -O /var/www/html/login.php https://raw.githubusercontent.com/iLikeLemonR/General-Server-Setup/refs/heads/main/Webpage/login.php

    # Enable the site and restart NGINX
    ln -s /etc/nginx/sites-available/remoteaccess /etc/nginx/sites-enabled/
    systemctl restart nginx
else
    echo "NGINX configuration for remoteaccess already exists."
fi

# 8. Install required packages (PHP, MySQLi extension, etc.)
echo "Installing PHP, MySQLi, and related packages..."
sudo apt-get install -y php-fpm php-mysqli

# 9. Final message
echo "Setup completed successfully."
echo "NGINX is configured to serve login.html and dashboard.html with authentication."
echo "The login system is set up with hardcoded credentials (for now)."
echo "You can visit the site at http://localhost, and the dashboard will be accessible after logging in."
