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

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final PageController _pageController = PageController();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }



  void _onItemTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        final isAdmin = authProvider.isAdmin;

        return Scaffold(
          body: Column(
            children: [
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() {
                      _currentIndex = index;
                    });
                  },
                  children: [
                    ContactsTab(searchQuery: _searchQuery),
                    const CallLogsTab(),
                    const SettingsTab(),
                  ],
                ),
              ),
              // Search bar positioned above bottom navigation - hidden on admin/settings tab
              if (_currentIndex != 2) // Hide on admin/settings tab
                Container(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.add),
                        tooltip: 'Add Contact',
                        onPressed: _currentIndex == 0 ? () => _showAddContactDialog(context) : null,
                      ),
                      Expanded(
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
                            setState(() {
                              _searchQuery = value.toLowerCase();
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.exit_to_app),
                        tooltip: 'Logout',
                        onPressed: () async {
                          final authProvider = context.read<AuthProvider>();
                          final navigator = Navigator.of(context, rootNavigator: true);
                          await authProvider.logout();
                          if (mounted) {
                            navigator.pushReplacementNamed('/login');
                          }
                        },
                      ),
                    ],
                  ),
                ),
              // Bottom Navigation Bar
              BottomNavigationBar(
                currentIndex: _currentIndex,
                onTap: _onItemTapped,
                items: [
                  const BottomNavigationBarItem(
                    icon: Icon(Icons.contacts),
                    label: 'Contacts',
                  ),
                  const BottomNavigationBarItem(
                    icon: Icon(Icons.phone),
                    label: 'Call Logs',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(isAdmin ? Icons.admin_panel_settings : Icons.settings),
                    label: isAdmin ? 'Admin' : 'Settings',
                  ),
                ],
              ),
            ],
          ),
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
