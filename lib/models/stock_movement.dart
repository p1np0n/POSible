class StockMovement {
  final String id;
  final String? productId;
  final String productName;
  final String type;
  final double quantity;
  final String? note;
  final DateTime createdAt;
  final String? userEmail;

  StockMovement({
    required this.id,
    this.productId,
    required this.productName,
    required this.type,
    required this.quantity,
    this.note,
    required this.createdAt,
    this.userEmail,
  });

  bool get isIn => type == 'in';

  factory StockMovement.fromMap(Map<String, dynamic> map) => StockMovement(
        id: map['id'] as String,
        productId: map['product_id'] as String?,
        productName: map['product_name'] as String,
        type: map['type'] as String,
        quantity: (map['quantity'] as num).toDouble(),
        note: map['note'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
        userEmail: map['user_email'] as String?,
      );
}
