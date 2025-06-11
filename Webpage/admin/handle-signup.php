<?php
require_once '../config.php';
require_once '../Auth.php';

header('Content-Type: application/json');

// Check if user is admin
session_start();
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

if (!$input || !isset($input['request_id']) || !isset($input['action'])) {
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => 'Missing required fields']);
    exit;
}

try {
    $pdo = new PDO(
        "pgsql:host={$config['db_host']};dbname={$config['db_name']}",
        $config['db_user'],
        $config['db_pass']
    );
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);

    // Check if user is admin
    $stmt = $pdo->prepare("SELECT is_admin FROM users WHERE id = ?");
    $stmt->execute([$_SESSION['user_id']]);
    if (!$stmt->fetchColumn()) {
        http_response_code(403);
        echo json_encode(['success' => false, 'message' => 'Forbidden']);
        exit;
    }

    // Get signup request details
    $stmt = $pdo->prepare("
        SELECT username, email, password_hash
        FROM signup_requests
        WHERE id = ? AND status = 'pending'
    ");
    $stmt->execute([$input['request_id']]);
    $request = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$request) {
        http_response_code(404);
        echo json_encode(['success' => false, 'message' => 'Signup request not found or already processed']);
        exit;
    }

    // Start transaction
    $pdo->beginTransaction();

    if ($input['action'] === 'approved') {
        // Create user account
        $stmt = $pdo->prepare("
            INSERT INTO users (username, email, password_hash)
            VALUES (?, ?, ?)
            RETURNING id
        ");
        $stmt->execute([$request['username'], $request['email'], $request['password_hash']]);
        $userId = $stmt->fetchColumn();

        // Create notification for the new user
        $stmt = $pdo->prepare("
            INSERT INTO notifications (user_id, type, message)
            VALUES (?, 'account_approved', 'Your account has been approved. You can now log in.')
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
        INSERT INTO audit_logs (user_id, action, details)
        VALUES (?, ?, ?)
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
    if ($pdo->inTransaction()) {
        $pdo->rollBack();
    }
    error_log("Database error: " . $e->getMessage());
    http_response_code(500);
    echo json_encode(['success' => false, 'message' => 'An error occurred while processing the request']);
} catch (Exception $e) {
    if ($pdo->inTransaction()) {
        $pdo->rollBack();
    }
    error_log("Error: " . $e->getMessage());
    http_response_code(500);
    echo json_encode(['success' => false, 'message' => 'An error occurred while processing the request']);
} 