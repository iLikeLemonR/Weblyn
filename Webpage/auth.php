<?php
require_once 'Auth.php';

// Start session with secure settings
ini_set('session.cookie_httponly', 1);
ini_set('session.cookie_secure', 1);
ini_set('session.use_only_cookies', 1);
session_start();

try {
    $auth = new Auth();
    
    if (!$auth->validateSession()) {
        header('HTTP/1.1 401 Unauthorized');
        exit;
    }
    
    echo 'Authorized';
} catch (Exception $e) {
    error_log("Authentication error: " . $e->getMessage());
    header('HTTP/1.1 500 Internal Server Error');
    exit;
}
?>
