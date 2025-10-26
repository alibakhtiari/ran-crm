import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/auth_provider.dart';
import '../providers/contact_provider.dart';
import '../models/contact.dart';
import '../services/background_sync_service.dart';

class ContactsTab extends StatefulWidget {
  final String searchQuery;

  const ContactsTab({super.key, required this.searchQuery});

  @override
  State<ContactsTab> createState() => _ContactsTabState();
}

class _ContactsTabState extends State<ContactsTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Data is already loaded from cache via ContactProvider constructor
      // Fetch fresh data in background
      context.read<ContactProvider>().fetchContacts(showLoading: false);
      _checkAndAutoSync();
    });
  }

  @override
  void dispose() {
    super.dispose();
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

    // Contact list
    return Consumer<ContactProvider>(
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
        final filteredContacts = widget.searchQuery.isEmpty
            ? contactProvider.contacts
            : contactProvider.contacts.where((contact) {
                return contact.name.toLowerCase().contains(widget.searchQuery) ||
                    contact.phoneNumber.contains(widget.searchQuery);
              }).toList();

        if (filteredContacts.isEmpty) {
          return Center(
            child: Text(
              widget.searchQuery.isEmpty
                  ? 'No contacts yet. Add one to get started!'
                  : 'No contacts found matching "${widget.searchQuery}"',
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
    );
  }
}
