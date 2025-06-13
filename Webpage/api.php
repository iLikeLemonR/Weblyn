<?php
require_once 'config.php';
require_once 'auth.php';

// Start session with secure settings
ini_set('session.cookie_httponly', 1);
ini_set('session.cookie_secure', 1);
ini_set('session.use_only_cookies', 1);
session_start();

// Set headers for JSON API
header('Content-Type: application/json');
header('X-Content-Type-Options: nosniff');
header('X-Frame-Options: DENY');
header('X-XSS-Protection: 1; mode=block');

// Get configuration
$config = get_config();

// CSRF protection utility
function validate_csrf_token() {
    if (!isset($_POST['csrf_token']) || !isset($_SESSION['csrf_token']) || 
        !hash_equals($_SESSION['csrf_token'], $_POST['csrf_token'])) {
        http_response_code(403);
        echo json_encode(['error' => 'Invalid CSRF token']);
        exit;
    }
}

// Rate limiting
function check_rate_limit($ip, $endpoint) {
    global $config;
    $redis = new Redis();
    try {
        $redis->connect($config['REDIS_HOST'], $config['REDIS_PORT']);
        $redis->auth($config['REDIS_PASSWORD']);
        
        $key = "rate_limit:{$ip}:{$endpoint}";
        $current = $redis->incr($key);
        if ($current === 1) {
            $redis->expire($key, $config['RATE_LIMIT_WINDOW']);
        }
        
        if ($current > $config['RATE_LIMIT_MAX_REQUESTS']) {
            http_response_code(429);
            echo json_encode(['error' => 'Rate limit exceeded']);
            exit;
        }
    } catch (Exception $e) {
        error_log("Rate limit error: " . $e->getMessage());
    }
}

// Get client IP
$client_ip = $_SERVER['REMOTE_ADDR'];
if (isset($_SERVER['HTTP_X_FORWARDED_FOR'])) {
    $client_ip = $_SERVER['HTTP_X_FORWARDED_FOR'];
}

// Check if user is authenticated
if (!isset($_SESSION['user_id'])) {
    http_response_code(401);
    echo json_encode(['error' => 'Unauthorized']);
    exit;
}

// Get request method and endpoint
$method = $_SERVER['REQUEST_METHOD'];
$endpoint = isset($_GET['endpoint']) ? $_GET['endpoint'] : '';

// Apply rate limiting
check_rate_limit($client_ip, $endpoint);

