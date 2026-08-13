class Customer {
  final String id;
  final String name;
  final String? phone;
  final String? email;
  final int loyaltyPoints;
  final double totalSpent;

  Customer({
    required this.id,
    required this.name,
    this.phone,
    this.email,
    required this.loyaltyPoints,
    required this.totalSpent,
  });

  factory Customer.fromMap(Map<String, dynamic> map) => Customer(
        id: map['id'] as String,
        name: map['name'] as String,
        phone: map['phone'] as String?,
        email: map['email'] as String?,
        loyaltyPoints: map['loyalty_points'] as int,
        totalSpent: (map['total_spent'] as num).toDouble(),
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'phone': phone,
        'email': email,
      };
}
