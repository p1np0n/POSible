/// Una línea guardada dentro de un ticket en espera. Es una "foto" del
/// carrito en ese momento — al retomarlo se busca el producto/modificadores
/// actuales por id; si ya no existen, se usa el nombre/precio guardados.
class OpenTicketItem {
  final String? productId;
  final String productName;
  final double unitPrice;
  final double quantity;
  final List<String> modifierIds;

  OpenTicketItem({
    this.productId,
    required this.productName,
    required this.unitPrice,
    required this.quantity,
    this.modifierIds = const [],
  });

  factory OpenTicketItem.fromMap(Map<String, dynamic> map) => OpenTicketItem(
        productId: map['product_id'] as String?,
        productName: map['product_name'] as String,
        unitPrice: (map['unit_price'] as num).toDouble(),
        quantity: (map['quantity'] as num).toDouble(),
        modifierIds: (map['modifier_ids'] as List?)?.map((e) => e as String).toList() ?? const [],
      );

  Map<String, dynamic> toMap() => {
        'product_id': productId,
        'product_name': productName,
        'unit_price': unitPrice,
        'quantity': quantity,
        'modifier_ids': modifierIds,
      };
}

class OpenTicket {
  final String id;
  final String? cashSessionId;
  final String? customerId;
  final String? discountId;
  final String? label;
  final List<OpenTicketItem> items;
  final DateTime createdAt;
  final String? userEmail;

  OpenTicket({
    required this.id,
    this.cashSessionId,
    this.customerId,
    this.discountId,
    this.label,
    required this.items,
    required this.createdAt,
    this.userEmail,
  });

  double get total => items.fold(0, (sum, item) => sum + item.unitPrice * item.quantity);

  factory OpenTicket.fromMap(Map<String, dynamic> map) => OpenTicket(
        id: map['id'] as String,
        cashSessionId: map['cash_session_id'] as String?,
        customerId: map['customer_id'] as String?,
        discountId: map['discount_id'] as String?,
        label: map['label'] as String?,
        items: (map['items_json'] as List)
            .map((e) => OpenTicketItem.fromMap(e as Map<String, dynamic>))
            .toList(),
        createdAt: DateTime.parse(map['created_at'] as String),
        userEmail: map['user_email'] as String?,
      );
}
