// Admin routes - Clean version without fs imports
import { adminMiddleware } from '../middleware/admin.js';
import { authMiddleware } from '../middleware/auth.js';
import { createJWT } from '../utils/jwt.js';
import bcrypt from 'bcryptjs';

// Simple admin login page (embedded)
const adminLoginPage = `<!DOCTYPE html>
<html>
<head>
    <title>Admin Login - CRM</title>
    <style>
        body { font-family: Arial, sans-serif; background: #f0f0f0; display: flex; justify-content: center; align-items: center; min-height: 100vh; margin: 0; }
        .login-card { background: white; padding: 40px; border-radius: 8px; box-shadow: 0 4px 12px rgba(0,0,0,0.1); width: 300px; }
        .login-card h1 { text-align: center; color: #333; margin-bottom: 30px; }
        .form-group { margin-bottom: 20px; }
        .form-group label { display: block; margin-bottom: 5px; color: #555; }
        .form-group input { width: 100%; padding: 10px; border: 1px solid #ddd; border-radius: 4px; font-size: 14px; }
        .login-btn { width: 100%; padding: 12px; background: #007bff; color: white; border: none; border-radius: 4px; font-size: 16px; cursor: pointer; }
        .login-btn:hover { background: #0056b3; }
        .error { background: #f8d7da; color: #721c24; padding: 10px; border-radius: 4px; margin-bottom: 15px; display: none; }
    </style>
</head>
<body>
    <div class="login-card">
        <h1>Admin Login</h1>
        <div class="error" id="error"></div>
        <form id="loginForm">
            <div class="form-group">
                 <label for="email">Email</label>
                <input type="text" id="email" required>
            </div>
            <div class="form-group">
                <label for="password">Password</label>
                <input type="password" id="password" required>
            </div>
            <button type="submit" class="login-btn">Login</button>
        </form>
    </div>
    <script>
        document.getElementById('loginForm').addEventListener('submit', async function(e) {
            e.preventDefault();
            const email = document.getElementById('email').value;
            const password = document.getElementById('password').value;
            const errorDiv = document.getElementById('error');
            try {
                const response = await fetch('/login', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ email, password })
                });
                const data = await response.json();
                if (response.ok && data.user && data.user.role === 'admin') {
                    localStorage.setItem('admin_token', data.token);
                    localStorage.setItem('admin_user', JSON.stringify(data.user));
                    window.location.href = '/admin/dashboard';
                } else {
                    errorDiv.textContent = data.error || 'Login failed';
                    errorDiv.style.display = 'block';
                }
            } catch (err) {
                errorDiv.textContent = 'Network error';
                errorDiv.style.display = 'block';
            }
        });
    </script>
</body>
</html>`;

