import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:call_log/call_log.dart' as phone_call_log;
import 'package:uuid/uuid.dart';
import '../api/api_client.dart';
import '../models/call.dart' as app_call;
import '../models/call_log.dart';

class CallLogSyncService {
  final ApiClient apiClient;
  static const Uuid _uuid = Uuid();

  CallLogSyncService({ApiClient? apiClient})
      : apiClient = apiClient ?? ApiClient();

  /// Request necessary permissions
  Future<bool> requestPermissions() async {
    final phoneStatus = await Permission.phone.request();
    return phoneStatus.isGranted;
  }

  /// Check if permissions are granted
  Future<bool> hasPermissions() async {
    return await Permission.phone.isGranted;
  }

  /// Read call logs from phone (including missed calls)
  Future<List<phone_call_log.CallLogEntry>> readPhoneCallLogs({int limit = 100}) async {
    if (!await hasPermissions()) {
      throw Exception('Phone permission not granted');
    }

    final Iterable<phone_call_log.CallLogEntry> entries = await phone_call_log.CallLog.query(
      dateFrom: DateTime.now().subtract(const Duration(days: 30)).millisecondsSinceEpoch,
      dateTo: DateTime.now().millisecondsSinceEpoch,
    );

    return entries.take(limit).toList();
  }

  /// Convert CallLogEntry to CallLog with UUID
  CallLog _convertToCallLog(phone_call_log.CallLogEntry entry, int userId) {
    // Determine direction
    String direction = 'incoming';
    String callType = 'incoming';
    
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
      // Handle other call types (rejected, blocked, etc.)
      direction = 'missed';
      callType = 'missed';
    }

    // Get phone number
    final phoneNumber = entry.number ?? '';
    
