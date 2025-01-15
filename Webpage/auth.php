<?php
// auth.php
session_start();

$session_token = $_COOKIE['session_token'] ?? null;
$token_file = '/var/www/html/session_tokens/' . md5($session_token);

if ($session_token && file_exists($token_file)) {
    echo 'Authorized';
} else {
    header('HTTP/1.1 401 Unauthorized');
    exit;
}
?>
