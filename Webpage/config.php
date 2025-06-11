<?php
// Database configuration
define('DB_HOST', 'localhost');
define('DB_NAME', 'weblyn');
define('DB_USER', 'weblyn_user');
define('DB_PASS', ''); // Set this in production

// Redis configuration
define('REDIS_HOST', 'localhost');
define('REDIS_PORT', 6379);
define('REDIS_PASS', ''); // Set this in production

// Session configuration
define('SESSION_LIFETIME', 3600); // 1 hour
define('SESSION_REFRESH_TIME', 300); // 5 minutes
define('SESSION_NAME', 'weblyn_session');

// Security configuration
define('PASSWORD_MIN_LENGTH', 12);
define('PASSWORD_REQUIRE_SPECIAL', true);
define('PASSWORD_REQUIRE_NUMBERS', true);
define('PASSWORD_REQUIRE_UPPERCASE', true);
define('PASSWORD_REQUIRE_LOWERCASE', true);

// Rate limiting
define('LOGIN_ATTEMPTS_LIMIT', 5);
define('LOGIN_ATTEMPTS_WINDOW', 300); // 5 minutes

// MFA configuration
define('MFA_ENABLED', true);
define('MFA_ISSUER', 'Weblyn');
define('MFA_ALGORITHM', 'sha1');
define('MFA_DIGITS', 6);
define('MFA_PERIOD', 30);

// CSP configuration
define('CSP_ENABLED', true);
define('CSP_REPORT_URI', '/csp-report.php');

// Audit logging
define('AUDIT_LOG_ENABLED', true);
define('AUDIT_LOG_PATH', '/var/log/weblyn/audit.log'); 