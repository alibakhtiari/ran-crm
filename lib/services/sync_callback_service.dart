import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'background_sync_service.dart';

/// Service to handle sync callbacks from Android sync adapter
class SyncCallbackService {
  static const platform = MethodChannel('com.crm.ran_crm/sync');

  static bool _isRegistered = false;

  /// Register sync callback for Android sync adapter
  static void registerSyncCallback() {
    if (_isRegistered) return;

    platform.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'performSync':
          if (kDebugMode) {
            print('🔄 SyncCallback: Received sync request from Android');
          }
          await BackgroundSyncService.performSync();
          return {'status': 'success'};
        default:
          return {'status': 'method_not_implemented'};
      }
    });

    _isRegistered = true;
    if (kDebugMode) {
      print('✅ SyncCallback registered');
    }
  }

  /// Unregister sync callback
  static void unregisterSyncCallback() {
    if (_isRegistered) {
      platform.setMethodCallHandler(null);
      _isRegistered = false;
      if (kDebugMode) {
        print('✅ SyncCallback unregistered');
      }
    }
  }
}
