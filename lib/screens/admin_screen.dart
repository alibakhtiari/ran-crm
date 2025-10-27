import 'package:flutter/material.dart';
import '../api/api_client.dart';
import '../models/user.dart';
import '../models/contact.dart';
import '../models/call.dart';


class UserStats {
  final int contactCount;
  final int callCount;

  UserStats({
    required this.contactCount,
    required this.callCount,
  });

  factory UserStats.fromJson(Map<String, dynamic> json) {
    final stats = json['stats'] as Map<String, dynamic>;
    return UserStats(
      contactCount: stats['contacts'] as int,
      callCount: stats['calls'] as int,
    );
  }
}

class UserDataDialog extends StatefulWidget {
  final ApiClient apiClient;
  final User user;
  final Function()? onDataFlushed;

  const UserDataDialog({
    super.key,
    required this.apiClient,
    required this.user,
    this.onDataFlushed,
  });

  @override
  State<UserDataDialog> createState() => _UserDataDialogState();
}

class _UserDataDialogState extends State<UserDataDialog> {
  List<Contact> _contacts = [];
  List<Call> _calls = [];
  bool _isLoadingContacts = true;
  bool _isLoadingCalls = true;
  String? _contactsError;
  String? _callsError;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    // Load contacts
    try {
      final contactsResponse = await widget.apiClient.getUserContacts(widget.user.id);
      final contactsData = contactsResponse['contacts'] as List<dynamic>;
      setState(() {
        _contacts = contactsData.map((json) => Contact.fromJson(json)).toList();
        _isLoadingContacts = false;
      });
    } catch (e) {
      setState(() {
        _contactsError = e.toString();
        _isLoadingContacts = false;
      });
    }

