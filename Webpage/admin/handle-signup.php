<?php
require_once '../config.php';
require_once '../Auth.php';

header('Content-Type: application/json');

// CSRF protection utility
function validate_csrf_token($token) {
    return isset($_SESSION['csrf_token']) && hash_equals($_SESSION['csrf_token'], $token);
}

// Start session with secure settings
ini_set('session.cookie_httponly', 1);
ini_set('session.cookie_secure', 1);
ini_set('session.use_only_cookies', 1);
session_start();

// Check if user is logged in
if (!isset($_SESSION['user_id'])) {
    http_response_code(401);
    echo json_encode(['success' => false, 'message' => 'Unauthorized']);
    exit;
}

// Only allow POST requests
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['success' => false, 'message' => 'Method not allowed']);
    exit;
}

// Get JSON input
$input = json_decode(file_get_contents('php://input'), true);

if (!$input || !isset($input['request_id']) || !isset($input['action']) || !isset($input['csrf_token'])) {
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => 'Missing required fields']);
    exit;
}

// Validate CSRF token
if (!validate_csrf_token($input['csrf_token'])) {
    http_response_code(403);
    echo json_encode(['success' => false, 'message' => 'Invalid CSRF token']);
    exit;
}

$config = require '../config.php';

try {
    $pdo = new PDO(
        "pgsql:host={$config['db_host']};dbname={$config['db_name']}",
        $config['db_user'],
        $config['db_pass'],
        [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::ATTR_EMULATE_PREPARES => false
        ]
    );

    // Check if user is admin
    $stmt = $pdo->prepare("SELECT is_admin FROM users WHERE id = ? AND is_active = true");
    $stmt->execute([$_SESSION['user_id']]);
    if (!$stmt->fetchColumn()) {
        http_response_code(403);
        echo json_encode(['success' => false, 'message' => 'Forbidden: Admin access required']);
        exit;
    }

    // Validate action
    if (!in_array($input['action'], ['approved', 'declined'])) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'Invalid action']);
        exit;
    }

    // Get signup request details
    $stmt = $pdo->prepare("
        SELECT username, email, password_hash
        FROM signup_requests
        WHERE id = ? AND status = 'pending'
    ");
    $stmt->execute([$input['request_id']]);
    $request = $stmt->fetch();

    if (!$request) {
        http_response_code(404);
        echo json_encode(['success' => false, 'message' => 'Signup request not found or already processed']);
        exit;
    }

    // Start transaction
    $pdo->beginTransaction();

    if ($input['action'] === 'approved') {
        // Check if username or email already exists
        $stmt = $pdo->prepare("SELECT COUNT(*) FROM users WHERE username = ? OR email = ?");
        $stmt->execute([$request['username'], $request['email']]);
        if ($stmt->fetchColumn() > 0) {
            throw new Exception('Username or email already exists');
        }

        // Create user account
        $stmt = $pdo->prepare("
            INSERT INTO users (username, email, password_hash, is_active)
            VALUES (?, ?, ?, true)
            RETURNING id
        ");
        $stmt->execute([$request['username'], $request['email'], $request['password_hash']]);
        $userId = $stmt->fetchColumn();

        // Create notification for the new user
        $stmt = $pdo->prepare("
            INSERT INTO notifications (user_id, type, message, created_at)
            VALUES (?, 'account_approved', 'Your account has been approved. You can now log in.', CURRENT_TIMESTAMP)
        ");
        $stmt->execute([$userId]);

        $message = 'Signup request approved successfully';
    } else {
        $message = 'Signup request declined';
    }

    // Update signup request status
    $stmt = $pdo->prepare("
        UPDATE signup_requests
        SET status = ?, processed_by = ?, processed_at = CURRENT_TIMESTAMP
        WHERE id = ?
    ");
    $stmt->execute([$input['action'], $_SESSION['user_id'], $input['request_id']]);

    // Log the action
    $stmt = $pdo->prepare("
        INSERT INTO audit_logs (user_id, action, details, created_at)
        VALUES (?, ?, ?, CURRENT_TIMESTAMP)
    ");
    $stmt->execute([
        $_SESSION['user_id'],
        'signup_' . $input['action'],
        json_encode([
            'request_id' => $input['request_id'],
            'username' => $request['username'],
            'email' => $request['email']
        ])
    ]);

    $pdo->commit();
    echo json_encode(['success' => true, 'message' => $message]);

} catch (PDOException $e) {
    if (isset($pdo) && $pdo->inTransaction()) {
        $pdo->rollBack();
    }
    error_log("Database error in handle-signup.php: " . $e->getMessage());
    http_response_code(500);
    echo json_encode(['success' => false, 'message' => 'An error occurred while processing the request']);
} catch (Exception $e) {
    if (isset($pdo) && $pdo->inTransaction()) {
        $pdo->rollBack();
    }
    error_log("Error in handle-signup.php: " . $e->getMessage());
    http_response_code(500);
    echo json_encode(['success' => false, 'message' => $e->getMessage()]);
} 