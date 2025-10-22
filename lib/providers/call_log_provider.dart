import 'package:flutter/foundation.dart';
import '../api/api_client.dart';
import '../models/call_log.dart';
import '../services/local_database_service.dart';

class CallLogProvider extends ChangeNotifier {
  final ApiClient apiClient;
  final LocalDatabaseService _localDb = LocalDatabaseService();

  List<CallLog> _callLogs = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<CallLog> get callLogs => _callLogs;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  CallLogProvider({ApiClient? apiClient}) : apiClient = apiClient ?? ApiClient() {
    // Load from local cache immediately
    _loadFromCache();
  }

  /// Load call logs from local cache (instant)
  Future<void> _loadFromCache() async {
    try {
      _callLogs = await _localDb.getCallLogs();
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Failed to load call logs from cache: $e');
      }
    }
  }

  /// Fetch call logs from server and update cache
  Future<void> fetchCallLogs({bool showLoading = true}) async {
    try {
      if (showLoading) {
        _isLoading = true;
        _errorMessage = null;
        notifyListeners();
      }

      // Fetch from server
      final serverCallLogs = await apiClient.getCallLogs();

      // Update local cache
      await _localDb.clearCallLogs();
      await _localDb.insertCallLogs(serverCallLogs);

      // Update UI
      _callLogs = serverCallLogs;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();

      // Fall back to cache on error
      if (_callLogs.isEmpty) {
        await _loadFromCache();
      }
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
