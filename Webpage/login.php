<?php
session_start();

// Read the credentials from the .env file
$env_file = '/var/www/html/.env';
if (file_exists($env_file)) {
    $env_data = file($env_file, FILE_IGNORE_NEW_LINES);
    foreach ($env_data as $line) {
        if (strpos($line, 'USERNAME=') === 0) {
            $valid_username = substr($line, 9);  // Extract the username
        }
        if (strpos($line, 'PASSWORD=') === 0) {
            $valid_password = substr($line, 9);  // Extract the password hash
        }
    }
} else {
    echo "Error: Credentials file not found.";
    exit;
}

if ($_SERVER['REQUEST_METHOD'] == 'POST') {
    $username = $_POST['username'];
    $password = $_POST['password'];

    // Check if the credentials are correct
    if ($username == $valid_username && password_verify($password, $valid_password)) {
        
        // Generate a random, secure session token
        $session_token = bin2hex(random_bytes(32));  // Generate a secure random token

        // Save the session token to a file or database securely (in a hidden, secure location)
        $token_file = '/var/www/html/session_tokens/' . md5($session_token);  // Use md5 to name the file
        file_put_contents($token_file, $session_token);

        // Set a cookie with the session token, making it secure and HttpOnly
        setcookie('session_token', $session_token, time() + 3600, '/', '', true, true);  // Secure cookie

        // Redirect the user to the dashboard
        header("Location: /dashboard.html");
        exit;
    } else {
        echo "Invalid username or password.";
    }
} else {
    // Display login form if not POST request
    echo '<form method="POST">
            Username: <input type="text" name="username" required><br>
            Password: <input type="password" name="password" required><br>
            <input type="submit" value="Login">
          </form>';
}
?>
