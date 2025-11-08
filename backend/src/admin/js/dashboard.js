// Dashboard functionality for admin interface

// Global variables
let allUsers = [];
let allContacts = [];
let allCalls = [];
let filteredContacts = [];
let filteredCalls = [];

// Initialize dashboard when page loads
document.addEventListener('DOMContentLoaded', async function () {
    // Check authentication
    if (!requireAuth()) {
        return;
    }

    // Set user info
    document.getElementById('userEmail').textContent = auth.user.email;

    // Load initial data
    await loadDashboardData();

    // Setup event listeners
    setupEventListeners();
});

// Setup event listeners
function setupEventListeners() {
    // Create user form
    const createUserForm = document.getElementById('createUserForm');
    if (createUserForm) {
        createUserForm.addEventListener('submit', handleCreateUser);
    }

    // Close modal when clicking outside
    const modal = document.getElementById('createUserModal');
    if (modal) {
        modal.addEventListener('click', function (e) {
            if (e.target === modal) {
                closeCreateUserModal();
            }
        });
    }
}

// Load all dashboard data
async function loadDashboardData() {
    try {
        await Promise.all([
            loadUsers(),
            loadContacts(),
            loadCalls(),
            loadOverviewStats()
        ]);
    } catch (error) {
        console.error('Error loading dashboard data:', error);
        showError('Failed to load dashboard data');
    }
}

// Load overview statistics
async function loadOverviewStats() {
    try {
        // Get basic counts
        const usersResponse = await fetch('/admin/users', {
            headers: auth.getAuthHeaders()
        });
        const users = await usersResponse.json();

        const contactsResponse = await fetch('/contacts', {
            headers: auth.getAuthHeaders()
        });
        const contacts = await contactsResponse.json();

        const callsResponse = await fetch('/calls', {
            headers: auth.getAuthHeaders()
        });
        const calls = await callsResponse.json();

        // Update UI
        document.getElementById('totalUsers').textContent = users.length;
        document.getElementById('totalContacts').textContent = contacts.length;
        document.getElementById('totalCalls').textContent = calls.length;

        const adminCount = users.filter(user => user.role === 'admin').length;
        document.getElementById('adminCount').textContent = adminCount;

    } catch (error) {
        console.error('Error loading overview stats:', error);
    }
}

// Load users data
async function loadUsers() {
    try {
        const response = await fetch('/admin/users', {
            headers: auth.getAuthHeaders()
        });

        if (response.ok) {
            allUsers = await response.json();
            displayUsers();
            updateUserFilters();
        } else {
            throw new Error('Failed to load users');
        }
    } catch (error) {
        console.error('Error loading users:', error);
        document.getElementById('usersTableContainer').innerHTML =
            '<p class="error-message">Failed to load users</p>';
    }
}

// Display users table
function displayUsers(users = allUsers) {
    const container = document.getElementById('usersTableContainer');

    if (users.length === 0) {
        container.innerHTML = '<p>No users found</p>';
        return;
    }

    const table = `
        <table class="users-table">
            <thead>
                <tr>
                    <th>ID</th>
                    <th>Name</th>
                    <th>Email</th>
                    <th>Role</th>
                    <th>Created</th>
                    <th>Actions</th>
                </tr>
            </thead>
            <tbody>
                ${users.map(user => `
                    <tr>
                        <td>${user.id}</td>
                        <td>${user.name || 'N/A'}</td>
                        <td>${user.email}</td>
                        <td><span class="role-badge role-${user.role}">${user.role}</span></td>
                        <td>${formatDate(user.created_at)}</td>
                        <td>
                            <button class="btn btn-primary" onclick="viewUserData(${user.id})" ${user.id === auth.user.id ? 'disabled' : ''}>
                                View Data
                            </button>
                            <button class="btn btn-danger" onclick="deleteUser(${user.id})" ${user.id === auth.user.id ? 'disabled' : ''}>
                                Delete
                            </button>
                        </td>
                    </tr>
                `).join('')}
            </tbody>
        </table>
    `;

    container.innerHTML = table;
}

// Load contacts data
async function loadContacts() {
    try {
        const response = await fetch('/contacts', {
            headers: auth.getAuthHeaders()
        });

        if (response.ok) {
            allContacts = await response.json();
            filteredContacts = [...allContacts];
            displayContacts();
            updateUserFilters();
        } else {
            throw new Error('Failed to load contacts');
        }
    } catch (error) {
        console.error('Error loading contacts:', error);
        document.getElementById('contactsTableContainer').innerHTML =
            '<p class="error-message">Failed to load contacts</p>';
    }
}

