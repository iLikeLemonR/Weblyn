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

# Ensure necessary NGINX directories exist
echo "Ensuring necessary NGINX directories exist..."
mkdir -p /var/www/html
mkdir -p /etc/nginx/sites-available
mkdir -p /etc/nginx/sites-enabled
mkdir -p /var/log/nginx

# 2. Pull the index.html to the correct directory
echo "Pulling index.html from GitHub..."
wget -q -O /var/www/html/index.html https://raw.githubusercontent.com/iLikeLemonR/Basic-Server-Setup/refs/heads/main/index.html

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
sed -i "s|http://localhost:8080/metrics|http://$LOCAL_IP:8080/metrics|g" /var/www/html/index.html


# Restart and enable NGINX service
systemctl restart nginx

# Check if NGINX is running
if systemctl is-active --quiet nginx; then
    echo "NGINX is running."
else
    echo "NGINX failed to start. Please check the logs."
    exit 1
fi

# 4. Check if Go is installed
echo "Checking if Go is installed..."
if ! command -v go &> /dev/null; then
    echo "Go is not installed. Installing Go..."
    
    # Fetch the latest Go version dynamically
    LATEST_GO_VERSION=$(curl -s https://go.dev/VERSION?m=text | cut -d 't' -f1)
    if [ -z "$LATEST_GO_VERSION" ]; then
        echo "Failed to fetch the latest Go version. Exiting..."
        exit 1
    fi
    
    # Construct the download URL and tarball name
    GO_TARBALL="${LATEST_GO_VERSION}.linux-amd64.tar.gz"
    GO_DOWNLOAD_URL="https://golang.org/dl/${GO_TARBALL}"
    
    # Download and install Go
    curl -L -o "$GO_TARBALL" "$GO_DOWNLOAD_URL" 2>&1 | tee download.log
    if [ $? -ne 0 ]; then
        echo "Failed to download Go tarball. See download.log for details."
        exit 1
    fi

    # Extract and install Go
    tar -C /usr/local -xvzf "$GO_TARBALL"
    rm -f "$GO_TARBALL"  # Delete the tarball after installation
    echo "Go has been installed."

    # Update the PATH for Go
    echo "export PATH=\$PATH:/usr/local/go/bin" >> ~/.bashrc
    export PATH=$PATH:/usr/local/go/bin
else
    echo "Go is already installed."
fi

# 5. Pull the Go script to the correct directory
echo "Pulling statsPuller.go from GitHub..."
USER_HOME=$(eval echo ~$SUDO_USER)
mkdir -p "$USER_HOME/RemoteAccess/GoFiles"
wget -q -O "$USER_HOME/RemoteAccess/GoFiles/statsPuller.go" https://raw.githubusercontent.com/iLikeLemonR/Basic-Server-Setup/refs/heads/main/statsPuller.go

# 6. Download required Go dependencies
echo "Downloading Go dependencies..."
cd "$USER_HOME/RemoteAccess/GoFiles"
go mod init system-stats
go get github.com/shirou/gopsutil/cpu
go get github.com/shirou/gopsutil/mem
go get github.com/shirou/gopsutil/disk
go get github.com/tklauser/go-sysconf

# 7. Set up NGINX to serve index.html and proxy to Go service
NGINX_CONFIG="/etc/nginx/sites-available/remoteaccess"
if [ ! -f "$NGINX_CONFIG" ]; then
    echo "Setting up NGINX configuration for remote access..."

    cat > $NGINX_CONFIG <<EOF
server {
    listen 80;
    server_name localhost;

    location / {
        root /var/www/html;
        index index.html;
    }

    location /metrics {
        proxy_pass http://localhost:8080;
    }
}
EOF

    # Enable the site and restart NGINX
    ln -s /etc/nginx/sites-available/remoteaccess /etc/nginx/sites-enabled/
    systemctl restart nginx
else
    echo "NGINX configuration for remoteaccess already exists."
fi

# 8. Set up the Go script to run on startup
SYSTEMD_SERVICE="/etc/systemd/system/go-stats-puller.service"
if [ ! -f "$SYSTEMD_SERVICE" ]; then
    echo "Setting up Go script to run on startup..."

    # Create systemd service for Go script
    cat > $SYSTEMD_SERVICE <<EOF
[Unit]
Description=Go Stats Puller
After=network.target

[Service]
ExecStart=/usr/local/go/bin/go run $USER_HOME/RemoteAccess/GoFiles/statsPuller.go
WorkingDirectory=$USER_HOME/RemoteAccess/GoFiles
Restart=always
User=$SUDO_USER
group=www-data

[Install]
WantedBy=multi-user.target
EOF

    # Enable and start the service
    systemctl daemon-reload
    systemctl enable go-stats-puller.service
    systemctl start go-stats-puller.service
else
    echo "Go script is already set up to run on startup."
fi

# 9. Final message
echo "Setup completed successfully."
echo "NGINX is configured to serve index.html and forward /metrics requests to the Go server."
echo "The Go script is set to run on startup."
echo "You can visit the site at http://localhost and access the metrics at http://localhost/metrics."
# another test comment