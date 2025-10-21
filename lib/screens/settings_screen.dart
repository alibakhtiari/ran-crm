import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/auth_provider.dart';
import '../services/background_sync_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _backgroundSyncEnabled = true;
  bool _isLoading = false;
  int _syncIntervalHours = 1;

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
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
              'Automatically sync contacts and call logs in the background every hour',
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
                builder: (context) => AlertDialog(
                  title: const Text('Select Sync Interval'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RadioListTile<int>(
                        title: const Text('Every 15 minutes'),
                        subtitle: const Text('More frequent, uses more battery'),
                        value: 0, // Special value for 15 min
                        groupValue: _syncIntervalHours == 0 ? 0 : _syncIntervalHours,
                        onChanged: (value) => Navigator.pop(context, value),
                      ),
                      RadioListTile<int>(
                        title: const Text('Every 1 hour'),
                        subtitle: const Text('Recommended'),
                        value: 1,
                        groupValue: _syncIntervalHours,
                        onChanged: (value) => Navigator.pop(context, value),
                      ),
                      RadioListTile<int>(
                        title: const Text('Every 2 hours'),
                        value: 2,
                        groupValue: _syncIntervalHours,
                        onChanged: (value) => Navigator.pop(context, value),
                      ),
                      RadioListTile<int>(
                        title: const Text('Every 4 hours'),
                        value: 4,
                        groupValue: _syncIntervalHours,
                        onChanged: (value) => Navigator.pop(context, value),
                      ),
                      RadioListTile<int>(
                        title: const Text('Every 12 hours'),
                        value: 12,
                        groupValue: _syncIntervalHours,
                        onChanged: (value) => Navigator.pop(context, value),
                      ),
                      RadioListTile<int>(
                        title: const Text('Every 24 hours'),
                        subtitle: const Text('Least frequent, saves battery'),
                        value: 24,
                        groupValue: _syncIntervalHours,
                        onChanged: (value) => Navigator.pop(context, value),
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
                      final authProvider = context.read<AuthProvider>();
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

          // Info Section
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'About Background Sync',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  '• Syncs contacts from your phone to the server',
                  style: TextStyle(fontSize: 14),
                ),
                SizedBox(height: 4),
                Text(
                  '• Syncs contacts from the server to your phone',
                  style: TextStyle(fontSize: 14),
                ),
                SizedBox(height: 4),
                Text(
                  '• Syncs call logs from your phone to the server',
                  style: TextStyle(fontSize: 14),
                ),
                SizedBox(height: 4),
                Text(
                  '• Runs automatically every hour when enabled',
                  style: TextStyle(fontSize: 14),
                ),
                SizedBox(height: 4),
                Text(
                  '• Only syncs when connected to the internet',
                  style: TextStyle(fontSize: 14),
                ),
                SizedBox(height: 4),
                Text(
                  '• Works even when the app is closed',
                  style: TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),

          const Divider(),

          // Permissions Info
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Required Permissions',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  '• Contacts: To read and sync contacts',
                  style: TextStyle(fontSize: 14),
                ),
                SizedBox(height: 4),
                Text(
                  '• Phone: To read call logs',
                  style: TextStyle(fontSize: 14),
                ),
                SizedBox(height: 4),
                Text(
                  '• Internet: To communicate with the server',
                  style: TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
