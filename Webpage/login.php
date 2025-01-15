<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Login - Remote Console</title>
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.1/dist/css/bootstrap.min.css">
    <style>
        body.dark-mode {
            background-color: #121212;
            color: #fff;
        }
        body.dark-mode .form-control {
            background-color: #333;
            color: #fff;
        }
        body.dark-mode .form-control:focus {
            background-color: #333;
            color: #fff;
        }
        body.dark-mode .btn-primary {
            background-color: #007bff;
            border-color: #007bff;
        }
        body.dark-mode .btn-primary:hover {
            background-color: #0056b3;
            border-color: #0056b3;
        }
    </style>
</head>
<body class="dark-mode">
    <div class="container my-5">
        <h2 class="text-center">Login</h2>

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
                echo '<div class="alert alert-danger text-center">Invalid username or password.</div>';
            }
        }
        ?>

        <form action="" method="POST">
            <div class="mb-3">
                <label for="username" class="form-label">Username</label>
                <input type="text" class="form-control" id="username" name="username" required>
            </div>
            <div class="mb-3">
                <label for="password" class="form-label">Password</label>
                <input type="password" class="form-control" id="password" name="password" required>
            </div>
            <button type="submit" class="btn btn-primary w-100">Login</button>
        </form>
    </div>
</body>
</html>