// Handle different endpoints
switch ($endpoint) {
    case 'user':
        if ($method === 'GET') {
            // Get user profile
            try {
                $pdo = new PDO(
                    "mysql:host={$config['DB_HOST']};dbname={$config['DB_NAME']};charset=utf8mb4",
                    $config['DB_USER'],
                    $config['DB_PASSWORD'],
                    [
                        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
                        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
                        PDO::ATTR_EMULATE_PREPARES => false
                    ]
                );
                
                $stmt = $pdo->prepare("SELECT id, username, email, role, created_at FROM users WHERE id = ?");
                $stmt->execute([$_SESSION['user_id']]);
                $user = $stmt->fetch();
                
                if ($user) {
                    echo json_encode(['success' => true, 'data' => $user]);
                } else {
                    http_response_code(404);
                    echo json_encode(['error' => 'User not found']);
                }
            } catch (PDOException $e) {
                error_log("Database error: " . $e->getMessage());
                http_response_code(500);
                echo json_encode(['error' => 'Internal server error']);
            }
        } elseif ($method === 'PUT') {
            // Update user profile
            validate_csrf_token();
            
            $data = json_decode(file_get_contents('php://input'), true);
            if (!$data) {
                http_response_code(400);
                echo json_encode(['error' => 'Invalid JSON data']);
                exit;
            }
            
            try {
                $pdo = new PDO(
                    "mysql:host={$config['DB_HOST']};dbname={$config['DB_NAME']};charset=utf8mb4",
                    $config['DB_USER'],
                    $config['DB_PASSWORD'],
                    [
                        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
                        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
                        PDO::ATTR_EMULATE_PREPARES => false
                    ]
                );
                
                $allowed_fields = ['email'];
                $updates = [];
                $params = [];
                
                foreach ($data as $key => $value) {
                    if (in_array($key, $allowed_fields)) {
                        $updates[] = "$key = ?";
                        $params[] = $value;
                    }
                }
                
                if (empty($updates)) {
                    http_response_code(400);
                    echo json_encode(['error' => 'No valid fields to update']);
                    exit;
                }
                
                $params[] = $_SESSION['user_id'];
                $sql = "UPDATE users SET " . implode(', ', $updates) . " WHERE id = ?";
                $stmt = $pdo->prepare($sql);
                $stmt->execute($params);
                
                // Log the update
                $stmt = $pdo->prepare("INSERT INTO audit_logs (user_id, action, details) VALUES (?, 'profile_update', ?)");
                $stmt->execute([$_SESSION['user_id'], json_encode($data)]);
                
                echo json_encode(['success' => true, 'message' => 'Profile updated successfully']);
            } catch (PDOException $e) {
                error_log("Database error: " . $e->getMessage());
                http_response_code(500);
                echo json_encode(['error' => 'Internal server error']);
            }
        } else {
            http_response_code(405);
            echo json_encode(['error' => 'Method not allowed']);
        }
        break;
        
    case 'users':
        if ($method === 'GET') {
            // Check if user is admin
            if (!isset($_SESSION['role']) || $_SESSION['role'] !== 'admin') {
                http_response_code(403);
                echo json_encode(['error' => 'Unauthorized access']);
                exit;
            }
            
            try {
                $pdo = new PDO(
                    "mysql:host={$config['DB_HOST']};dbname={$config['DB_NAME']};charset=utf8mb4",
                    $config['DB_USER'],
                    $config['DB_PASSWORD'],
                    [
                        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
                        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
                        PDO::ATTR_EMULATE_PREPARES => false
                    ]
                );
                
                $stmt = $pdo->prepare("
                    SELECT id, username, email, role, created_at, last_login 
                    FROM users 
                    ORDER BY created_at DESC
                ");
                $stmt->execute();
                $users = $stmt->fetchAll();
                
                echo json_encode(['success' => true, 'data' => $users]);
            } catch (PDOException $e) {
                error_log("Database error: " . $e->getMessage());
                http_response_code(500);
                echo json_encode(['error' => 'Internal server error']);
            }
        } elseif ($method === 'DELETE') {
            // Check if user is admin
            if (!isset($_SESSION['role']) || $_SESSION['role'] !== 'admin') {
                http_response_code(403);
                echo json_encode(['error' => 'Unauthorized access']);
                exit;
            }
            
            $userId = isset($_GET['id']) ? $_GET['id'] : null;
            if (!$userId) {
                http_response_code(400);
                echo json_encode(['error' => 'User ID is required']);
                exit;
            }
            
            try {
                $pdo = new PDO(
                    "mysql:host={$config['DB_HOST']};dbname={$config['DB_NAME']};charset=utf8mb4",
                    $config['DB_USER'],
                    $config['DB_PASSWORD'],
                    [
                        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
                        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
                        PDO::ATTR_EMULATE_PREPARES => false
                    ]
                );
                
                // Start transaction
                $pdo->beginTransaction();
                
                // Delete user's notifications
                $stmt = $pdo->prepare("DELETE FROM notifications WHERE user_id = ?");
                $stmt->execute([$userId]);
                
                // Delete user's audit logs
                $stmt = $pdo->prepare("DELETE FROM audit_logs WHERE user_id = ?");
                $stmt->execute([$userId]);
                
                // Delete the user
                $stmt = $pdo->prepare("DELETE FROM users WHERE id = ?");
                $stmt->execute([$userId]);
                
                // Commit transaction
                $pdo->commit();
                
                echo json_encode(['success' => true, 'message' => 'User deleted successfully']);
            } catch (PDOException $e) {
                // Rollback transaction on error
                if ($pdo->inTransaction()) {
                    $pdo->rollBack();
                }
                error_log("Database error: " . $e->getMessage());
                http_response_code(500);
                echo json_encode(['error' => 'Internal server error']);
            }
        } else {
            http_response_code(405);
            echo json_encode(['error' => 'Method not allowed']);
        }
        break;
        
    case 'notifications':
        if ($method === 'GET') {
            // Get user notifications
            try {
                $pdo = new PDO(
                    "mysql:host={$config['DB_HOST']};dbname={$config['DB_NAME']};charset=utf8mb4",
                    $config['DB_USER'],
                    $config['DB_PASSWORD'],
                    [
                        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
                        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
                        PDO::ATTR_EMULATE_PREPARES => false
                    ]
                );
                
                $stmt = $pdo->prepare("
                    SELECT id, message, created_at, is_read 
                    FROM notifications 
                    WHERE user_id = ? 
                    ORDER BY created_at DESC 
                    LIMIT 50
                ");
                $stmt->execute([$_SESSION['user_id']]);
                $notifications = $stmt->fetchAll();
                
                echo json_encode(['success' => true, 'data' => $notifications]);
            } catch (PDOException $e) {
                error_log("Database error: " . $e->getMessage());
                http_response_code(500);
                echo json_encode(['error' => 'Internal server error']);
            }
        } elseif ($method === 'POST') {
            validate_csrf_token();
            
            $data = json_decode(file_get_contents('php://input'), true);
            if (!$data || !isset($data['notification_id']) || !isset($data['action'])) {
                http_response_code(400);
                echo json_encode(['error' => 'Invalid request data']);
                exit;
            }
            
            if ($data['action'] === 'mark_read') {
                try {
                    $pdo = new PDO(
                        "mysql:host={$config['DB_HOST']};dbname={$config['DB_NAME']};charset=utf8mb4",
                        $config['DB_USER'],
                        $config['DB_PASSWORD'],
                        [
                            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
                            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
                            PDO::ATTR_EMULATE_PREPARES => false
                        ]
                    );
                    
                    $stmt = $pdo->prepare("
                        UPDATE notifications 
                        SET is_read = 1 
                        WHERE id = ? AND user_id = ?
                    ");
                    $stmt->execute([$data['notification_id'], $_SESSION['user_id']]);
                    
                    echo json_encode(['success' => true, 'message' => 'Notification marked as read']);
                } catch (PDOException $e) {
                    error_log("Database error: " . $e->getMessage());
                    http_response_code(500);
                    echo json_encode(['error' => 'Internal server error']);
                }
            } else {
                http_response_code(400);
                echo json_encode(['error' => 'Invalid action']);
            }
        } else {
            http_response_code(405);
            echo json_encode(['error' => 'Method not allowed']);
        }
        break;
        
    default:
        http_response_code(404);
        echo json_encode(['error' => 'Endpoint not found']);
        break;
} 