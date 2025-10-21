class CallLog {
  final int? id;
  final String phoneNumber;
  final String callType;
  final int duration;
  final DateTime timestamp;
  final int userId;
  final String? contactName;
  final DateTime createdAt;

  CallLog({
    this.id,
    required this.phoneNumber,
    required this.callType,
    required this.duration,
    required this.timestamp,
    required this.userId,
    this.contactName,
    required this.createdAt,
  });

  factory CallLog.fromJson(Map<String, dynamic> json) {
    return CallLog(
      id: json['id'] as int?,
      phoneNumber: json['phone_number'] as String,
      callType: json['call_type'] as String,
      duration: json['duration'] as int,
      timestamp: DateTime.parse(json['timestamp'] as String),
      userId: json['user_id'] as int,
      contactName: json['contact_name'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'phone_number': phoneNumber,
      'call_type': callType,
      'duration': duration,
      'timestamp': timestamp.toIso8601String(),
      'user_id': userId,
      if (contactName != null) 'contact_name': contactName,
      'created_at': createdAt.toIso8601String(),
    };
  }

  CallLog copyWith({
    int? id,
    String? phoneNumber,
    String? callType,
    int? duration,
    DateTime? timestamp,
    int? userId,
    String? contactName,
    DateTime? createdAt,
  }) {
    return CallLog(
      id: id ?? this.id,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      callType: callType ?? this.callType,
      duration: duration ?? this.duration,
      timestamp: timestamp ?? this.timestamp,
      userId: userId ?? this.userId,
      contactName: contactName ?? this.contactName,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
