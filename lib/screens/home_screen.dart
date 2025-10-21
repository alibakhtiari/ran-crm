import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/contact_provider.dart';
import '../models/contact.dart';
import 'contacts_tab.dart';
import 'call_logs_tab.dart';
import 'settings_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _currentIndex = _tabController.index;
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        final isAdmin = authProvider.isAdmin;

        return Scaffold(
          appBar: AppBar(
            title: const Text('RAN CRM'),
            bottom: TabBar(
              controller: _tabController,
              tabs: [
                const Tab(
                  icon: Icon(Icons.contacts),
                  text: 'Contacts',
                ),
                const Tab(
                  icon: Icon(Icons.phone),
                  text: 'Call Logs',
                ),
                Tab(
                  icon: Icon(isAdmin ? Icons.admin_panel_settings : Icons.settings),
                  text: isAdmin ? 'Admin' : 'Settings',
                ),
              ],
            ),
            actions: [
              PopupMenuButton(
                itemBuilder: (context) => [
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
                  if (value == 'logout') {
                    await context.read<AuthProvider>().logout();
                    if (!mounted) return;
                    Navigator.of(context).pushReplacementNamed('/login');
                  }
                },
              ),
            ],
          ),
          body: TabBarView(
            controller: _tabController,
            children: const [
              ContactsTab(),
              CallLogsTab(),
              SettingsTab(),
            ],
          ),
          floatingActionButton: _currentIndex == 0
              ? FloatingActionButton(
                  onPressed: () => _showAddContactDialog(context),
                  child: const Icon(Icons.add),
                )
              : null,
        );
      },
    );
  }

  Future<void> _showAddContactDialog(BuildContext context) async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
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
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty &&
                  phoneController.text.isNotEmpty) {
                final authProvider = context.read<AuthProvider>();
                final user = authProvider.user;

                if (user == null) {
                  Navigator.pop(dialogContext, false);
                  return;
                }

                final contact = Contact(
                  name: nameController.text,
                  phoneNumber: phoneController.text,
                  createdByUserId: user.id,
                  createdAt: DateTime.now(),
                );
                if (!context.mounted) return;
                final success =
                    await context.read<ContactProvider>().addContact(contact);
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext, success);
                }
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contact added successfully')),
      );
    }
  }
}
