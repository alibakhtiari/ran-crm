import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/contact_provider.dart';
import '../models/contact.dart';
import '../widgets/contact_tile.dart';
import '../services/contact_sync_service.dart' as contact_service;
import '../services/call_log_sync_service.dart' as call_log_service;
import '../services/background_sync_service.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final contact_service.ContactSyncService _contactSync = contact_service.ContactSyncService();
  final call_log_service.CallLogSyncService _callLogSync = call_log_service.CallLogSyncService();
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ContactProvider>().fetchContacts();
      _requestPermissions();
      _checkAndAutoSync(); // Auto-sync if needed
    });
  }

  Future<void> _requestPermissions() async {
    await _contactSync.requestPermissions();
    await _callLogSync.requestPermissions();
  }

  /// Check if auto-sync is needed and perform it silently
  Future<void> _checkAndAutoSync() async {
    try {
      await BackgroundSyncService.checkAndSync();
      // Refresh contacts after auto-sync
      if (mounted) {
        final contactProvider = context.read<ContactProvider>();
        unawaited(contactProvider.fetchContacts());
      }
    } catch (e) {
      if (kDebugMode) {
        print('Auto-sync failed: $e');
      }
      // Silent failure - don't show error to user
    }
  }

  Future<void> _syncAll() async {
    if (_isSyncing) return;

    setState(() => _isSyncing = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final contactProvider = context.read<ContactProvider>();
      final user = authProvider.user;

      if (user == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('User not authenticated'),
              backgroundColor: Colors.red,
            ),
          );
        });
        if (mounted) setState(() => _isSyncing = false);
        return;
      }

      final userId = user.id;

      // Show progress dialog
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Syncing contacts and call logs...'),
              ],
            ),
          ),
        );
      }

      // Sync contacts
      contact_service.SyncResult contactResult;
      try {
        contactResult = await _contactSync.syncContactsToServer(userId);
      } catch (e) {
        if (kDebugMode) {
          print('Contact sync error: $e');
        }
        contactResult = contact_service.SyncResult(
          total: 0,
          synced: 0,
          skipped: 0,
          errors: ['Contact sync failed: $e'],
        );
      }

      // Sync call logs
      call_log_service.SyncResult callLogResult;
      try {
        callLogResult = await _callLogSync.syncCallLogsToServer(userId);
      } catch (e) {
        if (kDebugMode) {
          print('Call log sync error: $e');
        }
        callLogResult = call_log_service.SyncResult(
          total: 0,
          synced: 0,
          skipped: 0,
          errors: ['Call log sync failed: $e'],
        );
      }

      // Close progress dialog
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      // Refresh contact list
      if (mounted) {
        try {
          await contactProvider.fetchContacts();
        } catch (e) {
          if (kDebugMode) {
            print('Failed to refresh contacts: $e');
          }
        }
      }

      // Show result
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Sync Complete'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('✅ Contacts: ${contactResult.summary}'),
                const SizedBox(height: 8),
                Text('📞 Call Logs: ${callLogResult.summary}'),
                if (contactResult.hasErrors || callLogResult.hasErrors) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Some items had errors during sync.',
                    style: TextStyle(color: Colors.orange, fontSize: 12),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      });
    } catch (e) {
      if (kDebugMode) {
        print('Sync failed with error: $e');
      }
      // Close progress dialog if open
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      // Show error
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      });
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  Future<void> _showAddContactDialog() async {
    final ctx = context;
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final authProvider = ctx.read<AuthProvider>();
    final contactProvider = ctx.read<ContactProvider>();

    final result = await showDialog<Contact?>(
      context: ctx,
      builder: (context) => AlertDialog(
        title: const Text('Add Contact'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty &&
                  phoneController.text.isNotEmpty) {
                final user = authProvider.user;

                if (user == null) {
                  Navigator.pop(context, null);
                  return;
                }

                final contact = Contact(
                  name: nameController.text,
                  phoneNumber: phoneController.text,
                  createdByUserId: user.id,
                  createdAt: DateTime.now(),
                );

                Navigator.pop(context, contact);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result != null) {
      final success = await contactProvider.addContact(result);
      if (success) {
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(content: Text('Contact added successfully')),
              );
            }
          });
        }
      }
    }
  }

  Future<void> _showEditContactDialog(Contact contact) async {
    final nameController = TextEditingController(text: contact.name);
    final phoneController = TextEditingController(text: contact.phoneNumber);
    final contactProvider = context.read<ContactProvider>();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Contact'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                border: OutlineInputBorder(),
              ),
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
              if (nameController.text.isNotEmpty &&
                  phoneController.text.isNotEmpty) {
                final updatedContact = contact.copyWith(
                  name: nameController.text,
                  phoneNumber: phoneController.text,
                  updatedAt: DateTime.now(),
                );

                final success = await contactProvider
                    .updateContact(contact.id!, updatedContact);
                if (context.mounted) {
                  Navigator.pop(context, success);
                }
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );

    if (result == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contact updated successfully')),
        );
      });
    }
  }

  Future<void> _deleteContact(Contact contact) async {
    final contactProvider = context.read<ContactProvider>();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Contact'),
        content: Text('Are you sure you want to delete ${contact.name}?'),
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
      final success = await contactProvider.deleteContact(contact.id!);
      if (success) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Contact deleted successfully')),
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contacts'),
        actions: [
          Consumer<AuthProvider>(
            builder: (context, authProvider, _) {
              if (authProvider.isAdmin) {
                return IconButton(
                  icon: const Icon(Icons.admin_panel_settings),
                  tooltip: 'Admin Panel',
                  onPressed: () {
                    Navigator.pushNamed(context, '/admin');
                  },
                );
              }
              return const SizedBox.shrink();
            },
          ),
          IconButton(
            icon: const Icon(Icons.phone),
            tooltip: 'Call Logs',
            onPressed: () {
              Navigator.pushNamed(context, '/calls');
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.pushNamed(context, '/settings');
            },
          ),
          PopupMenuButton(
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'sync',
                child: Row(
                  children: [
                    Icon(Icons.sync),
                    SizedBox(width: 8),
                    Text('Sync Phone Data'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout),
                    SizedBox(width: 8),
                    Text('Logout'),
                  ],
                ),
              ),
            ],
            onSelected: (value) async {
              if (value == 'sync') {
                await _syncAll();
              } else if (value == 'logout') {
                final authProvider = context.read<AuthProvider>();
                await authProvider.logout();
                Future.microtask(() {
                  if (mounted) {
                    Navigator.of(context).pushReplacementNamed('/login');
                  }
                });
              }
            },
          ),
        ],
      ),
      body: Consumer<ContactProvider>(
        builder: (context, contactProvider, _) {
          if (contactProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (contactProvider.errorMessage != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Error: ${contactProvider.errorMessage}',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => contactProvider.fetchContacts(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (contactProvider.contacts.isEmpty) {
            return const Center(
              child: Text('No contacts yet. Add one to get started!'),
            );
          }

          return RefreshIndicator(
            onRefresh: () => contactProvider.fetchContacts(),
            child: Consumer<AuthProvider>(
              builder: (context, authProvider, _) {
                final user = authProvider.user;
                if (user == null) {
                  return const Center(
                    child: Text('User not authenticated'),
                  );
                }

                return ListView.builder(
                  itemCount: contactProvider.contacts.length,
                  itemBuilder: (context, index) {
                    final contact = contactProvider.contacts[index];
                    final canEdit = contactProvider.canEditContact(
                      contact,
                      user.id,
                      authProvider.isAdmin,
                    );

                    return ContactTile(
                      contact: contact,
                      canEdit: canEdit,
                      onEdit: () => _showEditContactDialog(contact),
                      onDelete: () => _deleteContact(contact),
                    );
                  },
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddContactDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
