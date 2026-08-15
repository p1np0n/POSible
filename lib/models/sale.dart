class Sale {
  final String id;
  final int receiptNumber;
  final String? cashSessionId;
  final String? customerId;
  final String? discountId;
  final double discountAmount;
  final double taxAmount;
  final double subtotal;
  final double total;
  final String paymentMethod;
  final double cashAmount;
  final double cardAmount;
  final double otherAmount;
  final int loyaltyPointsEarned;
  final DateTime createdAt;

  Sale({
    required this.id,
    required this.receiptNumber,
    this.cashSessionId,
    this.customerId,
    this.discountId,
    required this.discountAmount,
    required this.taxAmount,
    required this.subtotal,
    required this.total,
    required this.paymentMethod,
    this.cashAmount = 0,
    this.cardAmount = 0,
    this.otherAmount = 0,
    required this.loyaltyPointsEarned,
    required this.createdAt,
  });

  bool get isSplitPayment => paymentMethod == 'mixed';

  factory Sale.fromMap(Map<String, dynamic> map) => Sale(
        id: map['id'] as String,
        receiptNumber: map['receipt_number'] as int,
        cashSessionId: map['cash_session_id'] as String?,
        customerId: map['customer_id'] as String?,
        discountId: map['discount_id'] as String?,
        discountAmount: (map['discount_amount'] as num).toDouble(),
        taxAmount: (map['tax_amount'] as num).toDouble(),
        subtotal: (map['subtotal'] as num).toDouble(),
        total: (map['total'] as num).toDouble(),
        paymentMethod: map['payment_method'] as String,
        cashAmount: (map['cash_amount'] as num?)?.toDouble() ?? 0,
        cardAmount: (map['card_amount'] as num?)?.toDouble() ?? 0,
        otherAmount: (map['other_amount'] as num?)?.toDouble() ?? 0,
        loyaltyPointsEarned: map['loyalty_points_earned'] as int,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}
