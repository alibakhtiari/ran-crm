// Authentication utilities for admin frontend

class AuthManager {
    constructor() {
        this.token = localStorage.getItem('admin_token');
        this.user = JSON.parse(localStorage.getItem('admin_user') || 'null');
    }

    // Check if user is authenticated and is admin
    isAuthenticated() {
        return this.token && this.user && this.user.role === 'admin';
    }

    // Get auth headers for API requests
    getAuthHeaders() {
        return {
            'Authorization': `Bearer ${this.token}`,
            'Content-Type': 'application/json'
        };
    }

    // Login function
    async login(email, password) {
        try {
            const response = await fetch('/login', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({ email, password })
            });

            const data = await response.json();

            if (response.ok) {
                this.token = data.token;
                this.user = data.user;

                // Store in localStorage
                localStorage.setItem('admin_token', this.token);
                localStorage.setItem('admin_user', JSON.stringify(this.user));

                return { success: true, user: this.user };
            } else {
                return { success: false, error: data.error || 'Login failed' };
            }
        } catch (error) {
            return { success: false, error: 'Network error: ' + error.message };
        }
    }

    // Logout function
    logout() {
        this.token = null;
        this.user = null;
        localStorage.removeItem('admin_token');
        localStorage.removeItem('admin_user');
        window.location.href = '/admin/';
    }

    // Check token validity
    async validateToken() {
        if (!this.token) {
            return false;
        }

        try {
            const response = await fetch('/contacts', {
                method: 'GET',
                headers: this.getAuthHeaders()
            });

            return response.ok;
        } catch (error) {
            return false;
        }
    }
}

// Initialize auth manager
const auth = new AuthManager();

// Login form handler
document.addEventListener('DOMContentLoaded', function () {
    const loginForm = document.getElementById('loginForm');
    const loginBtn = document.getElementById('loginBtn');
    const loginText = document.getElementById('loginText');
    const loginSpinner = document.getElementById('loginSpinner');
    const errorMessage = document.getElementById('errorMessage');

    if (loginForm) {
        // Check if already authenticated
        if (auth.isAuthenticated()) {
            window.location.href = '/admin/dashboard';
            return;
        }

        loginForm.addEventListener('submit', async function (e) {
            e.preventDefault();

            const email = document.getElementById('email').value.trim();
            const password = document.getElementById('password').value;

            if (!email || !password) {
                showError('Please enter both email and password');
                return;
            }

            // Show loading state
            setLoadingState(true);
            hideError();

            try {
                const result = await auth.login(email, password);

                if (result.success) {
                    if (result.user.role === 'admin') {
                        window.location.href = '/admin/dashboard';
                    } else {
                        showError('Access denied. Admin privileges required.');
                        setLoadingState(false);
                    }
                } else {
                    showError(result.error);
                    setLoadingState(false);
                }
            } catch (error) {
                showError('An unexpected error occurred');
                setLoadingState(false);
            }
        });
    }

    function setLoadingState(loading) {
        loginBtn.disabled = loading;
        if (loading) {
            loginText.style.display = 'none';
            loginSpinner.style.display = 'block';
        } else {
            loginText.style.display = 'block';
            loginSpinner.style.display = 'none';
        }
    }

    function showError(message) {
        errorMessage.textContent = message;
        errorMessage.style.display = 'block';
    }

    function hideError() {
        errorMessage.style.display = 'none';
    }
});

// Utility function to check authentication on other pages
function requireAuth() {
    if (!auth.isAuthenticated()) {
        window.location.href = '/admin/';
        return false;
    }
    return true;
}

// Export for use in other scripts
if (typeof module !== 'undefined' && module.exports) {
    module.exports = AuthManager;
}
