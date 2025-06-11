<?php
require_once 'Auth.php';

// Start output buffering
ob_start();

// Start session with secure settings
ini_set('session.cookie_httponly', 1);
ini_set('session.cookie_secure', 1);
ini_set('session.use_only_cookies', 1);
session_start();

try {
    $auth = new Auth();

    if ($_SERVER['REQUEST_METHOD'] == 'POST') {
        // Validate and sanitize input
        $username = filter_input(INPUT_POST, 'username', FILTER_SANITIZE_STRING);
        $password = filter_input(INPUT_POST, 'password', FILTER_SANITIZE_STRING);
        $mfaCode = filter_input(INPUT_POST, 'mfa_code', FILTER_SANITIZE_STRING);
        
        if (!$username || !$password) {
            throw new Exception('Invalid input. Please try again.');
        }
        
        // Attempt login
        if ($auth->login($username, $password, $mfaCode)) {
            // Redirect to dashboard
            header("Location: /dashboard.html");
            ob_end_flush();
            exit;
        }
    }
} catch (Exception $e) {
    echo '<div class="alert alert-danger text-center">' . htmlspecialchars($e->getMessage()) . '</div>';
}
?>
