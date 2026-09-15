class EmployeeProfile {
  final String id;
  final String email;
  final String? displayName;
  final bool approved;
  final String role;
  final List<String> permissions;
  final DateTime createdAt;

  EmployeeProfile({
    required this.id,
    required this.email,
    this.displayName,
    required this.approved,
    required this.role,
    required this.permissions,
    required this.createdAt,
  });

  bool get isAdmin => role == 'admin';

  /// Nombre a mostrar: el que eligió el administrador al crear el cajero,
  /// o el correo si todavía no tiene uno (cuentas de antes de este cambio).
  String get label => (displayName != null && displayName!.trim().isNotEmpty) ? displayName! : email;

  factory EmployeeProfile.fromMap(Map<String, dynamic> map) => EmployeeProfile(
        id: map['id'] as String,
        email: (map['email'] as String?) ?? '',
        displayName: map['display_name'] as String?,
        approved: map['approved'] as bool,
        role: (map['role'] as String?) ?? 'cajero',
        permissions: ((map['permissions'] as List?) ?? const []).map((e) => e.toString()).toList(),
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}