// Display contacts table
function displayContacts(contacts = filteredContacts) {
    const container = document.getElementById('contactsTableContainer');

    if (contacts.length === 0) {
        container.innerHTML = '<p>No contacts found</p>';
        return;
    }

    // Create user lookup map
    const userMap = {};
    allUsers.forEach(user => {
        userMap[user.id] = user;
    });

    const table = `
        <table class="data-table">
            <thead>
                <tr>
                    <th>ID</th>
                    <th>Name</th>
                    <th>Phone</th>
                    <th>Created By</th>
                    <th>Created</th>
                    <th>Actions</th>
                </tr>
            </thead>
            <tbody>
                ${contacts.map(contact => {
        const creator = userMap[contact.created_by_user_id];
        return `
                        <tr>
                            <td>${contact.id}</td>
                            <td>${contact.name}</td>
                            <td>${contact.phone_number}</td>
                            <td>${creator ? creator.name || creator.email : 'Unknown'}</td>
                            <td>${formatDate(contact.created_at)}</td>
                            <td>
                                <button class="btn btn-danger" onclick="deleteContact(${contact.id})">
                                    Delete
                                </button>
                            </td>
                        </tr>
                    `;
    }).join('')}
            </tbody>
        </table>
    `;

    container.innerHTML = table;
}

// Load calls data
async function loadCalls() {
    try {
        const response = await fetch('/calls', {
            headers: auth.getAuthHeaders()
        });

        if (response.ok) {
            allCalls = await response.json();
            filteredCalls = [...allCalls];
            displayCalls();
            updateUserFilters();
        } else {
            throw new Error('Failed to load calls');
        }
    } catch (error) {
        console.error('Error loading calls:', error);
        document.getElementById('callsTableContainer').innerHTML =
            '<p class="error-message">Failed to load calls</p>';
    }
}

// Display calls table
function displayCalls(calls = filteredCalls) {
    const container = document.getElementById('callsTableContainer');

    if (calls.length === 0) {
        container.innerHTML = '<p>No calls found</p>';
        return;
    }

    // Create user lookup map
    const userMap = {};
    allUsers.forEach(user => {
        userMap[user.id] = user;
    });

    const table = `
        <table class="data-table">
            <thead>
                <tr>
                    <th>ID</th>
                    <th>Phone</th>
                    <th>Direction</th>
                    <th>Duration</th>
                    <th>User</th>
                    <th>Start Time</th>
                    <th>Actions</th>
                </tr>
            </thead>
            <tbody>
                ${calls.map(call => {
        const user = userMap[call.user_id];
        return `
                        <tr>
                            <td>${call.id}</td>
                            <td>${call.phone_number}</td>
                            <td><span class="call-direction direction-${call.direction}">${call.direction}</span></td>
                            <td>${formatDuration(call.duration)}</td>
                            <td>${user ? user.name || user.email : 'Unknown'}</td>
                            <td>${formatDate(call.start_time)}</td>
                            <td>
                                <button class="btn btn-danger" onclick="deleteCall(${call.id})">
                                    Delete
                                </button>
                            </td>
                        </tr>
                    `;
    }).join('')}
            </tbody>
        </table>
    `;

    container.innerHTML = table;
}

// Update user filter dropdowns
function updateUserFilters() {
    const userFilter = document.getElementById('userFilter');
    const callUserFilter = document.getElementById('callUserFilter');

    const userOptions = allUsers.map(user =>
        `<option value="${user.id}">${user.name || user.email}</option>`
    ).join('');

    if (userFilter) {
        userFilter.innerHTML = '<option value="">All Users</option>' + userOptions;
    }

    if (callUserFilter) {
        callUserFilter.innerHTML = '<option value="">All Users</option>' + userOptions;
    }
}

// Filter contacts by user
function filterContactsByUser() {
    const userId = document.getElementById('userFilter').value;
    if (userId) {
        filteredContacts = allContacts.filter(contact => contact.created_by_user_id == userId);
    } else {
        filteredContacts = [...allContacts];
    }
    displayContacts();
}

// Filter calls by user
function filterCallsByUser() {
    const userId = document.getElementById('callUserFilter').value;
    if (userId) {
        filteredCalls = allCalls.filter(call => call.user_id == userId);
    } else {
        filteredCalls = [...allCalls];
    }
    filterCallsByDirection(); // Apply direction filter as well
}

