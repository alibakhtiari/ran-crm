import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:call_log/call_log.dart' as phone_call_log;
import '../api/api_client.dart';
import '../models/call_log.dart';
import '../models/call.dart';
import '../models/user.dart';
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

  /// Read call logs from phone and display immediately, then sync to server
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

      // Update local database
      await _localDb.clearCallLogs();
      await _localDb.insertCallLogs(callLogs);

      // Update UI immediately
      _callLogs = callLogs;
      _isLoading = false;
      notifyListeners();

      if (kDebugMode) {
        print('Displaying ${callLogs.length} call logs from phone');
      }

      // Start background sync to server
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

  /// Sync call logs to server in background (non-blocking) with duplicate detection
  Future<void> _syncToServerInBackground() async {
    try {
      int synced = 0;
      int skipped = 0;
      final List<String> errors = [];

      // First, get existing call logs from server to avoid duplicates
      List<CallLog> existingServerCallLogs = [];
      try {
        existingServerCallLogs = await apiClient.getCallLogs();
        if (kDebugMode) {
          print(
              'Found ${existingServerCallLogs.length} existing call logs on server');
        }
      } catch (e) {
        if (kDebugMode) {
          print('Failed to get existing call logs from server: $e');
        }
        // Continue with sync anyway, but will have more duplicates
      }

      // Create a set of existing entries for faster lookup
      final Set<String> existingKeys = existingServerCallLogs
          .map((call) =>
              '${call.phoneNumber}_${call.timestamp.millisecondsSinceEpoch}_${call.direction}')
          .toSet();

      for (final callLog in _callLogs) {
        try {
          // Create unique key for this call log
          final callKey =
              '${callLog.phoneNumber}_${callLog.timestamp.millisecondsSinceEpoch}_${callLog.direction}';

          // Skip if already exists on server
          if (existingKeys.contains(callKey)) {
            skipped++;
            if (kDebugMode) {
              print(
                  'Skipping duplicate call: ${callLog.phoneNumber} at ${callLog.timestamp}');
            }
            continue;
          }

          // Create Call model for server
          final call = Call(
            phoneNumber: callLog.phoneNumber,
            direction: callLog.direction ?? 'incoming',
            startTime: callLog.timestamp,
            duration: callLog.duration,
            userId: callLog.userId,
          );

          // Try to sync to server
          await apiClient.createCall(call);
          synced++;

          if (kDebugMode) {
            print(
                'Synced call log: ${callLog.phoneNumber} at ${callLog.timestamp}');
          }
        } catch (e) {
          // Handle any other errors
          errors.add('${callLog.phoneNumber}: $e');
          if (kDebugMode) {
            print('Error syncing call log ${callLog.phoneNumber}: $e');
          }
        }
      }

      if (kDebugMode) {
        print(
            'Background sync completed: $synced synced, $skipped skipped, ${errors.length} errors');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Background sync failed: $e');
      }
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