    // Load calls
    try {
      final callsResponse = await widget.apiClient.getUserCallLogs(widget.user.id);
      final callsData = callsResponse['calls'] as List<dynamic>;
      setState(() {
        _calls = callsData.map((json) => Call.fromJson(json)).toList();
        _isLoadingCalls = false;
      });
    } catch (e) {
      setState(() {
        _callsError = e.toString();
        _isLoadingCalls = false;
      });
    }
  }

  Future<void> _flushContacts() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Flush Contacts'),
        content: Text(
          'Are you sure you want to permanently delete all ${widget.user.email}\'s contacts? '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete Contacts'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // Call API to flush contacts - we'll implement this-selective endpoint
        await widget.apiClient.flushContactsOnly(widget.user.id);
        if (mounted) {
          await _loadUserData(); // Reload data
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Contacts flushed successfully')),
          );
        }
        widget.onDataFlushed?.call();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _flushCalls() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Flush Call Logs'),
        content: Text(
          'Are you sure you want to permanently delete all ${widget.user.email}\'s call logs? '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete Calls'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // Call API to flush calls only
        await widget.apiClient.flushCallsOnly(widget.user.id);
        if (mounted) {
          await _loadUserData(); // Reload data
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Call logs flushed successfully')),
          );
        }
        widget.onDataFlushed?.call();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _flushAllData() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Flush All Data'),
        content: Text(
          'Are you sure you want to permanently delete all contacts and call logs for ${widget.user.email}? '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Flush All Data'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await widget.apiClient.flushUserData(widget.user.id);
        if (mounted) {
          await _loadUserData(); // Reload data
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('All data flushed successfully')),
          );
        }
        widget.onDataFlushed?.call();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(16),
        child: DefaultTabController(
          length: 2,
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: widget.user.isAdmin ? Colors.orange : Colors.blue,
                    child: Icon(
                      widget.user.isAdmin ? Icons.admin_panel_settings : Icons.person,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.user.email,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Role: ${widget.user.role}',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (value) {
                      switch (value) {
                        case 'flush_contacts':
                          _flushContacts();
                          break;
                        case 'flush_calls':
                          _flushCalls();
                          break;
                        case 'flush_all':
                          _flushAllData();
                          break;
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'flush_contacts',
                        child: ListTile(
                          leading: Icon(Icons.contacts, color: Colors.red),
                          title: Text('Flush Contacts'),
                          subtitle: Text('Dynamic count'),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'flush_calls',
                        child: ListTile(
                          leading: Icon(Icons.call, color: Colors.red),
                          title: Text('Flush Call Logs'),
                          subtitle: Text('Dynamic count'),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'flush_all',
                        child: ListTile(
                          leading: Icon(Icons.delete_forever, color: Colors.red),
                          title: Text('Flush All Data'),
                          subtitle: Text('Contacts + Call Logs'),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const TabBar(
                tabs: [
                  Tab(text: 'Contacts'),
                  Tab(text: 'Call Logs'),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: TabBarView(
                  children: [
                    // Contacts Tab
                    _isLoadingContacts
                        ? const Center(child: CircularProgressIndicator())
                        : _contactsError != null
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text('Error loading contacts: $_contactsError'),
                                    const SizedBox(height: 8),
                                    ElevatedButton(
                                      onPressed: _loadUserData,
                                      child: const Text('Retry'),
                                    ),
                                  ],
                                ),
                              )
                            : _contacts.isEmpty
                                ? const Center(child: Text('No contacts found'))
                                : ListView(
                                    children: _contacts.map((contact) => ListTile(
                                      leading: const CircleAvatar(
                                        child: Icon(Icons.person),
                                      ),
                                      title: Text(contact.name),
                                      subtitle: Text(contact.phoneNumber),
                                    )).toList(),
                                  ),

                    // Calls Tab
                    _isLoadingCalls
                        ? const Center(child: CircularProgressIndicator())
                        : _callsError != null
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text('Error loading calls: $_callsError'),
                                    const SizedBox(height: 8),
                                    ElevatedButton(
                                      onPressed: _loadUserData,
                                      child: const Text('Retry'),
                                    ),
                                  ],
                                ),
                              )
                            : _calls.isEmpty
                                ? const Center(child: Text('No call logs found'))
                                : ListView.builder(
                                    itemCount: _calls.length,
                                    itemBuilder: (context, index) {
                                      final call = _calls[index];
                                      return ListTile(
                                        leading: CircleAvatar(
                                          backgroundColor: call.direction == 'incoming'
                                              ? Colors.green
                                              : Colors.blue,
                                          child: Icon(
                                            call.direction == 'incoming'
                                                ? Icons.call_received
                                                : Icons.call_made,
                                            color: Colors.white,
                                          ),
                                        ),
                                        title: Text(call.phoneNumber),
                                        subtitle: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${call.direction} • ${call.duration}s',
                                            ),
                                            Text(
                                              call.startTime.toString(),
                                              style: const TextStyle(fontSize: 12),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  late final ApiClient _apiClient;
  List<User> _users = [];
  Map<int, UserStats> _userStats = {};
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _apiClient = ApiClient();
    _fetchUsers();
  }

  String? _validateEmailOrUsername(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      return null; // Allow empty for now, validation happens on submit
    }

    // Simple email regex
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    if (emailRegex.hasMatch(trimmed)) {
      return null; // Valid email
    }

    // If it contains only alphanumeric characters and underscores, treat as username
    final usernameRegex = RegExp(r'^[a-zA-Z0-9_-]+$');
    if (usernameRegex.hasMatch(trimmed)) {
      return null; // Valid username
    }

    // If it doesn't match either pattern, show error
    return 'Enter a valid email address or username';
  }

  Future<void> _fetchUsers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final users = await _apiClient.getUsers();

      // Fetch stats for each user (only for display)
      final stats = <int, UserStats>{};
      for (final user in users) {
        try {
          final userStatsResponse = await _apiClient.getUserStats(user.id);
          stats[user.id] = UserStats.fromJson(userStatsResponse);
        } catch (e) {
          // If stats fail to load, use zero counts
          stats[user.id] = UserStats(contactCount: 0, callCount: 0);
        }
      }

      setState(() {
        _users = users;
        _userStats = stats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _showAddUserDialog() async {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    String selectedRole = 'user';
    String? emailError;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add User'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailController,
                decoration: InputDecoration(
                  labelText: 'Email or Username',
                  border: const OutlineInputBorder(),
                  errorText: emailError,
                ),
                onChanged: (value) {
                  setDialogState(() {
                    emailError = _validateEmailOrUsername(value);
                  });
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: selectedRole,
                decoration: const InputDecoration(
                  labelText: 'Role',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'user', child: Text('User')),
                  DropdownMenuItem(value: 'admin', child: Text('Admin')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() {
                      selectedRole = value;
                    });
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final emailValue = emailController.text.trim();
                final passwordValue = passwordController.text;
                final currentEmailError = _validateEmailOrUsername(emailValue);

                setDialogState(() {
                  emailError = currentEmailError;
                });

                if (currentEmailError != null) {
                  return; // Don't proceed if validation fails
                }

                if (emailValue.isNotEmpty && passwordValue.isNotEmpty) {
                  try {
                    await _apiClient.createUser(
                      emailValue,
                      passwordValue,
                      selectedRole,
                    );
                    if (context.mounted) {
                      Navigator.pop(context, true);
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      _fetchUsers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User added successfully')),
        );
      }
    }
  }

  Future<void> _deleteUser(User user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: Text('Are you sure you want to delete ${user.email}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _apiClient.deleteUser(user.id);
        _fetchUsers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _showUserData(User user) async {
    showDialog(
      context: context,
      builder: (context) => UserDataDialog(
        apiClient: _apiClient,
        user: user,
        onDataFlushed: () => _fetchUsers(), // Refresh stats when data is flushed
      ),
    );
  }



  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Error: $_errorMessage',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _fetchUsers,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_users.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Admin Panel'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _fetchUsers,
            ),
          ],
        ),
        body: const Center(child: Text('No users found')),
        floatingActionButton: FloatingActionButton(
          onPressed: _showAddUserDialog,
          child: const Icon(Icons.person_add),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchUsers,
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: _users.length,
        itemBuilder: (context, index) {
          final user = _users[index];
          final stats = _userStats[user.id] ?? UserStats(contactCount: 0, callCount: 0);

          return Card(
            margin: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User Header Row
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.email,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Role: ${user.role}',
                              style: TextStyle(
                                fontSize: 14,
                                color: user.isAdmin ? Colors.orange : Colors.blue,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Stats Column
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.contacts,
                                size: 16,
                                color: Colors.grey,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${stats.contactCount}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.call,
                                size: 16,
                                color: Colors.grey,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${stats.callCount}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1),

                  // Action Buttons Row
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _showUserData(user),
                          icon: const Icon(Icons.visibility, size: 18),
                          label: const Text('View Data'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Delete User button - disabled/grayed for admin users
                      Expanded(
                        child: Opacity(
                          opacity: user.isAdmin ? 0.5 : 1.0,
                          child: ElevatedButton.icon(
                            onPressed: user.isAdmin ? null : () => _deleteUser(user),
                            icon: const Icon(Icons.delete, size: 18),
                            label: const Text('Delete User'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: user.isAdmin ? Colors.grey : Colors.red,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddUserDialog,
        child: const Icon(Icons.person_add),
      ),
    );
  }
}
