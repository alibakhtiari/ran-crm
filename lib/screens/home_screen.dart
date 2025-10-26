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

  Future<void> _handleLogout(BuildContext context) async {
    final authProvider = context.read<AuthProvider>();
    await authProvider.logout();
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pushReplacementNamed('/login');
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
                    await _handleLogout(context);
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
    final authProvider = context.read<AuthProvider>();
    final contactProvider = context.read<ContactProvider>();

    final result = await showDialog<Contact?>(
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
            onPressed: () => Navigator.pop(dialogContext, null),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty &&
                  phoneController.text.isNotEmpty) {
                final user = authProvider.user;

                if (user == null) {
                  Navigator.pop(dialogContext, null);
                  return;
                }

                final contact = Contact(
                  name: nameController.text,
                  phoneNumber: phoneController.text,
                  createdByUserId: user.id,
                  createdAt: DateTime.now(),
                );
                Navigator.pop(dialogContext, contact);
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
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Contact added successfully')),
          );
        });
      }
    }
  }
}
