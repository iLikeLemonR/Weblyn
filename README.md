# Weblyn

A secure, web-based dashboard for managing your server with modern authentication and monitoring features.

## ✨ Features

- 🔐 **Secure Authentication**
  - Database-backed user management
  - Multi-factor authentication (MFA) support
  - Rate limiting for login attempts
  - Session management with Redis
  - Password complexity requirements

- 🌐 **Web Interface**
  - Modern, responsive design
  - Dark mode support
  - Real-time system monitoring
  - Secure HTTPS support (with domain)
  - Content Security Policy (CSP) protection

- 📊 **System Monitoring**
  - CPU usage tracking
  - Memory utilization
  - Disk space monitoring
  - Real-time updates
  - Historical data tracking

- 🔒 **Security Features**
  - SSL/TLS encryption (with domain)
  - Secure session management
  - Audit logging
  - CSRF protection
  - XSS protection
  - SQL injection prevention

## 🛠️ Requirements

- Debian-based Linux distribution (Ubuntu, Debian, etc.)
- Root access
- Domain name (optional, but recommended for HTTPS)

## 📥 Installation

1. Clone the repository:
```bash
git clone https://github.com/yourusername/weblyn.git
cd weblyn
```

2. Run the setup script:
```bash
sudo ./setup.sh
```

3. Follow the prompts to:
   - Configure your domain (optional)
   - Create an admin user
   - Set up the system

## 🔧 Configuration

The main configuration file is located at `/var/www/html/config.php`. You can modify:
- Database settings
- Redis configuration
- Session parameters
- Security settings
- MFA options
- Rate limiting
- Audit logging

## 🚀 Usage

1. Access the dashboard:
   - With domain: `https://your-domain.com`
   - Without domain: `http://localhost`

2. Log in with your admin credentials

3. Enable MFA (recommended):
   - Go to your profile settings
   - Enable MFA
   - Scan the QR code with your authenticator app

## 🧹 Uninstallation

To completely remove Weblyn:

```bash
sudo ./uninstall.sh
```

Follow the prompts to remove components selectively.

## 🔐 Security Notes

- Change default passwords after installation
- Enable MFA for all users
- Keep the system updated
- Monitor audit logs regularly
- Use a strong domain SSL certificate

## 📝 License

This project is licensed under the MIT License - see the LICENSE file for details.

## ⚠️ Disclaimer

This software is provided "as is", without warranty of any kind. Use at your own risk.

---

