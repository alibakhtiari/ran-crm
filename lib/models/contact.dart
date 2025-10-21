class Contact {
  final int? id;
  final String name;
  final String phoneNumber;
  final int createdByUserId;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Contact({
    this.id,
    required this.name,
    required this.phoneNumber,
    required this.createdByUserId,
    required this.createdAt,
    this.updatedAt,
  });

  factory Contact.fromJson(Map<String, dynamic> json) {
    return Contact(
      id: json['id'] as int?,
      name: json['name'] as String,
      phoneNumber: json['phone_number'] as String,
      createdByUserId: json['created_by_user_id'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'phone_number': phoneNumber,
      'created_by_user_id': createdByUserId,
      'created_at': createdAt.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  Contact copyWith({
    int? id,
    String? name,
    String? phoneNumber,
    int? createdByUserId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Contact(
      id: id ?? this.id,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      createdByUserId: createdByUserId ?? this.createdByUserId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
