import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/auth_provider.dart';
import '../providers/contact_provider.dart';
import '../models/contact.dart';
import '../services/contact_sync_service.dart' as contact_service;
import '../services/call_log_sync_service.dart' as call_log_service;
import '../services/background_sync_service.dart';

class ContactsTab extends StatefulWidget {
  const ContactsTab({super.key});

  @override
  State<ContactsTab> createState() => _ContactsTabState();
}

class _ContactsTabState extends State<ContactsTab> with AutomaticKeepAliveClientMixin {
  final contact_service.ContactSyncService _contactSync = contact_service.ContactSyncService();
  final call_log_service.CallLogSyncService _callLogSync = call_log_service.CallLogSyncService();
  bool _isSyncing = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Data is already loaded from cache via ContactProvider constructor
      // Fetch fresh data in background
      context.read<ContactProvider>().fetchContacts(showLoading: false);
      _requestPermissions();
      _checkAndAutoSync();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    await _contactSync.requestPermissions();
    await _callLogSync.requestPermissions();
  }

  Future<void> _checkAndAutoSync() async {
    try {
      await BackgroundSyncService.checkAndSync();
      if (mounted) {
        final contactProvider = context.read<ContactProvider>();
        await contactProvider.fetchContacts(showLoading: false);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Auto-sync failed: $e');
      }
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('User not authenticated'),
              backgroundColor: Colors.red,
            ),
          );
        }
        setState(() => _isSyncing = false);
        return;
      }

      final userId = user.id;

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

      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      if (mounted) {
        try {
          await contactProvider.fetchContacts();
        } catch (e) {
          if (kDebugMode) {
            print('Failed to refresh contacts: $e');
          }
        }
      }

      if (mounted) {
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
      }
    } catch (e) {
      if (kDebugMode) {
        print('Sync failed with error: $e');
      }
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot make phone call')),
        );
      }
    }
  }

  Future<void> _sendSMS(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'sms',
      path: phoneNumber,
    );
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot send SMS')),
        );
      }
    }
  }

  Future<void> _showEditContactDialog(Contact contact) async {
    final nameController = TextEditingController(text: contact.name);
    final phoneController = TextEditingController(text: contact.phoneNumber);
    final contactProvider = context.read<ContactProvider>();

    final result = await showDialog<Contact?>(
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
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty &&
                  phoneController.text.isNotEmpty) {
                final updatedContact = contact.copyWith(
                  name: nameController.text,
                  phoneNumber: phoneController.text,
                  updatedAt: DateTime.now(),
                );
                Navigator.pop(context, updatedContact);
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );

    if (result != null) {
      final success = await contactProvider.updateContact(contact.id!, result);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contact updated successfully')),
        );
      }
    }
  }

  Future<void> _deleteContact(Contact contact) async {
    final contactProvider = context.read<ContactProvider>();
    final ctx = context;

    final confirm = await showDialog<bool>(
      context: ctx,
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
      if (!mounted) return;
      final success = await contactProvider.deleteContact(contact.id!);
      if (success) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ScaffoldMessenger.of(ctx).showSnackBar(
            const SnackBar(content: Text('Contact deleted successfully')),
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search contacts...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            onChanged: (value) {
              setState(() => _searchQuery = value.toLowerCase());
            },
          ),
        ),

        // Sync button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isSyncing ? null : _syncAll,
                  icon: _isSyncing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync),
                  label: Text(_isSyncing ? 'Syncing...' : 'Sync Phone Data'),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // Contact list
        Expanded(
          child: Consumer<ContactProvider>(
            builder: (context, contactProvider, _) {
              if (contactProvider.isLoading && contactProvider.contacts.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }

              if (contactProvider.errorMessage != null && contactProvider.contacts.isEmpty) {
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

              // Filter contacts based on search
              final filteredContacts = _searchQuery.isEmpty
                  ? contactProvider.contacts
                  : contactProvider.contacts.where((contact) {
                      return contact.name.toLowerCase().contains(_searchQuery) ||
                          contact.phoneNumber.contains(_searchQuery);
                    }).toList();

              if (filteredContacts.isEmpty) {
                return Center(
                  child: Text(
                    _searchQuery.isEmpty
                        ? 'No contacts yet. Add one to get started!'
                        : 'No contacts found matching "$_searchQuery"',
                  ),
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
                      itemCount: filteredContacts.length,
                      itemBuilder: (context, index) {
                        final contact = filteredContacts[index];
                        final canEdit = contactProvider.canEditContact(
                          contact,
                          user.id,
                          authProvider.isAdmin,
                        );

                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              child: Text(
                                contact.name.isNotEmpty
                                    ? contact.name[0].toUpperCase()
                                    : '?',
                              ),
                            ),
                            title: Text(
                              contact.name,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(contact.phoneNumber),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Call button
                                IconButton(
                                  icon: const Icon(Icons.phone, color: Colors.green),
                                  tooltip: 'Call',
                                  onPressed: () => _makePhoneCall(contact.phoneNumber),
                                ),
                                // SMS button
                                IconButton(
                                  icon: const Icon(Icons.message, color: Colors.blue),
                                  tooltip: 'Text',
                                  onPressed: () => _sendSMS(contact.phoneNumber),
                                ),
                                // Edit button
                                if (canEdit)
                                  PopupMenuButton(
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(
                                        value: 'edit',
                                        child: Row(
                                          children: [
                                            Icon(Icons.edit),
                                            SizedBox(width: 8),
                                            Text('Edit'),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            Icon(Icons.delete, color: Colors.red),
                                            SizedBox(width: 8),
                                            Text('Delete'),
                                          ],
                                        ),
                                      ),
                                    ],
                                    onSelected: (value) {
                                      if (value == 'edit') {
                                        _showEditContactDialog(contact);
                                      } else if (value == 'delete') {
                                        _deleteContact(contact);
                                      }
                                    },
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
