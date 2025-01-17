<?php
// auth.php
session_start();

$session_token = $_COOKIE['session_token'] ?? null;
$token_file = file_get_contents('.env2') . md5($session_token);

// Ensure the token matches exactly with the one saved on the server
if ($session_token && file_exists($token_file) && file_get_contents($token_file) === $session_token) {
    echo 'Authorized';
} else {
    header('HTTP/1.1 401 Unauthorized');
    exit;
}
?>
