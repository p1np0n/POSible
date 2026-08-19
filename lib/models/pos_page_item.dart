/// Un producto o una categoría agregada a una pestaña personalizada de
/// Ventas — nunca ambos a la vez.
///
/// Cuando es un producto, puede tener su propio nombre y precio (el botón
/// de venta rápida, ej. "Huevos 5x1000"), distintos del producto real que
/// tiene detrás — así se puede agregar el mismo producto varias veces con
/// nombres/precios distintos. Si quedan en null, se usa el nombre/precio
/// normal del producto.
class PosPageItem {
  final String id;
  final String pageId;
  final String? productId;
  final String? categoryId;
  final String? customName;
  final double? customPrice;

  PosPageItem({
    required this.id,
    required this.pageId,
    this.productId,
    this.categoryId,
    this.customName,
    this.customPrice,
  });

  factory PosPageItem.fromMap(Map<String, dynamic> map) => PosPageItem(
        id: map['id'] as String,
        pageId: map['page_id'] as String,
        productId: map['product_id'] as String?,
        categoryId: map['category_id'] as String?,
        customName: map['custom_name'] as String?,
        customPrice: (map['custom_price'] as num?)?.toDouble(),
      );
}
