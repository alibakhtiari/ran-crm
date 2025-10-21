import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AccountSyncService {
  static const platform = MethodChannel('com.crm.ran_crm/account');

  /// Add account to Android system settings
  Future<bool> addAccount(String email, String token) async {
    try {
      final bool result = await platform.invokeMethod('addAccount', {
        'email': email,
        'token': token,
      });
      return result;
    } on PlatformException catch (e) {
      if (kDebugMode) {
        print('Failed to add account: ${e.message}');
      }
      return false;
    }
  }

  /// Remove account from Android system settings
  Future<bool> removeAccount(String email) async {
    try {
      final bool result = await platform.invokeMethod('removeAccount', {
        'email': email,
      });
      return result;
    } on PlatformException catch (e) {
      if (kDebugMode) {
        print('Failed to remove account: ${e.message}');
      }
      return false;
    }
  }

  /// Check if account exists
  Future<bool> hasAccount() async {
    try {
      final bool result = await platform.invokeMethod('hasAccount');
      return result;
    } on PlatformException catch (e) {
      if (kDebugMode) {
        print('Failed to check account: ${e.message}');
      }
      return false;
    }
  }

  /// Get all accounts
  Future<List<String>> getAccounts() async {
    try {
      final List<dynamic> result = await platform.invokeMethod('getAccounts');
      return result.cast<String>();
    } on PlatformException catch (e) {
      if (kDebugMode) {
        print('Failed to get accounts: ${e.message}');
      }
      return [];
    }
  }

  /// Request immediate sync
  Future<bool> requestSync(String email) async {
    try {
      final bool result = await platform.invokeMethod('requestSync', {
        'email': email,
      });
      return result;
    } on PlatformException catch (e) {
      if (kDebugMode) {
        print('Failed to request sync: ${e.message}');
      }
      return false;
    }
  }

  /// Enable or disable automatic sync
  Future<bool> enableAutoSync(String email, bool enable) async {
    try {
      final bool result = await platform.invokeMethod('enableAutoSync', {
        'email': email,
        'enable': enable,
      });
      return result;
    } on PlatformException catch (e) {
      if (kDebugMode) {
        print('Failed to set auto sync: ${e.message}');
      }
      return false;
    }
  }
}
