import 'package:uuid/uuid.dart';

class CallLog {
  final int? id;
  final String uuid; // Unique identifier for duplicate prevention
  final String phoneNumber;
  final String callType;
  final String? direction; // incoming/outgoing/missed
  final int duration;
  final DateTime timestamp;
  final int userId;
  final String? contactName;
  final String? userEmail; // Include user email from API if available
  final DateTime createdAt;

  CallLog({
    this.id,
    String? uuid,
    required this.phoneNumber,
    required this.callType,
    this.direction,
    required this.duration,
    required this.timestamp,
    required this.userId,
    this.contactName,
    this.userEmail,
    required this.createdAt,
  }) : uuid = uuid ?? const Uuid().v4();

  factory CallLog.fromJson(Map<String, dynamic> json) {
    return CallLog(
      id: json['id'] as int?,
      uuid: json['uuid'] as String?,
      phoneNumber: json['phone_number'] as String? ?? '',
      callType: json['call_type'] as String? ?? '',
      direction: json['direction'] as String? ?? _inferDirectionFromCallType(json['call_type'] as String?),
      duration: json['duration'] as int? ?? 0,
      timestamp: json['start_time'] != null 
          ? DateTime.parse(json['start_time'] as String) 
          : (json['timestamp'] != null ? DateTime.parse(json['timestamp'] as String) : DateTime.now()),
      userId: json['user_id'] as int,
      contactName: json['contact_name'] as String?,
      userEmail: json['user_email'] as String?,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String) 
          : DateTime.now(),
    );
  }

  static String _inferDirectionFromCallType(String? callType) {
    if (callType == null) return 'incoming';
    
    final type = callType.toLowerCase();
    if (type.contains('incoming') || type.contains('received')) return 'incoming';
    if (type.contains('outgoing') || type.contains('made')) return 'outgoing';
    if (type.contains('missed')) return 'missed';
    
    // Default to incoming for backward compatibility
    return 'incoming';
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'uuid': uuid,
      'phone_number': phoneNumber,
      'call_type': callType,
      if (direction != null) 'direction': direction,
      'duration': duration,
      'timestamp': timestamp.toIso8601String(),
      'user_id': userId,
      if (contactName != null) 'contact_name': contactName,
      if (userEmail != null) 'user_email': userEmail,
      'created_at': createdAt.toIso8601String(),
    };
  }

  CallLog copyWith({
    int? id,
    String? uuid,
    String? phoneNumber,
    String? callType,
    String? direction,
    int? duration,
    DateTime? timestamp,
    int? userId,
    String? contactName,
    String? userEmail,
    DateTime? createdAt,
  }) {
    return CallLog(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      callType: callType ?? this.callType,
      direction: direction ?? this.direction,
      duration: duration ?? this.duration,
      timestamp: timestamp ?? this.timestamp,
      userId: userId ?? this.userId,
      contactName: contactName ?? this.contactName,
      userEmail: userEmail ?? this.userEmail,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
