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
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Background sync enabled'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } else {
                        await BackgroundSyncService.unregisterPeriodicSync();
                        if (context.mounted) {
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
                      if (context.mounted) {
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
              int tempSelected = _syncIntervalHours;
              final selected = await showDialog<int>(
                context: context,
                builder: (context) => StatefulBuilder(
                  builder: (context, setState) => AlertDialog(
                    title: const Text('Select Sync Interval'),
                    content: Wrap(
                      spacing: 8.0,
                      runSpacing: 8.0,
                      children: [
                        ChoiceChip(
                          label: const Text('Every 15 minutes'),
                          selected: tempSelected == 0,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => tempSelected = 0);
                            }
                          },
                        ),
                        ChoiceChip(
                          label: const Text('Every 1 hour'),
                          selected: tempSelected == 1,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => tempSelected = 1);
                            }
                          },
                        ),
                        ChoiceChip(
                          label: const Text('Every 2 hours'),
                          selected: tempSelected == 2,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => tempSelected = 2);
                            }
                          },
                        ),
                        ChoiceChip(
                          label: const Text('Every 4 hours'),
                          selected: tempSelected == 4,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => tempSelected = 4);
                            }
                          },
                        ),
                        ChoiceChip(
                          label: const Text('Every 12 hours'),
                          selected: tempSelected == 12,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => tempSelected = 12);
                            }
                          },
                        ),
                        ChoiceChip(
                          label: const Text('Every 24 hours'),
                          selected: tempSelected == 24,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => tempSelected = 24);
                            }
                          },
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, tempSelected),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                ),
              );

              if (selected != null && context.mounted) {
                await _saveSyncInterval(selected);
                if (context.mounted) {
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

                      if (context.mounted) {
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
                      if (context.mounted) {
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