    return CallLog(
      id: entry.hashCode,
      phoneNumber: phoneNumber.replaceAll(RegExp(r'[^\d+]'), ''),
      callType: callType,
      direction: direction,
      duration: entry.duration ?? 0,
      timestamp: DateTime.fromMillisecondsSinceEpoch(entry.timestamp ?? 0),
      userId: userId,
      contactName: entry.name,
      createdAt: DateTime.now(),
    );
  }

  /// Sync phone call logs to server with UUID-based duplicate prevention
  Future<SyncResult> syncCallLogsToServer(int userId) async {
    try {
      final callLogs = await readPhoneCallLogs();
      int synced = 0;
      int skipped = 0;
      int failed = 0;
      final List<String> errors = [];

      // Get existing call logs from server to check for duplicates
      final Set<String> existingUuids = await _getExistingServerUuids();

      for (final entry in callLogs) {
        try {
          // Skip entries without phone numbers
          final phoneNumber = entry.number ?? '';
          if (phoneNumber.isEmpty) {
            skipped++;
            continue;
          }

          // Convert to CallLog with UUID
          final callLog = _convertToCallLog(entry, userId);
          
          // Check for duplicate using UUID
          if (existingUuids.contains(callLog.uuid)) {
            skipped++;
            if (kDebugMode) {
              print('Skipping duplicate call: ${callLog.phoneNumber} at ${callLog.timestamp}');
            }
            continue;
          }

          // Create app call for server
          final appCall = app_call.Call(
            phoneNumber: callLog.phoneNumber,
            direction: callLog.direction ?? 'incoming',
            startTime: callLog.timestamp,
            duration: callLog.duration,
            userId: callLog.userId,
          );

          // Try to create on server
          await apiClient.createCall(appCall);
          synced++;

          if (kDebugMode) {
            print('Synced call log: ${callLog.phoneNumber} at ${callLog.timestamp} (${callLog.direction})');
          }
        } catch (e) {
          failed++;
          errors.add('${entry.number}: $e');
          if (kDebugMode) {
            print('Error syncing call log ${entry.number}: $e');
          }
        }
      }

      return SyncResult(
        total: callLogs.length,
        synced: synced,
        skipped: skipped,
        errors: errors,
        failed: failed, // Add the failed parameter
      );
    } catch (e) {
      return SyncResult(
        total: 0,
        synced: 0,
        skipped: 0,
        errors: ['Failed to read call logs: $e'],
        failed: 0, // Add the failed parameter
      );
    }
  }

  /// Get existing call log UUIDs from server to prevent duplicates
  Future<Set<String>> _getExistingServerUuids() async {
    try {
      final existingCallLogs = await apiClient.getCallLogs();
      return existingCallLogs.map((call) => call.uuid).toSet();
    } catch (e) {
      if (kDebugMode) {
        print('Failed to get existing call logs from server: $e');
      }
      return <String>{};
    }
  }

  /// Batch sync call logs with progress tracking
  Future<BatchSyncResult> batchSyncCallLogs(
    int userId, {
    int batchSize = 50,
    Function(int processed, int total)? onProgress,
  }) async {
    final callLogs = await readPhoneCallLogs();
    final int total = callLogs.length;
    int processed = 0;
    int synced = 0;
    int skipped = 0;
    int failed = 0;
    final List<String> errors = [];

    // Get existing call logs from server
    final Set<String> existingUuids = await _getExistingServerUuids();

    // Process in batches
    for (int i = 0; i < callLogs.length; i += batchSize) {
      final batch = callLogs.skip(i).take(batchSize).toList();
      
      for (final entry in batch) {
        try {
          final phoneNumber = entry.number ?? '';
          if (phoneNumber.isEmpty) {
            skipped++;
            processed++;
            continue;
          }

          final callLog = _convertToCallLog(entry, userId);
          
          // Check for duplicate
          if (existingUuids.contains(callLog.uuid)) {
            skipped++;
            processed++;
            continue;
          }

          // Create and sync call
          final appCall = app_call.Call(
            phoneNumber: callLog.phoneNumber,
            direction: callLog.direction ?? 'incoming',
            startTime: callLog.timestamp,
            duration: callLog.duration,
            userId: callLog.userId,
          );

          await apiClient.createCall(appCall);
          synced++;
          processed++;

          if (kDebugMode) {
            print('Batch synced: ${callLog.phoneNumber} ($processed/$total)');
          }
        } catch (e) {
          failed++;
          processed++;
          errors.add('${entry.number}: $e');
        }
      }

      // Report progress
      onProgress?.call(processed, total);
      
      // Small delay to prevent overwhelming the server
      if (i + batchSize < callLogs.length) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }

    return BatchSyncResult(
      total: total,
      synced: synced,
      skipped: skipped,
      failed: failed,
      errors: errors,
    );
  }

  /// Get recent call logs (including missed calls)
  Future<List<Map<String, dynamic>>> getRecentCalls({int limit = 50}) async {
    try {
      final callLogs = await readPhoneCallLogs(limit: limit);
      return callLogs.map((entry) => {
        'number': entry.number ?? '',
        'name': entry.name ?? '',
        'type': entry.callType?.toString() ?? '',
        'direction': _getDirectionFromCallType(entry.callType),
        'timestamp': entry.timestamp ?? 0,
        'duration': entry.duration ?? 0,
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// Get call type statistics
  Future<Map<String, int>> getCallStatistics() async {
    try {
      final callLogs = await readPhoneCallLogs(limit: 1000);
      final Map<String, int> stats = {
        'incoming': 0,
        'outgoing': 0,
        'missed': 0,
        'total': callLogs.length,
      };

      for (final entry in callLogs) {
        final direction = _getDirectionFromCallType(entry.callType);
        stats[direction] = (stats[direction] ?? 0) + 1;
      }

      return stats;
    } catch (e) {
      return {'total': 0};
    }
  }

  String _getDirectionFromCallType(phone_call_log.CallType? callType) {
    switch (callType) {
      case phone_call_log.CallType.incoming:
        return 'incoming';
      case phone_call_log.CallType.outgoing:
        return 'outgoing';
      case phone_call_log.CallType.missed:
        return 'missed';
      default:
        return 'missed'; // Default to missed for unknown types
    }
  }
}

class SyncResult {
  final int total;
  final int synced;
  final int skipped;
  final int failed;
  final List<String> errors;

  SyncResult({
    required this.total,
    required this.synced,
    required this.skipped,
    required this.errors,
    this.failed = 0, // Add optional failed parameter with default value
  });

  bool get hasErrors => errors.isNotEmpty;

  String get summary {
    if (errors.isNotEmpty && total == 0) {
      return 'Not available yet';
    }
    return 'Total: $total, Synced: $synced, Skipped: $skipped, Failed: $failed, Errors: ${errors.length}';
  }
}

class BatchSyncResult {
  final int total;
  final int synced;
  final int skipped;
  final int failed;
  final List<String> errors;

  BatchSyncResult({
    required this.total,
    required this.synced,
    required this.skipped,
    required this.failed,
    required this.errors,
  });

  bool get isComplete => synced + skipped + failed == total;

  double get progress => total > 0 ? (synced + skipped + failed) / total : 0.0;

  String get summary {
    return 'Progress: ${synced + skipped + failed}/$total, Synced: $synced, Skipped: $skipped, Failed: $failed';
  }
}