// Simple admin dashboard (embedded)
const adminDashboardPage = `<!DOCTYPE html>
<html>
<head>
    <title>Admin Dashboard - CRM</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: Arial, sans-serif; background: #f5f5f5; }
        .header { background: #333; color: white; padding: 20px; display: flex; justify-content: space-between; align-items: center; }
        .header h1 { font-size: 24px; }
        .user-info { display: flex; align-items: center; gap: 15px; }
        .logout-btn { background: #dc3545; color: white; border: none; padding: 8px 16px; border-radius: 4px; cursor: pointer; }
        .container { padding: 30px; max-width: 1200px; margin: 0 auto; }
        .tabs { display: flex; margin-bottom: 30px; }
        .tab { flex: 1; padding: 15px; text-align: center; background: white; border: 1px solid #ddd; cursor: pointer; }
        .tab.active { background: #007bff; color: white; }
        .tab:hover { background: #f8f9fa; }
        .tab-content { display: none; }
        .tab-content.active { display: block; }
        .card { background: white; padding: 25px; border-radius: 8px; box-shadow: 0 2px 8px rgba(0,0,0,0.1); margin-bottom: 20px; }
        .stats { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 20px; margin-bottom: 30px; }
        .stat-card { background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 8px rgba(0,0,0,0.1); text-align: center; }
        .stat-number { font-size: 32px; font-weight: bold; color: #007bff; margin-bottom: 8px; }
        .stat-label { color: #666; font-size: 14px; }
        .btn { padding: 10px 16px; border: none; border-radius: 4px; cursor: pointer; font-size: 14px; margin-right: 10px; margin-bottom: 10px; }
        .btn-primary { background: #007bff; color: white; }
        .btn-danger { background: #dc3545; color: white; }
        .btn-success { background: #28a745; color: white; }
        .btn-warning { background: #ffc107; color: #212529; }
        .data-table { width: 100%; border-collapse: collapse; margin-top: 20px; }
        .data-table th, .data-table td { padding: 12px; text-align: left; border-bottom: 1px solid #ddd; }
        .data-table th { background: #f8f9fa; font-weight: 600; }
        .data-table tr:hover { background: #f5f5f5; }
        .loading { text-align: center; padding: 20px; color: #666; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Admin Dashboard</h1>
        <div class="user-info">
            <span id="userEmail">Loading...</span>
            <button class="logout-btn" onclick="logout()">Logout</button>
        </div>
    </div>
    <div class="container">
        <div class="tabs">
            <div class="tab active" onclick="showTab('overview')">Overview</div>
            <div class="tab" onclick="showTab('users')">Users</div>
            <div class="tab" onclick="showTab('contacts')">Contacts</div>
            <div class="tab" onclick="showTab('calls')">Call Logs</div>
        </div>

        <div id="overview" class="tab-content active">
            <div class="stats">
                <div class="stat-card">
                    <div class="stat-number" id="totalUsers">-</div>
                    <div class="stat-label">Total Users</div>
                </div>
                <div class="stat-card">
                    <div class="stat-number" id="totalContacts">-</div>
                    <div class="stat-label">Total Contacts</div>
                </div>
                <div class="stat-card">
                    <div class="stat-number" id="totalCalls">-</div>
                    <div class="stat-label">Total Call Logs</div>
                </div>
                <div class="stat-card">
                    <div class="stat-number" id="adminCount">-</div>
                    <div class="stat-label">Admin Users</div>
                </div>
            </div>
            <div class="card">
                <h2>Quick Actions</h2>
                <button class="btn btn-success" onclick="showTab('users')">Manage Users</button>
                <button class="btn btn-primary" onclick="showTab('contacts')">View Contacts</button>
                <button class="btn btn-primary" onclick="showTab('calls')">View Call Logs</button>
                <button class="btn btn-primary" onclick="createUser()">Add New User</button>
            </div>
        </div>

        <div id="users" class="tab-content">
            <div class="card">
                <h2>User Management</h2>
                <button class="btn btn-success" onclick="createUser()">Add New User</button>
                <button class="btn btn-primary" onclick="loadUsers()">Refresh</button>
                <div id="usersTable">
                    <div class="loading">Loading users...</div>
                </div>
            </div>
        </div>

        <div id="contacts" class="tab-content">
            <div class="card">
                <h2>Contact Management</h2>
                <button class="btn btn-primary" onclick="loadContacts()">Refresh</button>
                <div id="contactsTable">
                    <div class="loading">Loading contacts...</div>
                </div>
            </div>
        </div>

        <div id="calls" class="tab-content">
            <div class="card">
                <h2>Call Log Management</h2>
                <button class="btn btn-primary" onclick="loadCalls()">Refresh</button>
                <div id="callsTable">
                    <div class="loading">Loading call logs...</div>
                </div>
            </div>
        </div>
    </div>

    <script>
        let allUsers = [], allContacts = [], allCalls = [];

        function getAuthHeaders() {
            const token = localStorage.getItem('admin_token');
            return { 'Authorization': 'Bearer ' + token, 'Content-Type': 'application/json' };
        }

        function isAuthenticated() {
            const token = localStorage.getItem('admin_token');
            const user = JSON.parse(localStorage.getItem('admin_user') || 'null');
            return token && user && user.role === 'admin';
        }

        function logout() {
            localStorage.removeItem('admin_token');
            localStorage.removeItem('admin_user');
            window.location.href = '/admin/';
        }

        function showTab(tabName) {
            document.querySelectorAll('.tab-content').forEach(el => el.classList.remove('active'));
            document.querySelectorAll('.tab').forEach(el => el.classList.remove('active'));
            document.getElementById(tabName).classList.add('active');
            event.target.classList.add('active');
            
            if (tabName === 'users' && allUsers.length === 0) loadUsers();
            if (tabName === 'contacts' && allContacts.length === 0) loadContacts();
            if (tabName === 'calls' && allCalls.length === 0) loadCalls();
        }

        async function loadDashboardData() {
            const [usersRes, contactsRes, callsRes] = await Promise.all([
                fetch('/admin/users', { headers: getAuthHeaders() }),
                fetch('/contacts', { headers: getAuthHeaders() }),
                fetch('/calls', { headers: getAuthHeaders() })
            ]);
            
            if (usersRes.ok && contactsRes.ok && callsRes.ok) {
                allUsers = await usersRes.json();
                allContacts = await contactsRes.json();
                allCalls = await callsRes.json();
                
                document.getElementById('totalUsers').textContent = allUsers.length;
                document.getElementById('totalContacts').textContent = allContacts.length;
                document.getElementById('totalCalls').textContent = allCalls.length;
                document.getElementById('adminCount').textContent = allUsers.filter(u => u.role === 'admin').length;
            }
        }

        async function loadUsers() {
            try {
                const response = await fetch('/admin/users', { headers: getAuthHeaders() });
                if (response.ok) {
                    allUsers = await response.json();
                    const table = '<table class="data-table"><thead><tr><th>ID</th><th>Name</th><th>Email</th><th>Role</th><th>Created</th><th>Actions</th></tr></thead><tbody>' +
                        allUsers.map(u => '<tr><td>' + u.id + '</td><td>' + (u.name || 'N/A') + '</td><td>' + u.email + '</td><td>' + u.role + '</td><td>' + new Date(u.created_at).toLocaleString() + '</td><td><button class="btn btn-warning" onclick="flushUserData(' + u.id + ')">Flush Data</button> <button class="btn btn-danger" onclick="deleteUser(' + u.id + ')" ' + (u.id === JSON.parse(localStorage.getItem('admin_user')).id ? 'disabled' : '') + '>Delete</button></td></tr>').join('') +
                        '</tbody></table>';
                    document.getElementById('usersTable').innerHTML = table;
                }
            } catch (error) {
                document.getElementById('usersTable').innerHTML = '<div class="loading">Failed to load users</div>';
            }
        }

        async function loadContacts() {
            try {
                const response = await fetch('/contacts', { headers: getAuthHeaders() });
                if (response.ok) {
                    allContacts = await response.json();
                    const userMap = {}; allUsers.forEach(u => userMap[u.id] = u);
                    const table = '<table class="data-table"><thead><tr><th>ID</th><th>Name</th><th>Phone</th><th>Created By</th><th>Created</th><th>Actions</th></tr></thead><tbody>' +
                        allContacts.map(c => '<tr><td>' + c.id + '</td><td>' + c.name + '</td><td>' + c.phone_number + '</td><td>' + (userMap[c.created_by_user_id]?.name || 'Unknown') + '</td><td>' + new Date(c.created_at).toLocaleString() + '</td><td><button class="btn btn-danger" onclick="deleteContact(' + c.id + ')">Delete</button></td></tr>').join('') +
                        '</tbody></table>';
                    document.getElementById('contactsTable').innerHTML = table;
                }
            } catch (error) {
                document.getElementById('contactsTable').innerHTML = '<div class="loading">Failed to load contacts</div>';
            }
        }

        async function loadCalls() {
            try {
                const response = await fetch('/calls', { headers: getAuthHeaders() });
                if (response.ok) {
                    allCalls = await response.json();
                    const userMap = {}; allUsers.forEach(u => userMap[u.id] = u);
                    const table = '<table class="data-table"><thead><tr><th>ID</th><th>Phone</th><th>Direction</th><th>Duration</th><th>User</th><th>Time</th><th>Actions</th></tr></thead><tbody>' +
                        allCalls.map(c => '<tr><td>' + c.id + '</td><td>' + c.phone_number + '</td><td>' + c.direction + '</td><td>' + (c.duration || 0) + 's</td><td>' + (userMap[c.user_id]?.name || 'Unknown') + '</td><td>' + new Date(c.start_time).toLocaleString() + '</td><td><button class="btn btn-danger" onclick="deleteCall(' + c.id + ')">Delete</button></td></tr>').join('') +
                        '</tbody></table>';
                    document.getElementById('callsTable').innerHTML = table;
                }
            } catch (error) {
                document.getElementById('callsTable').innerHTML = '<div class="loading">Failed to load calls</div>';
            }
        }

        async function deleteUser(userId) {
            if (confirm('Delete this user?')) {
                const response = await fetch('/admin/users/' + userId, { method: 'DELETE', headers: getAuthHeaders() });
                if (response.ok) { loadUsers(); loadDashboardData(); }
            }
        }

        async function deleteContact(contactId) {
            if (confirm('Delete this contact?')) {
                const response = await fetch('/contacts/' + contactId, { method: 'DELETE', headers: getAuthHeaders() });
                if (response.ok) { loadContacts(); loadDashboardData(); }
            }
        }

        async function deleteCall(callId) {
            if (confirm('Delete this call log?')) {
                const response = await fetch('/calls/' + callId, { method: 'DELETE', headers: getAuthHeaders() });
                if (response.ok) { loadCalls(); loadDashboardData(); }
            }
        }

        async function flushUserData(userId) {
            if (confirm('Flush ALL data for this user?')) {
                const response = await fetch('/admin/users/' + userId + '/data', { method: 'DELETE', headers: getAuthHeaders() });
                if (response.ok) { loadContacts(); loadCalls(); loadDashboardData(); }
            }
        }

        function createUser() {
            const name = prompt('User name:'); if (!name) return;
            const email = prompt('Email:'); if (!email) return;
            const password = prompt('Password:'); if (!password) return;
            const role = prompt('Role (user/admin):', 'user'); if (!role) return;
            
            fetch('/admin/users', {
                method: 'POST',
                headers: getAuthHeaders(),
                body: JSON.stringify({ name, email, password, role })
            }).then(r => r.json()).then(data => {
                if (data.id) { loadUsers(); loadDashboardData(); alert('User created!'); }
                else alert('Failed: ' + (data.error || 'Unknown error'));
            });
        }

        document.addEventListener('DOMContentLoaded', async function() {
            if (!isAuthenticated()) { window.location.href = '/admin/'; return; }
            const user = JSON.parse(localStorage.getItem('admin_user') || '{}');
            document.getElementById('userEmail').textContent = user.email || 'Admin';
            await loadDashboardData();
        });
    </script>
</body>
</html>`;

export function registerAdminRoutes(app) {
    // Get admin login page
    app.get('/admin/', (c) => {
        return c.html(adminLoginPage);
    });

    // Get admin dashboard page
    app.get('/admin/dashboard', (c) => {
        return c.html(adminDashboardPage);
    });
}
