document.addEventListener('DOMContentLoaded', () => {
    // Initialize admin functionality
    initializeAdminPanel();
    loadUserData();
    loadNotifications();
    setupEventListeners();
});

function initializeAdminPanel() {
    // Set up navigation
    const navLinks = document.querySelectorAll('.sidebar nav a');
    navLinks.forEach(link => {
        link.addEventListener('click', (e) => {
            e.preventDefault();
            const target = e.currentTarget.getAttribute('href').substring(1);
            showSection(target);
        });
    });
}

function showSection(sectionId) {
    // Hide all sections
    document.querySelectorAll('.admin-section').forEach(section => {
        section.style.display = 'none';
    });
    
    // Show selected section
    const targetSection = document.getElementById(sectionId);
    if (targetSection) {
        targetSection.style.display = 'block';
    }
    
    // Update active nav link
    document.querySelectorAll('.sidebar nav li').forEach(li => {
        li.classList.remove('active');
    });
    const activeLink = document.querySelector(`.sidebar nav a[href="#${sectionId}"]`);
    if (activeLink) {
        activeLink.parentElement.classList.add('active');
    }
}

async function loadUserData() {
    try {
        const response = await fetch('api.php?endpoint=user');
        if (!response.ok) throw new Error('Failed to load user data');
        
        const data = await response.json();
        if (data.success) {
            updateUserInterface(data.data);
        }
    } catch (error) {
        console.error('Error loading user data:', error);
        showError('Failed to load user data');
    }
}

function updateUserInterface(userData) {
    // Update username and avatar
    document.getElementById('username').textContent = userData.username;
    document.getElementById('userAvatar').textContent = userData.username.charAt(0).toUpperCase();
    
    // Load user list if admin
    if (userData.role === 'admin') {
        loadUserList();
    }
}

async function loadUserList() {
    try {
        const response = await fetch('api.php?endpoint=users');
        if (!response.ok) throw new Error('Failed to load user list');
        
        const data = await response.json();
        if (data.success) {
            displayUserList(data.data);
        }
    } catch (error) {
        console.error('Error loading user list:', error);
        showError('Failed to load user list');
    }
}

function displayUserList(users) {
    const userList = document.getElementById('userList');
    userList.innerHTML = users.map(user => `
        <div class="user-item">
            <div class="user-info">
                <div class="user-avatar">${user.username.charAt(0).toUpperCase()}</div>
                <div class="user-details">
                    <div class="user-name">${user.username}</div>
                    <div class="user-email">${user.email}</div>
                </div>
            </div>
            <div class="user-actions">
                <button class="btn-edit" onclick="editUser(${user.id})">
                    <i class="fas fa-edit"></i>
                </button>
                <button class="btn-delete" onclick="deleteUser(${user.id})">
                    <i class="fas fa-trash"></i>
                </button>
            </div>
        </div>
    `).join('');
}

async function loadNotifications() {
    try {
        const response = await fetch('api.php?endpoint=notifications');
        if (!response.ok) throw new Error('Failed to load notifications');
        
        const data = await response.json();
        if (data.success) {
            displayNotifications(data.data);
            updateNotificationBadge(data.data.filter(n => !n.is_read).length);
        }
    } catch (error) {
        console.error('Error loading notifications:', error);
        showError('Failed to load notifications');
    }
}

function displayNotifications(notifications) {
    const notificationList = document.getElementById('notificationList');
    notificationList.innerHTML = notifications.map(notification => `
        <div class="notification-item ${notification.is_read ? 'read' : 'unread'}">
            <div class="notification-content">
                <div class="notification-message">${notification.message}</div>
                <div class="notification-time">${formatDate(notification.created_at)}</div>
            </div>
            ${!notification.is_read ? `
                <button class="btn-mark-read" onclick="markNotificationRead(${notification.id})">
                    <i class="fas fa-check"></i>
                </button>
            ` : ''}
        </div>
    `).join('');
}

function updateNotificationBadge(count) {
    const badge = document.getElementById('notificationCount');
    badge.textContent = count;
    badge.style.display = count > 0 ? 'block' : 'none';
}

function formatDate(dateString) {
    const date = new Date(dateString);
    return date.toLocaleString();
}

function setupEventListeners() {
    // Notification bell click handler
    document.querySelector('.notifications-bell').addEventListener('click', () => {
        showSection('notifications');
    });
    
    // Setup other event listeners as needed
}

// Error handling
function showError(message) {
    // Implement error display logic
    console.error(message);
    // You can add a toast notification or error message display here
}

// User management functions
async function editUser(userId) {
    // Implement user edit functionality
    console.log('Edit user:', userId);
}

async function deleteUser(userId) {
    if (confirm('Are you sure you want to delete this user?')) {
        try {
            const response = await fetch(`api.php?endpoint=users&id=${userId}`, {
                method: 'DELETE',
                headers: {
                    'Content-Type': 'application/json'
                }
            });
            
            if (!response.ok) throw new Error('Failed to delete user');
            
            const data = await response.json();
            if (data.success) {
                loadUserList(); // Refresh user list
                showSuccess('User deleted successfully');
            }
        } catch (error) {
            console.error('Error deleting user:', error);
            showError('Failed to delete user');
        }
    }
}

async function markNotificationRead(notificationId) {
    try {
        const response = await fetch('api.php?endpoint=notifications', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                notification_id: notificationId,
                action: 'mark_read'
            })
        });
        
        if (!response.ok) throw new Error('Failed to mark notification as read');
        
        const data = await response.json();
        if (data.success) {
            loadNotifications(); // Refresh notifications
        }
    } catch (error) {
        console.error('Error marking notification as read:', error);
        showError('Failed to mark notification as read');
    }
}

function showSuccess(message) {
    // Implement success message display
    console.log('Success:', message);
    // You can add a toast notification or success message display here
} 