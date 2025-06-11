<?php
// Start output buffering
ob_start();

// Start session with secure settings
ini_set('session.cookie_httponly', 1);
ini_set('session.cookie_secure', 1);
ini_set('session.use_only_cookies', 1);
session_start();

// Read the credentials from the .env file
$env_file = '/var/www/html/.env';
if (!file_exists($env_file)) {
    error_log("Error: Credentials file not found at $env_file");
    header("HTTP/1.1 500 Internal Server Error");
    echo "Error: System configuration error. Please contact administrator.";
    exit;
}

// Initialize variables
$valid_username = null;
$valid_password = null;

// Read and parse the .env file
$env_data = file($env_file, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
foreach ($env_data as $line) {
    if (strpos($line, 'USERNAME=') === 0) {
        $valid_username = trim(substr($line, 9));
    }
    if (strpos($line, 'PASSWORD=') === 0) {
        $valid_password = trim(substr($line, 9));
    }
}

// Validate that we have both username and password
if (!$valid_username || !$valid_password) {
    error_log("Error: Invalid credentials configuration in $env_file");
    header("HTTP/1.1 500 Internal Server Error");
    echo "Error: System configuration error. Please contact administrator.";
    exit;
}

if ($_SERVER['REQUEST_METHOD'] == 'POST') {
    // Validate and sanitize input
    $username = filter_input(INPUT_POST, 'username', FILTER_SANITIZE_STRING);
    $password = filter_input(INPUT_POST, 'password', FILTER_SANITIZE_STRING);
    
    if (!$username || !$password) {
        echo '<div class="alert alert-danger text-center">Invalid input. Please try again.</div>';
        exit;
    }
    
    // Check if the credentials are correct
    if ($username === $valid_username && password_verify($password, $valid_password)) {
        // Generate a random, secure session token
        $session_token = bin2hex(random_bytes(32));
        
        // Set secure cookie with proper settings
        setcookie(
            'session_token',
            $session_token,
            [
                'expires' => time() + 3600, // 1 hour expiration
                'path' => '/',
                'secure' => true,
                'httponly' => true,
                'samesite' => 'Strict'
            ]
        );
        
        // Save the session token securely
        $token_dir = file_get_contents('/var/www/html/.env2');
        if (!$token_dir) {
            error_log("Error: Token directory configuration not found");
            header("HTTP/1.1 500 Internal Server Error");
            echo "Error: System configuration error. Please contact administrator.";
            exit;
        }
        
        $token_file = $token_dir . md5($session_token);
        if (!file_put_contents($token_file, $session_token)) {
            error_log("Error: Failed to save session token");
            header("HTTP/1.1 500 Internal Server Error");
            echo "Error: System error. Please try again.";
            exit;
        }
        
        // Redirect to dashboard
        header("Location: /dashboard.html");
        ob_end_flush();
        exit;
    } else {
        // Add a small delay to prevent brute force attacks
        sleep(1);
        echo '<div class="alert alert-danger text-center">Invalid username or password.</div>';
    }
}
?>
