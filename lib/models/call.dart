class Call {
  final int? id;
  final int? contactId;
  final int userId;
  final String phoneNumber;
  final String direction; // 'incoming' or 'outgoing'
  final DateTime startTime;
  final int duration; // in seconds

  Call({
    this.id,
    this.contactId,
    required this.userId,
    required this.phoneNumber,
    required this.direction,
    required this.startTime,
    required this.duration,
  });

  factory Call.fromJson(Map<String, dynamic> json) {
    return Call(
      id: json['id'] as int?,
      contactId: json['contact_id'] as int?,
      userId: json['user_id'] as int,
      phoneNumber: json['phone_number'] as String,
      direction: json['direction'] as String,
      startTime: DateTime.parse(json['start_time'] as String),
      duration: json['duration'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (contactId != null) 'contact_id': contactId,
      'user_id': userId,
      'phone_number': phoneNumber,
      'direction': direction,
      'start_time': startTime.toIso8601String(),
      'duration': duration,
    };
  }

  String get formattedDuration {
    final minutes = duration ~/ 60;
    final seconds = duration % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
