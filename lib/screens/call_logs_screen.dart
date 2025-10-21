import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api/api_client.dart';
import '../models/call.dart';
import '../widgets/call_tile.dart';
import '../services/call_log_sync_service.dart';
import '../providers/auth_provider.dart';

class CallLogsScreen extends StatefulWidget {
  const CallLogsScreen({super.key});

  @override
  State<CallLogsScreen> createState() => _CallLogsScreenState();
}

class _CallLogsScreenState extends State<CallLogsScreen> {
  late final ApiClient _apiClient;
  late final CallLogSyncService _syncService;
  List<Call> _calls = [];
  bool _isLoading = true;
  bool _isSyncing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _apiClient = ApiClient();
    _syncService = CallLogSyncService();
    _fetchCalls();
  }

  Future<void> _fetchCalls() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final calls = await _apiClient.getCalls();
      if (mounted) {
        setState(() {
          _calls = calls;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _syncCallLogs() async {
    if (_isSyncing) return;

    setState(() => _isSyncing = true);

    try {
      final authProvider = context.read<AuthProvider>();
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
        return;
      }

      // Check permissions first
      final hasPermission = await _syncService.hasPermissions();
      if (!hasPermission) {
        final granted = await _syncService.requestPermissions();
        if (!granted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Phone permission is required to sync call logs'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }
      }

      // Show syncing dialog
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
                Text('Syncing call logs...'),
              ],
            ),
          ),
        );
      }

      // Sync call logs
      final result = await _syncService.syncCallLogsToServer(user.id);

      // Close syncing dialog
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      // Refresh call logs
      await _fetchCalls();

      // Show result
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync complete: ${result.summary}'),
            backgroundColor: result.hasErrors ? Colors.orange : Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      // Close dialog if open
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      // Show error
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
        setState(() => _isSyncing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Call Logs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: _isSyncing ? null : _syncCallLogs,
            tooltip: 'Sync Call Logs',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchCalls,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Error: $_errorMessage',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchCalls,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _calls.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.phone_missed,
                            size: 64,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No call logs yet',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Tap the sync button to sync your call logs',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: _isSyncing ? null : _syncCallLogs,
                            icon: const Icon(Icons.sync),
                            label: const Text('Sync Call Logs'),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _fetchCalls,
                      child: ListView.builder(
                        itemCount: _calls.length,
                        itemBuilder: (context, index) {
                          return CallTile(call: _calls[index]);
                        },
                      ),
                    ),
    );
  }
}
