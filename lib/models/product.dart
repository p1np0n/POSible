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

  /// 'fixed' (normal), 'variable' (se pregunta el precio al venderlo) o
  /// 'weight' (se vende por peso: el precio es por kilo y se agrega al
  /// carrito escaneando un código de balanza — ver [plu]).
  final String pricingType;

  /// Código interno corto (típicamente 5 dígitos) usado para identificar
  /// este producto dentro de un código de barras de balanza. Solo aplica
  /// cuando pricingType es 'weight'.
  final String? plu;

  /// Margen objetivo (%) propio de este producto, para calcular el precio
  /// de venta sugerido a partir del costo. Si es null, se usa el margen
  /// general de la tienda (Configuración).
  final double? targetMarginPercent;

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
    this.pricingType = 'fixed',
    this.plu,
    this.targetMarginPercent,
  });

  bool get isVariablePrice => pricingType == 'variable';
  bool get isSoldByWeight => pricingType == 'weight';

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

  /// Copia este producto reemplazando el precio (ej. al pedirle al cajero
  /// el precio de un artículo de precio variable antes de agregarlo al
  /// carrito), la foto (ej. al encontrarla automáticamente por código de
  /// barras), el nombre (ej. el nombre propio de un botón de venta rápida
  /// en una pestaña, distinto del nombre real del producto) y/o el stock
  /// (ej. al editarlo rápido desde el mosaico de Ventas).
  Product copyWith({String? name, double? price, String? imageUrl, double? stockQuantity}) => Product(
        id: id,
        name: name ?? this.name,
        categoryId: categoryId,
        price: price ?? this.price,
        cost: cost,
        sku: sku,
        barcode: barcode,
        imageUrl: imageUrl ?? this.imageUrl,
        stockQuantity: stockQuantity ?? this.stockQuantity,
        trackStock: trackStock,
        active: active,
        lowStockThreshold: lowStockThreshold,
        pricingType: pricingType,
        plu: plu,
        targetMarginPercent: targetMarginPercent,
      );

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
        pricingType: map['pricing_type'] as String? ?? 'fixed',
        plu: map['plu'] as String?,
        targetMarginPercent: (map['target_margin_percent'] as num?)?.toDouble(),
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
        'pricing_type': pricingType,
        'plu': plu,
        'target_margin_percent': targetMarginPercent,
      };
}
