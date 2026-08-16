class Product {
  final String id;
  final String name;
  final String? categoryId;
  final double price;
  final double? cost;
  final String? sku;
  final String? barcode;
  final String? imageUrl;
  final double stockQuantity;
  final bool trackStock;
  final bool active;
  final double? lowStockThreshold;

  Product({
    required this.id,
    required this.name,
    this.categoryId,
    required this.price,
    this.cost,
    this.sku,
    this.barcode,
    this.imageUrl,
    required this.stockQuantity,
    required this.trackStock,
    required this.active,
    this.lowStockThreshold,
  });

  /// true si el producto controla inventario, tiene un umbral configurado y
  /// las existencias están en o por debajo de ese umbral.
  bool get isLowStock =>
      trackStock && lowStockThreshold != null && stockQuantity <= lowStockThreshold!;

  double? get marginPercent {
    if (cost == null || cost == 0 || price == 0) return null;
    return ((price - cost!) / price) * 100;
  }

  static const _quickItemIdPrefix = 'quick-';

  /// Un ítem agregado a mano en Ventas (nombre y precio libres), sin pasar
  /// por el inventario. No se guarda en la tabla "products".
  factory Product.quickItem({required String name, required double price}) => Product(
        id: '$_quickItemIdPrefix${DateTime.now().microsecondsSinceEpoch}',
        name: name,
        price: price,
        stockQuantity: 0,
        trackStock: false,
        active: true,
      );

  bool get isQuickItem => id.startsWith(_quickItemIdPrefix);

  factory Product.fromMap(Map<String, dynamic> map) => Product(
        id: map['id'] as String,
        name: map['name'] as String,
        categoryId: map['category_id'] as String?,
        price: (map['price'] as num).toDouble(),
        cost: (map['cost'] as num?)?.toDouble(),
        sku: map['sku'] as String?,
        barcode: map['barcode'] as String?,
        imageUrl: map['image_url'] as String?,
        stockQuantity: (map['stock_quantity'] as num).toDouble(),
        trackStock: map['track_stock'] as bool,
        active: map['active'] as bool,
        lowStockThreshold: (map['low_stock_threshold'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'category_id': categoryId,
        'price': price,
        'cost': cost,
        'sku': sku,
        'barcode': barcode,
        'image_url': imageUrl,
        'stock_quantity': stockQuantity,
        'track_stock': trackStock,
        'active': active,
        'low_stock_threshold': lowStockThreshold,
      };
}
