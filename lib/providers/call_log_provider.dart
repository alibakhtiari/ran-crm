import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:call_log/call_log.dart' as phone_call_log;
import '../api/api_client.dart';
import '../models/call_log.dart';
import '../models/call.dart';
import '../models/user.dart';
import '../services/local_database_service.dart';
import '../services/call_log_sync_service.dart';

class CallLogProvider extends ChangeNotifier {
  final ApiClient apiClient;
  final LocalDatabaseService _localDb = LocalDatabaseService();
  final CallLogSyncService _syncService = CallLogSyncService();

  List<CallLog> _callLogs = [];
  bool _isLoading = false;
  String? _errorMessage;
  int _syncProgress = 0;
  int _syncTotal = 0;

  List<CallLog> get callLogs => _callLogs;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get syncProgress => _syncProgress;
  int get syncTotal => _syncTotal;
  double get syncProgressPercent => _syncTotal > 0 ? _syncProgress / _syncTotal : 0.0;

  CallLogProvider({ApiClient? apiClient})
      : apiClient = apiClient ?? ApiClient() {
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

  /// Convert Call model to CallLog model
  CallLog _convertCallToCallLog(Call call, {String? userEmail}) {
    return CallLog(
      id: call.id,
      uuid: call.uuid ?? '', // Handle UUID from server
      phoneNumber: call.phoneNumber,
      callType: call.direction,
      direction: call.direction,
      duration: call.duration,
      timestamp: call.startTime,
      userId: call.userId,
      contactName: null, // Will be populated if available
      userEmail: userEmail,
      createdAt: DateTime.now(),
    );
  }

  /// Read call logs from phone and display immediately, then sync to server with UUID
  Future<void> readAndDisplayCallLogs({bool showLoading = true}) async {
    try {
      if (showLoading) {
        _isLoading = true;
        _errorMessage = null;
        notifyListeners();
      }

      // Check phone permissions
      if (!await Permission.phone.isGranted) {
        final phoneStatus = await Permission.phone.request();
        if (!phoneStatus.isGranted) {
          _errorMessage = 'Phone permission is required to read call logs';
          _isLoading = false;
          notifyListeners();
          return;
        }
      }

      // Read call logs from phone
      final Iterable<phone_call_log.CallLogEntry> phoneEntries =
          await phone_call_log.CallLog.query(
        dateFrom: DateTime.now()
            .subtract(const Duration(days: 30))
            .millisecondsSinceEpoch,
        dateTo: DateTime.now().millisecondsSinceEpoch,
      );

      // Convert to CallLog format - now including missed calls
      final List<CallLog> callLogs = [];
      for (final entry in phoneEntries) {
        try {
          // Include incoming, outgoing, and missed calls
          if (entry.callType != phone_call_log.CallType.incoming &&
              entry.callType != phone_call_log.CallType.outgoing &&
              entry.callType != phone_call_log.CallType.missed) {
            continue;
          }

          final phoneNumber = entry.number ?? '';
          if (phoneNumber.isEmpty) {
            continue;
          }

          String direction;
          String callType;
          
          if (entry.callType == phone_call_log.CallType.incoming) {
            direction = 'incoming';
            callType = 'incoming';
          } else if (entry.callType == phone_call_log.CallType.outgoing) {
            direction = 'outgoing';
            callType = 'outgoing';
          } else if (entry.callType == phone_call_log.CallType.missed) {
            direction = 'missed';
            callType = 'missed';
          } else {
            continue; // Skip unknown call types
          }
          
          final callLog = CallLog(
            id: entry.hashCode,
            phoneNumber: phoneNumber.replaceAll(RegExp(r'[^\d+]'), ''),
            callType: callType,
            direction: direction,
            duration: entry.duration ?? 0,
            timestamp:
                DateTime.fromMillisecondsSinceEpoch(entry.timestamp ?? 0),
            userId: 1, // Using default userId for now
            contactName: entry.name,
            createdAt: DateTime.now(),
          );

          callLogs.add(callLog);
        } catch (e) {
          if (kDebugMode) {
            print('Error converting call entry: $e');
          }
        }
      }

      // Update local database efficiently with batch operation
      await _localDb.clearCallLogs();
      await _localDb.insertCallLogs(callLogs);

      // Update UI immediately
      _callLogs = callLogs;
      _isLoading = false;
      notifyListeners();

      if (kDebugMode) {
        print('Displaying ${callLogs.length} call logs from phone');
      }

      // Start background sync to server with UUID-based duplicate prevention
      _syncToServerInBackground();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetch call logs for a specific user (used by regular users)
  Future<void> fetchCallLogsForUser(User user, {bool showLoading = true}) async {
    try {
      if (showLoading) {
        _isLoading = true;
        _errorMessage = null;
        notifyListeners();
      }

      // For regular users, fetch only their own call logs
      final serverCalls = await apiClient.getCallsForUser(user.id);
      
      // Convert Call objects to CallLog objects
      final serverCallLogs = serverCalls
          .map((call) => _convertCallToCallLog(call, userEmail: user.email))
          .toList();

      // Update local cache with batch operation
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

  /// Fetch all call logs (used by admins)
  Future<void> fetchAllCallLogs({bool showLoading = true}) async {
    try {
      if (showLoading) {
        _isLoading = true;
        _errorMessage = null;
        notifyListeners();
      }

      // For admins, fetch all call logs
      final serverCalls = await apiClient.getAllCalls();
      
      // Convert Call objects to CallLog objects
      final serverCallLogs = serverCalls
          .map((call) => _convertCallToCallLog(call))
          .toList();

      // Update local cache with batch operation
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

  /// Sync call logs to server in background (non-blocking) with UUID-based duplicate detection
  Future<void> _syncToServerInBackground() async {
    try {
      // Use the improved sync service with batch processing
      final result = await _syncService.batchSyncCallLogs(
        1, // userId
        batchSize: 25, // Smaller batches for better performance
        onProgress: (processed, total) {
          _syncProgress = processed;
          _syncTotal = total;
          notifyListeners();
        },
      );

      if (kDebugMode) {
        print(
            'Background sync completed: ${result.synced} synced, ${result.skipped} skipped, ${result.failed} failed');
      }

      // Reset progress after sync
      _syncProgress = 0;
      _syncTotal = 0;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Background sync failed: $e');
      }
      _syncProgress = 0;
      _syncTotal = 0;
      notifyListeners();
    }
  }

  /// Manually trigger sync with progress tracking
  Future<BatchSyncResult> syncCallLogsManually(int userId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _syncService.batchSyncCallLogs(
        userId,
        batchSize: 25,
        onProgress: (processed, total) {
          _syncProgress = processed;
          _syncTotal = total;
          notifyListeners();
        },
      );

      _isLoading = false;
      _syncProgress = 0;
      _syncTotal = 0;
      notifyListeners();

      return result;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      _syncProgress = 0;
      _syncTotal = 0;
      notifyListeners();
      rethrow;
    }
  }

  /// Fetch call logs from server (fallback method)
  Future<void> fetchCallLogs({bool showLoading = true}) async {
    try {
      if (showLoading) {
        _isLoading = true;
        _errorMessage = null;
        notifyListeners();
      }

      // Fetch from server
      final serverCallLogs = await apiClient.getCallLogs();

      // Update local cache with batch operation
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

  /// Get call logs by direction (missed, incoming, outgoing)
  Future<List<CallLog>> getCallLogsByDirection(String direction) async {
    return await _localDb.getCallLogs(direction: direction);
  }

  /// Get call statistics
  Future<Map<String, int>> getCallStatistics() async {
    try {
      final stats = await _syncService.getCallStatistics();
      return stats;
    } catch (e) {
      return {'total': 0, 'incoming': 0, 'outgoing': 0, 'missed': 0};
    }
  }

  /// Refresh call logs from phone and server
  Future<void> refreshCallLogs() async {
    await readAndDisplayCallLogs();
  }

  /// Check if a call log already exists by UUID
  Future<bool> callLogExists(String uuid) async {
    return await _localDb.callLogExists(uuid);
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Filter call logs by direction
  List<CallLog> getFilteredCallLogs(String? direction) {
    if (direction == null || direction.isEmpty) {
      return _callLogs;
    }
    return _callLogs.where((call) => call.direction == direction).toList();
  }

  /// Get unique call directions available
  List<String> getAvailableDirections() {
    return _callLogs.map((call) => call.direction ?? 'incoming').toSet().toList();
  }
}
