<?php
require_once 'config.php';
require_once 'Auth.php';

header('Content-Type: application/json');

// Only allow POST requests
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['success' => false, 'message' => 'Method not allowed']);
    exit;
}

// Get JSON input
$input = json_decode(file_get_contents('php://input'), true);

if (!$input || !isset($input['username']) || !isset($input['email']) || !isset($input['password'])) {
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

    // Check if username or email already exists
    $stmt = $pdo->prepare("SELECT COUNT(*) FROM users WHERE username = ? OR email = ?");
    $stmt->execute([$input['username'], $input['email']]);
    if ($stmt->fetchColumn() > 0) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'Username or email already exists']);
        exit;
    }

    // Check if there's already a pending request
    $stmt = $pdo->prepare("SELECT COUNT(*) FROM signup_requests WHERE username = ? OR email = ?");
    $stmt->execute([$input['username'], $input['email']]);
    if ($stmt->fetchColumn() > 0) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'A signup request is already pending for this username or email']);
        exit;
    }

    // Hash password
    $passwordHash = password_hash($input['password'], PASSWORD_DEFAULT);

    // Create signup request
    $stmt = $pdo->prepare("
        INSERT INTO signup_requests (username, email, password_hash)
        VALUES (?, ?, ?)
        RETURNING id
    ");
    $stmt->execute([$input['username'], $input['email'], $passwordHash]);
    $requestId = $stmt->fetchColumn();

    // Notify all admin users
    $stmt = $pdo->prepare("
        INSERT INTO notifications (user_id, type, message, link, metadata)
        SELECT id, 'signup_request', ?, ?, ?
        FROM users
        WHERE is_admin = true
    ");
    $message = "New signup request from {$input['username']}";
    $link = "/admin/signup-requests";
    $metadata = json_encode([
        'request_id' => $requestId,
        'username' => $input['username'],
        'email' => $input['email']
    ]);
    $stmt->execute([$message, $link, $metadata]);

    echo json_encode(['success' => true, 'message' => 'Signup request submitted successfully']);

} catch (PDOException $e) {
    error_log("Database error: " . $e->getMessage());
    http_response_code(500);
    echo json_encode(['success' => false, 'message' => 'An error occurred while processing your request']);
} catch (Exception $e) {
    error_log("Error: " . $e->getMessage());
    http_response_code(500);
    echo json_encode(['success' => false, 'message' => 'An error occurred while processing your request']);
} 