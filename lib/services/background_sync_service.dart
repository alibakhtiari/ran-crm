import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../api/api_client.dart';
import 'contact_sync_service.dart';
import 'call_log_sync_service.dart';

/// Background sync service - simplified approach without WorkManager
/// Uses periodic checks when app is in foreground
class BackgroundSyncService {
  static const String syncTaskName = 'com.crm.ran_crm.sync';
  static const String uniqueSyncTaskName = 'periodic_sync';

  // Sync intervals
  static const Duration syncInterval = Duration(hours: 1);
  static DateTime? _lastSyncTime;
  static bool _syncEnabled = true;

  /// Initialize service (no-op now since we removed WorkManager)
  static Future<void> initialize() async {
    // No initialization needed without WorkManager
    if (kDebugMode) {
      print('✅ Background sync service initialized (manual sync mode)');
    }
  }

  /// Enable/disable periodic sync
  static Future<void> registerPeriodicSync() async {
    _syncEnabled = true;
    if (kDebugMode) {
      print('✅ Periodic sync enabled (will sync when app is opened)');
    }
  }

  /// Unregister periodic sync
  static Future<void> unregisterPeriodicSync() async {
    _syncEnabled = false;
    if (kDebugMode) {
      print('✅ Periodic sync disabled');
    }
  }

  /// Register one-time sync task
  static Future<void> registerOneTimeSync() async {
    // Trigger immediate sync
    await performSync();
  }

  /// Cancel all sync tasks
  static Future<void> cancelAllTasks() async {
    _syncEnabled = false;
    if (kDebugMode) {
      print('✅ All sync tasks cancelled');
    }
  }

  /// Check if sync is needed and perform it
  static Future<void> checkAndSync() async {
    if (!_syncEnabled) {
      if (kDebugMode) {
        print('⏭️  Sync disabled, skipping');
      }
      return;
    }

    if (_lastSyncTime != null) {
      final timeSinceLastSync = DateTime.now().difference(_lastSyncTime!);
      if (timeSinceLastSync < syncInterval) {
        if (kDebugMode) {
          print('⏭️  Sync not needed yet (last sync: ${timeSinceLastSync.inMinutes} min ago)');
        }
        return;
      }
    }

    await performSync();
  }

  /// Perform the actual sync
  static Future<void> performSync() async {
    if (kDebugMode) {
      print('📱 Starting sync...');
    }
    _lastSyncTime = DateTime.now();

    try {
      // Initialize services
      const storage = FlutterSecureStorage();
      final apiClient = ApiClient(storage: storage);

      // Check if user is logged in
      final token = await storage.read(key: 'jwt_token');
      if (token == null || token.isEmpty) {
        if (kDebugMode) {
          print('❌ No auth token found, skipping sync');
        }
        return;
      }

      // Get user ID from storage
      final userIdStr = await storage.read(key: 'user_id');
      if (userIdStr == null) {
        if (kDebugMode) {
          print('❌ No user ID found, skipping sync');
        }
        return;
      }
      final userId = int.parse(userIdStr);

      // Initialize sync services
      final contactSync = ContactSyncService(apiClient: apiClient);
      final callLogSync = CallLogSyncService(apiClient: apiClient);

      if (kDebugMode) {
        print('🔄 Starting contact sync...');
      }
      // Sync contacts (both directions)
      try {
        final contactToServerResult = await contactSync.syncContactsToServer(userId);
        if (kDebugMode) {
          print('✅ Contacts to server: ${contactToServerResult.summary}');
        }

        final contactToPhoneResult = await contactSync.syncContactsToPhone();
        if (kDebugMode) {
          print('✅ Contacts to phone: ${contactToPhoneResult.summary}');
        }
      } catch (e) {
        if (kDebugMode) {
          print('❌ Contact sync error: $e');
        }
      }

      if (kDebugMode) {
        print('📞 Starting call log sync...');
      }
      // Sync call logs (to server only)
      try {
        final callLogResult = await callLogSync.syncCallLogsToServer(userId);
        if (kDebugMode) {
          print('✅ Call logs synced: ${callLogResult.summary}');
        }
      } catch (e) {
        if (kDebugMode) {
          print('❌ Call log sync error: $e');
        }
      }

      if (kDebugMode) {
        print('✅ Sync completed successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Sync failed: $e');
      }
    }
  }

  /// Get last sync time
  static DateTime? getLastSyncTime() => _lastSyncTime;

  /// Check if sync is enabled
  static bool isSyncEnabled() => _syncEnabled;
}
