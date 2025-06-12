<?php
require_once 'Auth.php';

// Start output buffering
ob_start();

// Start session with secure settings
ini_set('session.cookie_httponly', 1);
ini_set('session.cookie_secure', 1);
ini_set('session.use_only_cookies', 1);
session_start();

// CSRF protection utility
function get_csrf_token() {
    if (empty($_SESSION['csrf_token'])) {
        $_SESSION['csrf_token'] = bin2hex(random_bytes(32));
    }
    return $_SESSION['csrf_token'];
}

function validate_csrf_token($token) {
    return isset($_SESSION['csrf_token']) && hash_equals($_SESSION['csrf_token'], $token);
}

try {
    $auth = new Auth();

    if ($_SERVER['REQUEST_METHOD'] === 'POST') {
        // Validate CSRF token
        $csrfToken = $_POST['csrf_token'] ?? '';
        if (!validate_csrf_token($csrfToken)) {
            throw new Exception('Invalid CSRF token.');
        }
        
        // Validate and sanitize input
        $username = filter_input(INPUT_POST, 'username', FILTER_SANITIZE_FULL_SPECIAL_CHARS);
        $password = filter_input(INPUT_POST, 'password', FILTER_UNSAFE_RAW);
        $mfaCode = filter_input(INPUT_POST, 'mfa_code', FILTER_SANITIZE_NUMBER_INT);
        
        if (!$username || !$password) {
            throw new Exception('Invalid input. Please try again.');
        }
        
        // Attempt login
        if ($auth->login($username, $password, $mfaCode)) {
            // Get proper redirect URL based on user role
            $redirectUrl = $auth->getRedirectUrl($_SESSION['user_id']);
            
            // AJAX request
            if (isset($_SERVER['HTTP_X_REQUESTED_WITH']) && strtolower($_SERVER['HTTP_X_REQUESTED_WITH']) === 'xmlhttprequest') {
                echo json_encode(['success' => true, 'redirect' => $redirectUrl]);
                ob_end_flush();
                exit;
            } else {
                // Normal POST
                header('Location: ' . $redirectUrl);
                ob_end_flush();
                exit;
            }
        }
    } elseif ($_SERVER['REQUEST_METHOD'] === 'GET') {
        // For AJAX: provide CSRF token
        if (isset($_GET['get_csrf_token'])) {
            echo json_encode(['csrf_token' => get_csrf_token()]);
            exit;
        }
        
        // Check if user is already logged in
        if (isset($_SESSION['user_id']) && $auth->validateSession()) {
            $redirectUrl = $auth->getRedirectUrl($_SESSION['user_id']);
            header('Location: ' . $redirectUrl);
            exit;
        }
    }
} catch (Exception $e) {
    if (isset($_SERVER['HTTP_X_REQUESTED_WITH']) && strtolower($_SERVER['HTTP_X_REQUESTED_WITH']) === 'xmlhttprequest') {
        echo json_encode(['success' => false, 'message' => $e->getMessage()]);
    } else {
        echo '<div class="alert alert-danger text-center">' . htmlspecialchars($e->getMessage()) . '</div>';
    }
}
?>