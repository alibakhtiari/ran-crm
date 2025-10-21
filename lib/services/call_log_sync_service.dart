import 'package:permission_handler/permission_handler.dart';
import 'package:call_log/call_log.dart';
import '../api/api_client.dart';
import '../models/call.dart' as app_call;

class CallLogSyncService {
  final ApiClient apiClient;

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

  /// Read call logs from phone
  Future<List<CallLogEntry>> readPhoneCallLogs({int limit = 100}) async {
    if (!await hasPermissions()) {
      throw Exception('Phone permission not granted');
    }

    final Iterable<CallLogEntry> entries = await CallLog.query(
      dateFrom: DateTime.now().subtract(const Duration(days: 30)).millisecondsSinceEpoch,
      dateTo: DateTime.now().millisecondsSinceEpoch,
    );

    return entries.take(limit).toList();
  }

  /// Sync phone call logs to server
  Future<SyncResult> syncCallLogsToServer(int userId) async {
    try {
      final callLogs = await readPhoneCallLogs();
      int synced = 0;
      int skipped = 0;
      final List<String> errors = [];

      for (final entry in callLogs) {
        try {
          // Determine direction
          String direction = 'incoming';
          if (entry.callType == CallType.incoming) {
            direction = 'incoming';
          } else if (entry.callType == CallType.outgoing) {
            direction = 'outgoing';
          } else {
            skipped++;
            continue; // Skip missed, rejected, etc.
          }

          // Get phone number
          final phoneNumber = entry.number ?? '';
          if (phoneNumber.isEmpty) {
            skipped++;
            continue;
          }

          // Create app call
          final appCall = app_call.Call(
            phoneNumber: phoneNumber.replaceAll(RegExp(r'[^\d+]'), ''),
            direction: direction,
            startTime: DateTime.fromMillisecondsSinceEpoch(entry.timestamp ?? 0),
            duration: entry.duration ?? 0,
            userId: userId,
          );

          // Try to create on server
          try {
            await apiClient.createCall(appCall);
            synced++;
          } catch (e) {
            // Skip if already exists or other server error
            if (e.toString().contains('already exists') ||
                e.toString().contains('duplicate')) {
              skipped++;
            } else {
              errors.add('$phoneNumber: $e');
            }
          }
        } catch (e) {
          errors.add('${entry.number}: $e');
        }
      }

      return SyncResult(
        total: callLogs.length,
        synced: synced,
        skipped: skipped,
        errors: errors,
      );
    } catch (e) {
      return SyncResult(
        total: 0,
        synced: 0,
        skipped: 0,
        errors: ['Failed to read call logs: $e'],
      );
    }
  }

  /// Get recent call logs
  Future<List<Map<String, dynamic>>> getRecentCalls({int limit = 50}) async {
    try {
      final callLogs = await readPhoneCallLogs(limit: limit);
      return callLogs.map((entry) => {
        'number': entry.number ?? '',
        'name': entry.name ?? '',
        'type': entry.callType?.toString() ?? '',
        'timestamp': entry.timestamp ?? 0,
        'duration': entry.duration ?? 0,
      }).toList();
    } catch (e) {
      return [];
    }
  }
}

class SyncResult {
  final int total;
  final int synced;
  final int skipped;
  final List<String> errors;

  SyncResult({
    required this.total,
    required this.synced,
    required this.skipped,
    required this.errors,
  });

  bool get hasErrors => errors.isNotEmpty;

  String get summary {
    if (errors.isNotEmpty && total == 0) {
      return 'Not available yet';
    }
    return 'Total: $total, Synced: $synced, Skipped: $skipped, Errors: ${errors.length}';
  }
}
