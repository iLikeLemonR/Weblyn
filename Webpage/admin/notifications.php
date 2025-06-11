<?php
require_once '../config.php';
require_once '../Auth.php';

// Start session with secure settings
ini_set('session.cookie_httponly', 1);
ini_set('session.cookie_secure', 1);
ini_set('session.use_only_cookies', 1);
session_start();

// Check if user is logged in
if (!isset($_SESSION['user_id'])) {
    header('Location: /login.html');
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

    // Check if user is admin and active
    $stmt = $pdo->prepare("SELECT is_admin FROM users WHERE id = ? AND is_active = true");
    $stmt->execute([$_SESSION['user_id']]);
    if (!$stmt->fetchColumn()) {
        header('Location: /dashboard.html');
        exit;
    }

    // Get unread notifications count
    $stmt = $pdo->prepare("
        SELECT COUNT(*) 
        FROM notifications 
        WHERE user_id = ? AND is_read = false
    ");
    $stmt->execute([$_SESSION['user_id']]);
    $unreadCount = $stmt->fetchColumn();

    // Get pending signup requests
    $stmt = $pdo->prepare("
        SELECT id, username, email, created_at
        FROM signup_requests
        WHERE status = 'pending'
        ORDER BY created_at DESC
    ");
    $stmt->execute();
    $signupRequests = $stmt->fetchAll();

    // Get recent notifications
    $stmt = $pdo->prepare("
        SELECT id, type, message, created_at, is_read, link, metadata
        FROM notifications
        WHERE user_id = ?
        ORDER BY created_at DESC
        LIMIT 50
    ");
    $stmt->execute([$_SESSION['user_id']]);
    $notifications = $stmt->fetchAll();

    // Generate CSRF token
    if (empty($_SESSION['csrf_token'])) {
        $_SESSION['csrf_token'] = bin2hex(random_bytes(32));
    }
    $csrfToken = $_SESSION['csrf_token'];

} catch (PDOException $e) {
    error_log("Database error in notifications.php: " . $e->getMessage());
    $error = "An error occurred while fetching notifications";
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Admin Notifications - Weblyn</title>
    <link rel="stylesheet" href="../dashcss.css">
    <style>
        .notifications-container {
            max-width: 800px;
            margin: 20px auto;
            padding: 20px;
        }
        .notification-card {
            background: var(--card-bg);
            border-radius: 8px;
            padding: 15px;
            margin-bottom: 15px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            cursor: pointer;
        }
        .notification-card.unread {
            border-left: 4px solid var(--accent-color);
        }
        .signup-request {
            background: var(--card-bg);
            border-radius: 8px;
            padding: 15px;
            margin-bottom: 15px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        .signup-request .actions {
            margin-top: 10px;
            display: flex;
            gap: 10px;
        }
        .signup-request .actions button {
            padding: 5px 15px;
            border: none;
            border-radius: 4px;
            cursor: pointer;
        }
        .signup-request .actions .approve {
            background: var(--success-color);
            color: white;
        }
        .signup-request .actions .decline {
            background: var(--error-color);
            color: white;
        }
        .timestamp {
            color: var(--text-secondary);
            font-size: 0.9em;
        }
    </style>
</head>
<body>
    <div class="notifications-container">
        <h2>Admin Notifications</h2>
        
        <?php if (isset($error)): ?>
            <div class="error-message"><?php echo htmlspecialchars($error); ?></div>
        <?php endif; ?>

        <h3>Pending Signup Requests</h3>
        <?php if (empty($signupRequests)): ?>
            <p>No pending signup requests</p>
        <?php else: ?>
            <?php foreach ($signupRequests as $request): ?>
                <div class="signup-request" data-request-id="<?php echo htmlspecialchars($request['id']); ?>">
                    <h4><?php echo htmlspecialchars($request['username']); ?></h4>
                    <p>Email: <?php echo htmlspecialchars($request['email']); ?></p>
                    <p class="timestamp">Requested: <?php echo htmlspecialchars(date('M j, Y g:i A', strtotime($request['created_at']))); ?></p>
                    <div class="actions">
                        <button class="approve" onclick="handleSignupRequest(<?php echo htmlspecialchars($request['id']); ?>, 'approved')">Approve</button>
                        <button class="decline" onclick="handleSignupRequest(<?php echo htmlspecialchars($request['id']); ?>, 'declined')">Decline</button>
                    </div>
                </div>
            <?php endforeach; ?>
        <?php endif; ?>

        <h3>Recent Notifications</h3>
        <?php if (empty($notifications)): ?>
            <p>No notifications</p>
        <?php else: ?>
            <?php foreach ($notifications as $notification): ?>
                <div class="notification-card <?php echo $notification['is_read'] ? '' : 'unread'; ?>" 
                     data-notification-id="<?php echo htmlspecialchars($notification['id']); ?>">
                    <p><?php echo htmlspecialchars($notification['message']); ?></p>
                    <p class="timestamp"><?php echo htmlspecialchars(date('M j, Y g:i A', strtotime($notification['created_at']))); ?></p>
                </div>
            <?php endforeach; ?>
        <?php endif; ?>
    </div>

    <script>
        const csrfToken = '<?php echo $csrfToken; ?>';

        async function handleSignupRequest(requestId, action) {
            try {
                const response = await fetch('handle-signup.php', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                        'X-Requested-With': 'XMLHttpRequest'
                    },
                    body: JSON.stringify({
                        request_id: requestId,
                        action: action,
                        csrf_token: csrfToken
                    })
                });

                const data = await response.json();
                
                if (data.success) {
                    // Remove the request from the UI
                    const requestElement = document.querySelector(`[data-request-id="${requestId}"]`);
                    if (requestElement) {
                        requestElement.remove();
                    }
                    
                    // Show success message
                    alert(data.message);
                } else {
                    throw new Error(data.message);
                }
            } catch (error) {
                alert(error.message || 'An error occurred while processing the request');
            }
        }

        // Mark notifications as read when clicked
        document.querySelectorAll('.notification-card').forEach(card => {
            card.addEventListener('click', async function() {
                const notificationId = this.dataset.notificationId;
                if (this.classList.contains('unread')) {
                    try {
                        const response = await fetch('mark-read.php', {
                            method: 'POST',
                            headers: {
                                'Content-Type': 'application/json',
                                'X-Requested-With': 'XMLHttpRequest'
                            },
                            body: JSON.stringify({
                                notification_id: notificationId,
                                csrf_token: csrfToken
                            })
                        });

                        const data = await response.json();
                        
                        if (data.success) {
                            this.classList.remove('unread');
                        }
                    } catch (error) {
                        console.error('Error marking notification as read:', error);
                    }
                }
            });
        });
    </script>
</body>
</html> 