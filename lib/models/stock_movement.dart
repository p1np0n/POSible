class StockMovement {
  final String id;
  final String? productId;
  final String productName;
  final String type;
  final double quantity;
  final String? note;
  final DateTime createdAt;
  final String? userEmail;

  /// Costo unitario del producto al momento del movimiento — solo se
  /// guarda para movimientos de "uso propio" (ver [isOwnerUse]), para
  /// poder sumar el gasto total sin que cambie si después se actualiza el
  /// costo del producto.
  final double? costAtTime;

  StockMovement({
    required this.id,
    this.productId,
    required this.productName,
    required this.type,
    required this.quantity,
    this.note,
    required this.createdAt,
    this.userEmail,
    this.costAtTime,
  });

  bool get isIn => type == 'in';
  bool get isOwnerUse => type == 'owner_use';

  factory StockMovement.fromMap(Map<String, dynamic> map) => StockMovement(
        id: map['id'] as String,
        productId: map['product_id'] as String?,
        productName: map['product_name'] as String,
        type: map['type'] as String,
        quantity: (map['quantity'] as num).toDouble(),
        note: map['note'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
        userEmail: map['user_email'] as String?,
        costAtTime: (map['cost_at_time'] as num?)?.toDouble(),
      );
}