// Filter calls by direction
function filterCallsByDirection() {
    const userId = document.getElementById('callUserFilter').value;
    const direction = document.getElementById('callDirectionFilter').value;

    let filtered = [...allCalls];

    if (userId) {
        filtered = filtered.filter(call => call.user_id == userId);
    }

    if (direction) {
        filtered = filtered.filter(call => call.direction === direction);
    }

    filteredCalls = filtered;
    displayCalls();
}

// View user data (contacts and calls)
async function viewUserData(userId) {
    try {
        // Load user contacts
        const contactsResponse = await fetch(`/admin/users/${userId}/contacts`, {
            headers: auth.getAuthHeaders()
        });
        const contactsData = await contactsResponse.json();

        // Load user calls
        const callsResponse = await fetch(`/admin/users/${userId}/calls`, {
            headers: auth.getAuthHeaders()
        });
        const callsData = await callsResponse.json();

        // Load user stats
        const statsResponse = await fetch(`/admin/users/${userId}/stats`, {
            headers: auth.getAuthHeaders()
        });
        const statsData = await statsResponse.json();

        // Create modal content
        const modal = document.createElement('div');
        modal.className = 'modal';
        modal.innerHTML = `
            <div class="modal-content" style="max-width: 800px; max-height: 80vh; overflow-y: auto;">
                <span class="close" onclick="this.closest('.modal').remove()">&times;</span>
                <h2>User Data: ${contactsData.user.name || contactsData.user.email}</h2>
                
                <div class="stats-grid">
                    <div class="stat-card">
                        <div class="stat-number">${statsData.stats.contacts}</div>
                        <div class="stat-label">Contacts</div>
                    </div>
                    <div class="stat-card">
                        <div class="stat-number">${statsData.stats.calls.total}</div>
                        <div class="stat-label">Total Calls</div>
                    </div>
                    <div class="stat-card">
                        <div class="stat-number">${statsData.stats.calls.incoming}</div>
                        <div class="stat-label">Incoming</div>
                    </div>
                    <div class="stat-card">
                        <div class="stat-number">${statsData.stats.calls.outgoing}</div>
                        <div class="stat-label">Outgoing</div>
                    </div>
                </div>

                <h3>User Contacts (${contactsData.contacts.length})</h3>
                <div style="max-height: 200px; overflow-y: auto; border: 1px solid #ddd; padding: 10px; margin: 10px 0;">
                    ${contactsData.contacts.length === 0 ? '<p>No contacts found</p>' :
                contactsData.contacts.map(contact =>
                    `<div style="padding: 5px; border-bottom: 1px solid #eee;">
                                <strong>${contact.name}</strong> - ${contact.phone_number}
                            </div>`
                ).join('')
            }
                </div>

                <h3>User Call Logs (${callsData.calls.length})</h3>
                <div style="max-height: 200px; overflow-y: auto; border: 1px solid #ddd; padding: 10px; margin: 10px 0;">
                    ${callsData.calls.length === 0 ? '<p>No calls found</p>' :
                callsData.calls.slice(0, 20).map(call =>
                    `<div style="padding: 5px; border-bottom: 1px solid #eee;">
                                <strong>${call.direction}</strong> - ${call.phone_number} - ${formatDuration(call.duration)} - ${formatDate(call.start_time)}
                            </div>`
                ).join('')
            }
                </div>

                <div class="user-actions" style="margin-top: 20px;">
                    <button class="btn btn-warning" onclick="confirmFlushUserData(${userId})">Flush All Data</button>
                    <button class="btn btn-danger" onclick="confirmDeleteUser(${userId})">Delete User</button>
                </div>
            </div>
        `;

        document.body.appendChild(modal);
        modal.style.display = 'block';

    } catch (error) {
        console.error('Error loading user data:', error);
        showError('Failed to load user data');
    }
}

// Delete user
async function deleteUser(userId) {
    if (!confirm('Are you sure you want to delete this user? This action cannot be undone.')) {
        return;
    }

    try {
        const response = await fetch(`/admin/users/${userId}`, {
            method: 'DELETE',
            headers: auth.getAuthHeaders()
        });

        if (response.ok) {
            showSuccess('User deleted successfully');
            loadUsers();
            loadDashboardData();
        } else {
            const error = await response.json();
            throw new Error(error.error || 'Failed to delete user');
        }
    } catch (error) {
        console.error('Error deleting user:', error);
        showError(error.message);
    }
}

