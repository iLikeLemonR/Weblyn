#!/bin/bash

# Ensure the script runs with sudo privileges
if [ "$(id -u)" -ne 0 ]; then
    echo "Please run as root using sudo."
    exit 1
fi

CURRENT_USER=${SUDO_USER:-$(whoami)}

mkdir -p /var/www/html
touch /var/www/html/.env
touch /var/www/html/.env2
cat > "/var/www/html/.env2" <<EOF 
/var/www/html/session_tokens/
EOF

# Prompt user for username and password for login
echo "Enter a username for the login page:"
read USERNAME
echo "Enter a password for the login page:"
read -s PASSWORD

# Save credentials to a .env file for later use (secure storage for simplicity)
echo "USERNAME=$USERNAME" > /var/www/html/.env
echo "PASSWORD=$(openssl passwd -6 $PASSWORD)" >> /var/www/html/.env
echo "Saved user and pass!"

# Reinstall and fully set up NGINX with PHP-FPM
echo "Reinstalling NGINX and ensuring correct setup..."
apt-get update
apt-get install --reinstall -y nginx-full nginx-common nginx-extras
apt-get install -y php-fpm
apt install -y nodejs
apt install -y npm

# Ensure necessary NGINX directories exist
echo "Ensuring necessary NGINX directories exist..."
mkdir -p /etc/nginx/sites-available
mkdir -p /etc/nginx/sites-enabled
mkdir -p /var/log/nginx
mkdir -p /var/www/html/session_tokens
mkdir -p /var/log/xterm
sudo chmod 755 /var/log/xterm
sudo chmod 700 /var/www/html/session_tokens
sudo chmod 600 /var/www/html/.env
sudo chmod 600 /var/www/html/.env2
sudo chown -R www-data:www-data /var/www/html/

# Pull the login.html, login.php, auth.php, xtermServer.js, and dashboard.html pages to the correct directory
echo "Pulling login.html, login.php, auth.php, statsPuller.go, and dashboard.html..."
wget -q -O /var/www/html/login.html https://raw.githubusercontent.com/iLikeLemonR/General-Server-Setup/refs/heads/main/Webpage/login.html
wget -q -O /var/www/html/login.php https://raw.githubusercontent.com/iLikeLemonR/General-Server-Setup/refs/heads/main/Webpage/login.php
wget -q -O /var/www/html/auth.php https://raw.githubusercontent.com/iLikeLemonR/General-Server-Setup/refs/heads/main/Webpage/auth.php
wget -q -O /var/www/html/statsPuller.go https://raw.githubusercontent.com/iLikeLemonR/General-Server-Setup/refs/heads/main/Webpage/statsPuller.go
wget -q -O /var/www/html/dashboard.html https://raw.githubusercontent.com/iLikeLemonR/General-Server-Setup/refs/heads/main/Webpage/dashboard.html
wget -q -O /var/www/html/xtermServer.js https://raw.githubusercontent.com/iLikeLemonR/General-Server-Setup/refs/heads/main/Webpage/xtermServer.js

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
sed -i "s|http://localhost:8080/metrics|http://$LOCAL_IP:8080/metrics|g" /var/www/html/dashboardjs.js
sed -i "s|ws://localhost:3000|ws://$LOCAL_IP:3000|g" /var/www/html/dashboardjs.js

# Detect installed PHP-FPM version
PHP_FPM_SOCK=$(find /var/run/php/ -name "php*-fpm.sock" | head -n 1)

if [ -z "$PHP_FPM_SOCK" ]; then
    echo "PHP-FPM is not installed or running. Please install PHP-FPM and try again."
    exit 1
fi

echo "Detected PHP-FPM socket: $PHP_FPM_SOCK"

