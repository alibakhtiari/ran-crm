import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/auth_provider.dart';
import '../services/background_sync_service.dart';

class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> with AutomaticKeepAliveClientMixin {
  bool _backgroundSyncEnabled = true;
  bool _isLoading = false;
  int _syncIntervalHours = 1;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _backgroundSyncEnabled = prefs.getBool('background_sync_enabled') ?? true;
        _syncIntervalHours = prefs.getInt('sync_interval_hours') ?? 1;
      });
    } catch (e) {
      if (kDebugMode) {
        print('Failed to load settings: $e');
      }
    }
  }

  Future<void> _saveSyncInterval(int hours) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('sync_interval_hours', hours);
      setState(() {
        _syncIntervalHours = hours;
      });
    } catch (e) {
      if (kDebugMode) {
        print('Failed to save sync interval: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        final isAdmin = authProvider.isAdmin;
        final user = authProvider.user;

        return ListView(
          children: [
            // User Info Section
            if (user != null) ...[
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Account',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ),
              ListTile(
                leading: CircleAvatar(
                  child: Text(user.email[0].toUpperCase()),
                ),
                title: Text(user.email),
                subtitle: Text(
                  isAdmin ? 'Administrator' : 'User',
                  style: TextStyle(
                    color: isAdmin ? Colors.orange : Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.exit_to_app, color: Colors.red),
                  tooltip: 'Logout',
                  onPressed: () async {
                    final navigator = Navigator.of(context, rootNavigator: true);
                    await context.read<AuthProvider>().logout();
                    if (navigator.mounted) {
                      navigator.pushReplacementNamed('/login');
                    }
                  },
                ),
              ),
              const Divider(),
            ],

            // Sync Settings Section
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Sync Settings',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ),

            // Background Sync Toggle
            SwitchListTile(
              title: const Text('Background Sync'),
              subtitle: const Text(
                'Automatically sync contacts and call logs in the background',
              ),
              value: _backgroundSyncEnabled,
              onChanged: _isLoading
                  ? null
                  : (value) async {
                      setState(() => _isLoading = true);

                      try {
                        if (value) {
                          await BackgroundSyncService.registerPeriodicSync();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Background sync enabled'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } else {
                          await BackgroundSyncService.unregisterPeriodicSync();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Background sync disabled'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                          }
                        }
                        setState(() => _backgroundSyncEnabled = value);
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed to update sync settings: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      } finally {
                        if (mounted) {
                          setState(() => _isLoading = false);
                        }
                      }
                    },
            ),

            const Divider(),

            // Sync Interval Selector
            ListTile(
              leading: const Icon(Icons.schedule, color: Colors.blue),
              title: const Text('Sync Interval'),
              subtitle: Text('Current: Every $_syncIntervalHours hour${_syncIntervalHours > 1 ? 's' : ''}'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () async {
                final selected = await showDialog<int>(
                  context: context,
                  builder: (context) => StatefulBuilder(
                    builder: (context, setState) => AlertDialog(
                      title: const Text('Select Sync Interval'),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          RadioMenuButton<int>(
                            value: 0,
                            groupValue: _syncIntervalHours == 0 ? 0 : _syncIntervalHours,
                            onChanged: (value) => Navigator.pop(context, value),
                            child: const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Every 15 minutes'),
                                Text('More frequent, uses more battery', style: TextStyle(fontSize: 12)),
                              ],
                            ),
                          ),
                          RadioMenuButton<int>(
                            value: 1,
                            groupValue: _syncIntervalHours,
                            onChanged: (value) => Navigator.pop(context, value),
                            child: const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Every 1 hour'),
                                Text('Recommended', style: TextStyle(fontSize: 12)),
                              ],
                            ),
                          ),
                          RadioMenuButton<int>(
                            value: 2,
                            groupValue: _syncIntervalHours,
                            onChanged: (value) => Navigator.pop(context, value),
                            child: const Text('Every 2 hours'),
                          ),
                          RadioMenuButton<int>(
                            value: 4,
                            groupValue: _syncIntervalHours,
                            onChanged: (value) => Navigator.pop(context, value),
                            child: const Text('Every 4 hours'),
                          ),
                          RadioMenuButton<int>(
                            value: 12,
                            groupValue: _syncIntervalHours,
                            onChanged: (value) => Navigator.pop(context, value),
                            child: const Text('Every 12 hours'),
                          ),
                          RadioMenuButton<int>(
                            value: 24,
                            groupValue: _syncIntervalHours,
                            onChanged: (value) => Navigator.pop(context, value),
                            child: const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Every 24 hours'),
                                Text('Least frequent, saves battery', style: TextStyle(fontSize: 12)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                      ],
                    ),
                  ),
                );

                if (selected != null && mounted) {
                  await _saveSyncInterval(selected);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          selected == 0
                              ? 'Sync interval set to 15 minutes'
                              : 'Sync interval set to $selected hour${selected > 1 ? 's' : ''}',
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                }
              },
            ),

            const Divider(),

            // Manual Sync Button
            ListTile(
              leading: const Icon(Icons.sync, color: Colors.blue),
              title: const Text('Sync Now'),
              subtitle: const Text('Manually trigger immediate sync'),
              trailing: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: _isLoading
                  ? null
                  : () async {
                      setState(() => _isLoading = true);

                      try {
                        final success = await authProvider.triggerSync();

                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                success
                                    ? 'Sync initiated successfully'
                                    : 'Failed to initiate sync',
                              ),
                              backgroundColor: success ? Colors.green : Colors.red,
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Sync failed: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      } finally {
                        if (mounted) {
                          setState(() => _isLoading = false);
                        }
                      }
                    },
            ),

            const Divider(),

            // Admin Section
            if (isAdmin) ...[
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Admin',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.admin_panel_settings, color: Colors.orange),
                title: const Text('Admin Panel'),
                subtitle: const Text('Manage users and system settings'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.pushNamed(context, '/admin');
                },
              ),
              const Divider(),
            ],


          ],
        );
      },
    );
  }
}