// Delete contact
async function deleteContact(contactId) {
    if (!confirm('Are you sure you want to delete this contact?')) {
        return;
    }

    try {
        const response = await fetch(`/contacts/${contactId}`, {
            method: 'DELETE',
            headers: auth.getAuthHeaders()
        });

        if (response.ok) {
            showSuccess('Contact deleted successfully');
            loadContacts();
            loadDashboardData();
        } else {
            const error = await response.json();
            throw new Error(error.error || 'Failed to delete contact');
        }
    } catch (error) {
        console.error('Error deleting contact:', error);
        showError(error.message);
    }
}

// Delete call
async function deleteCall(callId) {
    if (!confirm('Are you sure you want to delete this call log?')) {
        return;
    }

    try {
        const response = await fetch(`/calls/${callId}`, {
            method: 'DELETE',
            headers: auth.getAuthHeaders()
        });

        if (response.ok) {
            showSuccess('Call log deleted successfully');
            loadCalls();
            loadDashboardData();
        } else {
            const error = await response.json();
            throw new Error(error.error || 'Failed to delete call');
        }
    } catch (error) {
        console.error('Error deleting call:', error);
        showError(error.message);
    }
}

// Flush user data (delete all contacts and calls for a user)
async function flushUserData(userId) {
    try {
        const response = await fetch(`/admin/users/${userId}/data`, {
            method: 'DELETE',
            headers: auth.getAuthHeaders()
        });

        if (response.ok) {
            showSuccess('User data flushed successfully');
            loadContacts();
            loadCalls();
            loadDashboardData();
            // Close modal if open
            const modal = document.querySelector('.modal');
            if (modal) modal.remove();
        } else {
            const error = await response.json();
            throw new Error(error.error || 'Failed to flush user data');
        }
    } catch (error) {
        console.error('Error flushing user data:', error);
        showError(error.message);
    }
}

// Confirm user data flush
function confirmFlushUserData(userId) {
    if (confirm('Are you sure you want to delete ALL data (contacts and calls) for this user? This action cannot be undone.')) {
        flushUserData(userId);
    }
}

// Confirm user deletion
function confirmDeleteUser(userId) {
    if (confirm('Are you sure you want to delete this user and all their data? This action cannot be undone.')) {
        deleteUser(userId);
        // Close modal if open
        const modal = document.querySelector('.modal');
        if (modal) modal.remove();
    }
}

// Create user modal functions
function openCreateUserModal() {
    document.getElementById('createUserModal').style.display = 'block';
}

function closeCreateUserModal() {
    document.getElementById('createUserModal').style.display = 'none';
    document.getElementById('createUserForm').reset();
}

// Handle create user form submission
async function handleCreateUser(e) {
    e.preventDefault();

    const formData = new FormData(e.target);
    const userData = {
        name: formData.get('name'),
        email: formData.get('email'),
        password: formData.get('password'),
        role: formData.get('role')
    };

    try {
        const response = await fetch('/admin/users', {
            method: 'POST',
            headers: auth.getAuthHeaders(),
            body: JSON.stringify(userData)
        });

        if (response.ok) {
            showSuccess('User created successfully');
            closeCreateUserModal();
            loadUsers();
            loadDashboardData();
        } else {
            const error = await response.json();
            throw new Error(error.error || 'Failed to create user');
        }
    } catch (error) {
        console.error('Error creating user:', error);
        showError(error.message);
    }
}

// Show tab content
function showTab(tabName) {
    // Hide all tab contents
    document.querySelectorAll('.tab-content').forEach(content => {
        content.classList.remove('active');
    });

    // Remove active class from all tabs
    document.querySelectorAll('.nav-tab').forEach(tab => {
        tab.classList.remove('active');
    });

    // Show selected tab
    document.getElementById(tabName).classList.add('active');
    document.querySelector(`[onclick="showTab('${tabName}')"]`).classList.add('active');

    // Load data if needed
    if (tabName === 'users' && allUsers.length === 0) {
        loadUsers();
    } else if (tabName === 'contacts' && allContacts.length === 0) {
        loadContacts();
    } else if (tabName === 'calls' && allCalls.length === 0) {
        loadCalls();
    }
}

// Utility functions
function formatDate(dateString) {
    if (!dateString) return 'N/A';
    return new Date(dateString).toLocaleString();
}

function formatDuration(seconds) {
    if (!seconds || seconds === 0) return '0s';
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return mins > 0 ? `${mins}m ${secs}s` : `${secs}s`;
}

function showError(message) {
    alert('Error: ' + message);
}

function showSuccess(message) {
    alert('Success: ' + message);
}