# Configure NGINX
echo "Configuring NGINX..."
NGINX_CONFIG="/etc/nginx/sites-available/default"
cat > $NGINX_CONFIG <<EOF
server {
    listen 80;
    server_name localhost;

    root /var/www/html;
    index login.html;

    location / {
        try_files \$uri \$uri/ =404;
    }

    location /dashboard.html {
        auth_request /auth.php; # Calls auth.php to check authorization
    }

    location /auth.php {
        internal;
        fastcgi_pass unix:$PHP_FPM_SOCK; # Dynamically detected PHP-FPM socket
        fastcgi_param SCRIPT_FILENAME /var/www/html/auth.php;
        include fastcgi_params;
    }

    location /metrics {
        proxy_pass http://localhost:8080/metrics;
    }

    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:$PHP_FPM_SOCK; # Dynamically detected PHP-FPM socket
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

export PATH=$PATH:/usr/local/go/bin
export GOPATH=$HOME/go
# Install Go if not installed
if ! command -v go &> /dev/null; then
    echo "Go not found. Installing Go..."

    # Download the latest Go tarball
    GO_VERSION=$(curl -s https://go.dev/dl/ | grep -oP 'go\d+\.\d+\.\d+.*\.tar\.gz' | head -n 1)
    GO_TAR_URL="https://go.dev/dl/$GO_VERSION"
    wget $GO_TAR_URL -P /home/$CURRENT_USER/Downloads

    # Extract the tarball and install
    tar -C /usr/local -xzf /home/$CURRENT_USER/Downloads/$GO_VERSION

    # Clean up the tarball
    rm -f /home/$CURRENT_USER/Downloads/$GO_VERSION

    echo "Go has been installed."
else
    echo "Go is already installed."
fi

# Set up Go environment variables
if ! grep -q "export PATH=\$PATH:/usr/local/go/bin" ~/.bashrc; then
    echo "export PATH=\$PATH:/usr/local/go/bin" >> ~/.bashrc
    echo "export GOPATH=\$HOME/go" >> ~/.bashrc
    source ~/.bashrc
    echo "Go environment variables have been set."
else
    echo "Go environment variables already set."
fi

# Initialize Go module in /var/www/html
echo "Initializing Go module and xterm@xterm using npm in /var/www/html..."
cd /var/www/html
npm init -y 
npm install express xterm node-pty ws
go mod init statsPuller.com/statsPuller

# Install Go libraries
echo "Installing Go libraries..."

# Ensure Go workspace exists
mkdir -p "$HOME/go"

# Install necessary libraries using go get
go get github.com/shirou/gopsutil/cpu
go get github.com/shirou/gopsutil/mem
go get github.com/shirou/gopsutil/disk

echo "Go libraries have been installed."

# Create the systemd service for statsPuller
echo "Creating systemd service for statsPuller.go..."

cat > /etc/systemd/system/statsPuller.service <<EOF
[Unit]
Description=Stats Puller Go Service
After=network.target

[Service]
ExecStart=/usr/local/go/bin/go run /var/www/html/statsPuller.go
WorkingDirectory=/var/www/html
User=www-data
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Create the systemd service for xtermServer
echo "Creating systemd service for xtermServer.js..."
cat > /etc/systemd/system/xterm-server.service <<EOF
[Unit]
Description=Xterm Server
After=network.target

[Service]
ExecStart=/usr/bin/node /var/www/html/xtermServer.js
Restart=always
User=babyy
Group=babyy
WorkingDirectory=/var/www/html
Environment=NODE_ENV=production
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=xterm-server

[Install]
WantedBy=multi-user.target

EOF

# Reload systemd to apply the new service
systemctl daemon-reload

# Enable and start the statsPuller service
echo "Enabling and starting the statsPuller service and the xtermServer service..."
systemctl enable statsPuller.service
systemctl start statsPuller.service

sudo systemctl enable xterm-server.service
sudo systemctl start xterm-server.service

echo "statsPuller service has been set up and is running."
echo "xtermServer service has been set up and is running."

# Restart NGINX service to make sure everything works
systemctl restart nginx

# Check if NGINX is running
if systemctl is-active --quiet nginx; then
    echo "NGINX is running."
else
    echo "NGINX failed to start. Please check the logs."
    exit 1
fi
