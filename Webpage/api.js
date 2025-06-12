// API client for Weblyn
class API {
    constructor() {
        this.baseUrl = '/api.php';
        this.csrfToken = document.querySelector('meta[name="csrf-token"]')?.content;
    }

    // Helper method to handle API responses
    async handleResponse(response) {
        const data = await response.json();
        
        if (!response.ok) {
            throw new Error(data.error || 'An error occurred');
        }
        
        return data;
    }

    // Helper method to make API requests
    async request(endpoint, method = 'GET', data = null) {
        const options = {
            method,
            headers: {
                'Content-Type': 'application/json',
                'X-Requested-With': 'XMLHttpRequest'
            },
            credentials: 'same-origin'
        };

        if (this.csrfToken) {
            options.headers['X-CSRF-Token'] = this.csrfToken;
        }

        if (data) {
            options.body = JSON.stringify(data);
        }

        const response = await fetch(`${this.baseUrl}?endpoint=${endpoint}`, options);
        return this.handleResponse(response);
    }

    // User profile methods
    async getUserProfile() {
        return this.request('user');
    }

    async updateUserProfile(data) {
        return this.request('user', 'PUT', data);
    }

    // Notification methods
    async getNotifications() {
        return this.request('notifications');
    }

    async markNotificationAsRead(notificationId) {
        return this.request('notifications/read', 'POST', { notification_id: notificationId });
    }
}

// Create a global API instance
window.api = new API();

// Examples:
/*
// Get user profile
api.getUserProfile()
    .then(data => {
        console.log('User profile:', data);
    })
    .catch(error => {
        console.error('Error fetching profile:', error);
    });

// Update user profile
api.updateUserProfile({ email: 'new@example.com' })
    .then(data => {
        console.log('Profile updated:', data);
    })
    .catch(error => {
        console.error('Error updating profile:', error);
    });

// Get notifications
api.getNotifications()
    .then(data => {
        console.log('Notifications:', data);
    })
    .catch(error => {
        console.error('Error fetching notifications:', error);
    });
*/ 