class EmployeeProfile {
  final String id;
  final String email;
  final bool approved;
  final DateTime createdAt;

  EmployeeProfile({
    required this.id,
    required this.email,
    required this.approved,
    required this.createdAt,
  });

  factory EmployeeProfile.fromMap(Map<String, dynamic> map) => EmployeeProfile(
        id: map['id'] as String,
        email: (map['email'] as String?) ?? '',
        approved: map['approved'] as bool,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}
