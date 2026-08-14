class SaleItem {
  final String id;
  final String saleId;
  final String? productId;
  final String productName;
  final double unitPrice;
  final double quantity;
  final double subtotal;
  final String? modifiersSummary;

  SaleItem({
    required this.id,
    required this.saleId,
    this.productId,
    required this.productName,
    required this.unitPrice,
    required this.quantity,
    required this.subtotal,
    this.modifiersSummary,
  });

  factory SaleItem.fromMap(Map<String, dynamic> map) => SaleItem(
        id: map['id'] as String,
        saleId: map['sale_id'] as String,
        productId: map['product_id'] as String?,
        productName: map['product_name'] as String,
        unitPrice: (map['unit_price'] as num).toDouble(),
        quantity: (map['quantity'] as num).toDouble(),
        subtotal: (map['subtotal'] as num).toDouble(),
        modifiersSummary: map['modifiers_summary'] as String?,
      );
}
