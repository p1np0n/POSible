class Store {
  final String id;
  final String name;
  final String storeCode;
  final String? ownerId;
  final String? ownerEmail;
  final bool featureReports;
  final bool featureCustomers;
  final bool featureEmployees;
  final bool active;
  final DateTime createdAt;

  Store({
    required this.id,
    required this.name,
    required this.storeCode,
    required this.ownerId,
    required this.ownerEmail,
    required this.featureReports,
    required this.featureCustomers,
    required this.featureEmployees,
    required this.active,
    required this.createdAt,
  });

  factory Store.fromMap(Map<String, dynamic> map) => Store(
        id: map['id'] as String,
        name: map['name'] as String,
        storeCode: (map['store_code'] as String?) ?? '',
        ownerId: map['owner_id'] as String?,
        ownerEmail: map['owner_email'] as String?,
        featureReports: map['feature_reports'] as bool,
        featureCustomers: map['feature_customers'] as bool,
        featureEmployees: map['feature_employees'] as bool,
        active: map['active'] as bool,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}
