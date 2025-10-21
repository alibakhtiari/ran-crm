import 'package:flutter/foundation.dart';
import '../api/api_client.dart';
import '../models/user.dart';
import '../services/account_sync_service.dart';
import '../services/background_sync_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum AuthStatus {
  initial,
  authenticated,
  unauthenticated,
  loading,
}

class AuthProvider extends ChangeNotifier {
  final ApiClient apiClient;
  final AccountSyncService accountSyncService;
  final FlutterSecureStorage storage;

  AuthStatus _status = AuthStatus.initial;
  User? _user;
  String? _errorMessage;

  AuthStatus get status => _status;
  User? get user => _user;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get isAdmin => _user?.isAdmin ?? false;

  AuthProvider({
    ApiClient? apiClient,
    AccountSyncService? accountSyncService,
    FlutterSecureStorage? storage,
  })  : apiClient = apiClient ?? ApiClient(),
        accountSyncService = accountSyncService ?? AccountSyncService(),
        storage = storage ?? const FlutterSecureStorage() {
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    final isLoggedIn = await apiClient.isLoggedIn();

    if (isLoggedIn) {
      // Load user info from storage
      final userIdStr = await storage.read(key: 'user_id');
      final userEmail = await storage.read(key: 'user_email');
      final userRole = await storage.read(key: 'user_role');

      if (userIdStr != null && userEmail != null && userRole != null) {
        // Reconstruct user object from stored data
        _user = User(
          id: int.parse(userIdStr),
          email: userEmail,
          role: userRole,
          createdAt: DateTime.now(), // Use current time for reconstructed user
        );
        _status = AuthStatus.authenticated;
      } else {
        // Missing user data, need to re-login
        _status = AuthStatus.unauthenticated;
      }
    } else {
      _status = AuthStatus.unauthenticated;
    }

    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    try {
      _status = AuthStatus.loading;
      _errorMessage = null;
      notifyListeners();

      final result = await apiClient.login(email, password);
      _user = result['user'] as User;
      _status = AuthStatus.authenticated;

      // Store user data for persistence
      await storage.write(key: 'user_id', value: _user!.id.toString());
      await storage.write(key: 'user_email', value: _user!.email);
      await storage.write(key: 'user_role', value: _user!.role);

      // Add account to Android system and enable auto-sync
      final token = result['token'];
      if (token != null && token is String) {
        try {
          await accountSyncService.addAccount(email, token);
          await accountSyncService.enableAutoSync(email, true);
        } catch (e) {
          if (kDebugMode) {
            print('Failed to add account to system: $e');
          }
          // Continue even if account sync fails
        }
      }

      // Initialize and register background sync
      try {
        await BackgroundSyncService.initialize();
        await BackgroundSyncService.registerPeriodicSync();
        if (kDebugMode) {
          print('✅ Background sync registered successfully');
        }
      } catch (e) {
        if (kDebugMode) {
          print('❌ Failed to register background sync: $e');
        }
        // Continue even if background sync fails
      }

      notifyListeners();

      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    // Unregister background sync
    try {
      await BackgroundSyncService.cancelAllTasks();
      if (kDebugMode) {
        print('✅ Background sync unregistered');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to unregister background sync: $e');
      }
    }

    // Remove account from Android system
    final userEmail = _user?.email;
    if (userEmail != null) {
      try {
        await accountSyncService.removeAccount(userEmail);
      } catch (e) {
        if (kDebugMode) {
          print('Failed to remove account from system: $e');
        }
      }
    }

    // Clear stored user data
    await storage.delete(key: 'user_id');
    await storage.delete(key: 'user_email');
    await storage.delete(key: 'user_role');

    await apiClient.logout();
    _user = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Manually trigger sync
  Future<bool> triggerSync() async {
    final userEmail = _user?.email;
    if (userEmail == null) return false;

    try {
      // Trigger immediate background sync
      await BackgroundSyncService.registerOneTimeSync();
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Failed to trigger sync: $e');
      }
      return false;
    }
  }
}
