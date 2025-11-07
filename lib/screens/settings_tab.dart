import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../providers/auth_provider.dart';
import '../services/battery_optimization_service.dart';

class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> with AutomaticKeepAliveClientMixin {
  bool _isLoading = false;
  int _syncIntervalHours = 1;
  bool _batteryOptimizationIgnored = false;
  bool _checkingBatteryOptimization = false;
  DateTime _lastSyncTime = DateTime.now();
  Timer? _timeUpdateTimer;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _checkBatteryOptimizationStatus();
    _startTimeUpdates();
  }

  @override
  void dispose() {
    _timeUpdateTimer?.cancel();
    super.dispose();
  }

  void _startTimeUpdates() {
    // Update time every minute
    _timeUpdateTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) {
        setState(() {
          _lastSyncTime = DateTime.now();
        });
      }
    });
  }

  // Calculate next sync time based on interval
  DateTime getNextSyncTime() {
    if (_syncIntervalHours == 0) {
      // 15 minutes = 0 hours (we use 0 to represent 15 minutes)
      return _lastSyncTime.add(const Duration(minutes: 15));
    } else {
      return _lastSyncTime.add(Duration(hours: _syncIntervalHours));
    }
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _syncIntervalHours = prefs.getInt('sync_interval_hours') ?? 1;
        _lastSyncTime = DateTime.now();
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
        _lastSyncTime = DateTime.now(); // Reset sync time when interval changes
      });
    } catch (e) {
      if (kDebugMode) {
        print('Failed to save sync interval: $e');
      }
    }
  }

  Future<void> _checkBatteryOptimizationStatus() async {
    setState(() => _checkingBatteryOptimization = true);
    try {
      final batteryService = BatteryOptimizationService();
      _batteryOptimizationIgnored = await batteryService.isBatteryOptimizationIgnored();
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to check battery optimization status: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _checkingBatteryOptimization = false);
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
        final currentTime = DateFormat('HH:mm').format(_lastSyncTime);
        final nextSyncTime = getNextSyncTime();
        final nextSyncTimeFormatted = DateFormat('HH:mm').format(nextSyncTime);
        final timeUntilNextSync = nextSyncTime.difference(_lastSyncTime);

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

            // Sync Interval Selector
            ListTile(
              leading: const Icon(Icons.schedule, color: Colors.blue),
              title: const Text('Sync Interval'),
              subtitle: Text(_syncIntervalHours == 0 
                ? 'Current: Every 15 minutes' 
                : 'Current: Every $_syncIntervalHours hour${_syncIntervalHours > 1 ? 's' : ''}'),
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

            // 15-minute sync time display
            if (_syncIntervalHours == 0) ...[
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.access_time, color: Colors.blue),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Current time: $currentTime',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Next sync at: $nextSyncTimeFormatted',
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Time remaining: ${timeUntilNextSync.inHours}h ${timeUntilNextSync.inMinutes % 60}m',
                            style: TextStyle(
                              color: Colors.blue.shade600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

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
                      setState(() => _lastSyncTime = DateTime.now()); // Update sync time

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

            // Battery Optimization Section
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Battery Optimization',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ),

            // Disable Battery Optimization Shortcut
            ListTile(
              leading: _checkingBatteryOptimization
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      _batteryOptimizationIgnored ? Icons.battery_charging_full : Icons.battery_alert,
                      color: _batteryOptimizationIgnored ? Colors.green : Colors.orange,
                    ),
              title: const Text('Disable Battery Optimization'),
              subtitle: Text(
                _batteryOptimizationIgnored
                    ? 'Battery optimization is disabled for reliable background sync'
                    : 'Tap to disable battery optimization for better sync performance',
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: _isLoading
                  ? null
                  : () async {
                      setState(() => _isLoading = true);

                      try {
                        final batteryService = BatteryOptimizationService();
                        final success = await batteryService.requestIgnoreBatteryOptimizations();

                        if (success) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Battery optimization disabled successfully'),
                                backgroundColor: Colors.green,
                              ),
                            );
                            await Future.delayed(const Duration(seconds: 1));
                            if (mounted) {
                              await _checkBatteryOptimizationStatus();
                            }
                          }
                        } else {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Failed to disable battery optimization'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                          }
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
