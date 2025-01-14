#!/bin/bash

# Ensure the script runs with sudo privileges
if [ "$(id -u)" -ne 0 ]; then
    echo "Please run as root."
    exit 1
fi

# 1. Reinstall and fully set up NGINX
echo "Reinstalling NGINX and ensuring correct setup..."
sudo apt-get update
sudo apt-get install --reinstall -y nginx-full nginx-common

# 2. Ensure necessary NGINX directories exist
echo "Ensuring necessary NGINX directories exist..."
mkdir -p /var/www/html
mkdir -p /etc/nginx/sites-available
mkdir -p /etc/nginx/sites-enabled
mkdir -p /var/log/nginx
mkdir -p /var/www/html/session_tokens
chmod 700 /var/www/html/session_tokens

# 7. Set up NGINX to serve login.html and dashboard.html with authentication
NGINX_CONFIG="/etc/nginx/sites-available/remoteaccess"
if [ ! -f "$NGINX_CONFIG" ]; then
    echo "Setting up NGINX configuration for remote access..."

    cat > $NGINX_CONFIG <<EOF
server {
    listen 80;
    server_name localhost;

    # Location for login page
    location /login.html {
        root /var/www/html;
        try_files $uri $uri/ =404;
    }

    # Location for the login script (login.php)
    location /login.php {
        root /var/www/html;
        fastcgi_pass unix:/var/run/php/php7.4-fpm.sock;  # Adjust PHP-FPM version if needed
        fastcgi_index login.php;
        fastcgi_param SCRIPT_FILENAME /var/www/html$fastcgi_script_name;
        include fastcgi_params;
    }

    # Protect dashboard.html (only accessible after login via secure session token)
    location /dashboard.html {
        root /var/www/html;
        try_files $uri $uri/ =404;

        # Check if session_token cookie exists and is valid
        set $allowed 0;
        if ($cookie_session_token) {
            # Verify the session token by checking the hidden file
            set $token_file /var/www/html/session_tokens/$cookie_session_token;
            if (-f $token_file) {
                set $allowed 1;
            }
        }

        if ($allowed = 0) {
            return 403;  # Forbidden if the token is not valid
        }
    }

    # Default location (root should serve login.html as the entry point)
    location / {
        root /var/www/html;
        index login.html;
    }
}
EOF

# 3. Ensure the NGINX service exists and is running
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

# 4. Prompt user for username and password for login
echo "Enter a username for the login page:"
read USERNAME
echo "Enter a password for the login page:"
read -s PASSWORD

# Save credentials to a .env file for later use (secure storage for simplicity)
echo "USERNAME=$USERNAME" > /var/www/html/.env
echo "PASSWORD=$(openssl passwd -crypt $PASSWORD)" >> /var/www/html/.env

# 5. Pull the login.html and dashboard.html pages to the correct directory
echo "Pulling login.html and dashboard.html..."
wget -q -O /var/www/html/login.html https://raw.githubusercontent.com/iLikeLemonR/General-Server-Setup/refs/heads/main/Webpage/login.html
wget -q -O /var/www/html/dashboard.html https://raw.githubusercontent.com/iLikeLemonR/General-Server-Setup/refs/heads/main/Webpage/dashboard.html

# 6. Pull login.php from GitHub
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
