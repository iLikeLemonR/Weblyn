<?php
require_once 'config.php';

// Only accept POST requests
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    header('HTTP/1.1 405 Method Not Allowed');
    exit;
}

// Get the raw POST data
$json = file_get_contents('php://input');

// Validate that it's valid JSON
$data = json_decode($json, true);
if (json_last_error() !== JSON_ERROR_NONE) {
    header('HTTP/1.1 400 Bad Request');
    exit;
}

// Log the CSP violation
if (AUDIT_LOG_ENABLED) {
    $logEntry = date('Y-m-d H:i:s') . " - CSP Violation:\n";
    $logEntry .= "User-Agent: " . $_SERVER['HTTP_USER_AGENT'] . "\n";
    $logEntry .= "IP Address: " . $_SERVER['REMOTE_ADDR'] . "\n";
    $logEntry .= "Violation Data: " . $json . "\n";
    $logEntry .= "----------------------------------------\n";

    file_put_contents(AUDIT_LOG_PATH, $logEntry, FILE_APPEND);
}

// Always return 204 No Content
header('HTTP/1.1 204 No Content');
?> 