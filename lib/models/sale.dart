class Sale {
  final String id;
  final String? cashSessionId;
  final String? customerId;
  final double subtotal;
  final double total;
  final String paymentMethod;
  final int loyaltyPointsEarned;
  final DateTime createdAt;

  Sale({
    required this.id,
    this.cashSessionId,
    this.customerId,
    required this.subtotal,
    required this.total,
    required this.paymentMethod,
    required this.loyaltyPointsEarned,
    required this.createdAt,
  });

  factory Sale.fromMap(Map<String, dynamic> map) => Sale(
        id: map['id'] as String,
        cashSessionId: map['cash_session_id'] as String?,
        customerId: map['customer_id'] as String?,
        subtotal: (map['subtotal'] as num).toDouble(),
        total: (map['total'] as num).toDouble(),
        paymentMethod: map['payment_method'] as String,
        loyaltyPointsEarned: map['loyalty_points_earned'] as int,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}
