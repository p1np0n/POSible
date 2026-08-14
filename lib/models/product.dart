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
  });

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
      };
}
