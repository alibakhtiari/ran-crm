class User {
  final int id;
  final String email;
  final String role;
  final DateTime createdAt;

  User({
    required this.id,
    required this.email,
    required this.role,
    required this.createdAt,
  });

  bool get isAdmin => role == 'admin';

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      email: json['email'] as String,
      role: json['role'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'role': role,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
