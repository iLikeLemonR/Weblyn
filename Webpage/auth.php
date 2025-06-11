<?php
// auth.php
// Start session with secure settings
ini_set('session.cookie_httponly', 1);
ini_set('session.cookie_secure', 1);
ini_set('session.use_only_cookies', 1);
session_start();

// Get the session token from cookie
$session_token = $_COOKIE['session_token'] ?? null;

// Validate token format
if (!$session_token || !preg_match('/^[a-f0-9]{64}$/', $session_token)) {
    error_log("Invalid session token format");
    header('HTTP/1.1 401 Unauthorized');
    exit;
}

// Get token directory from configuration
$token_dir = file_get_contents('/var/www/html/.env2');
if (!$token_dir) {
    error_log("Token directory configuration not found");
    header('HTTP/1.1 500 Internal Server Error');
    exit;
}

// Construct token file path
$token_file = $token_dir . md5($session_token);

// Validate token file exists and content matches
if (!file_exists($token_file)) {
    error_log("Session token file not found");
    header('HTTP/1.1 401 Unauthorized');
    exit;
}

$stored_token = file_get_contents($token_file);
if ($stored_token !== $session_token) {
    error_log("Session token mismatch");
    header('HTTP/1.1 401 Unauthorized');
    exit;
}

// Token is valid
echo 'Authorized';
?>
