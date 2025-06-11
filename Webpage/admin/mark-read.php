<?php
require_once '../config.php';
require_once '../Auth.php';

header('Content-Type: application/json');

// Check if user is logged in
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

if (!$input || !isset($input['notification_id'])) {
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => 'Missing notification ID']);
    exit;
}

try {
    $pdo = new PDO(
        "pgsql:host={$config['db_host']};dbname={$config['db_name']}",
        $config['db_user'],
        $config['db_pass']
    );
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);

    // Mark notification as read
    $stmt = $pdo->prepare("
        UPDATE notifications
        SET is_read = true
        WHERE id = ? AND user_id = ?
    ");
    $stmt->execute([$input['notification_id'], $_SESSION['user_id']]);

    if ($stmt->rowCount() === 0) {
        http_response_code(404);
        echo json_encode(['success' => false, 'message' => 'Notification not found']);
        exit;
    }

    echo json_encode(['success' => true]);

} catch (PDOException $e) {
    error_log("Database error: " . $e->getMessage());
    http_response_code(500);
    echo json_encode(['success' => false, 'message' => 'An error occurred while marking the notification as read']);
} catch (Exception $e) {
    error_log("Error: " . $e->getMessage());
    http_response_code(500);
    echo json_encode(['success' => false, 'message' => 'An error occurred while marking the notification as read']);
} 