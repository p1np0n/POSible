/// Un producto o una categoría agregada a una pestaña personalizada de
/// Ventas — nunca ambos a la vez.
class PosPageItem {
  final String id;
  final String pageId;
  final String? productId;
  final String? categoryId;

  PosPageItem({required this.id, required this.pageId, this.productId, this.categoryId});

  factory PosPageItem.fromMap(Map<String, dynamic> map) => PosPageItem(
        id: map['id'] as String,
        pageId: map['page_id'] as String,
        productId: map['product_id'] as String?,
        categoryId: map['category_id'] as String?,
      );
}
