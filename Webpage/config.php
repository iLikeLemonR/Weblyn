<?php
return [
    // Database configuration
    'db_host' => getenv('DB_HOST') ?: 'localhost',
    'db_name' => getenv('DB_NAME') ?: 'weblyn',
    'db_user' => getenv('DB_USER') ?: 'weblyn_user',
    'db_pass' => getenv('DB_PASS') ?: '',

    // Redis configuration
    'redis_host' => getenv('REDIS_HOST') ?: 'localhost',
    'redis_port' => getenv('REDIS_PORT') ?: 6379,
    'redis_pass' => getenv('REDIS_PASS') ?: '',

    // Session configuration
    'session_lifetime' => getenv('SESSION_LIFETIME') ?: 3600,
    'session_refresh_time' => getenv('SESSION_REFRESH_TIME') ?: 300,
    'session_name' => getenv('SESSION_NAME') ?: 'weblyn_session',

    // Security configuration
    'password_min_length' => getenv('PASSWORD_MIN_LENGTH') ?: 12,
    'password_require_special' => getenv('PASSWORD_REQUIRE_SPECIAL') ?: true,
    'password_require_numbers' => getenv('PASSWORD_REQUIRE_NUMBERS') ?: true,
    'password_require_uppercase' => getenv('PASSWORD_REQUIRE_UPPERCASE') ?: true,
    'password_require_lowercase' => getenv('PASSWORD_REQUIRE_LOWERCASE') ?: true,

    // Rate limiting
    'login_attempts_limit' => getenv('LOGIN_ATTEMPTS_LIMIT') ?: 5,
    'login_attempts_window' => getenv('LOGIN_ATTEMPTS_WINDOW') ?: 300,

    // MFA configuration
    'mfa_enabled' => getenv('MFA_ENABLED') ?: true,
    'mfa_issuer' => getenv('MFA_ISSUER') ?: 'Weblyn',
    'mfa_algorithm' => getenv('MFA_ALGORITHM') ?: 'sha1',
    'mfa_digits' => getenv('MFA_DIGITS') ?: 6,
    'mfa_period' => getenv('MFA_PERIOD') ?: 30,

    // CSP configuration
    'csp_enabled' => getenv('CSP_ENABLED') ?: true,
    'csp_report_uri' => getenv('CSP_REPORT_URI') ?: '/csp-report.php',

    // Audit logging
    'audit_log_enabled' => getenv('AUDIT_LOG_ENABLED') ?: true,
    'audit_log_path' => getenv('AUDIT_LOG_PATH') ?: '/var/log/weblyn/audit.log',
]; 