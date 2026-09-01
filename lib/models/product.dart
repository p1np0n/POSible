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

  /// true si el producto está archivado: no se vende hace tiempo, así que
  /// se saca de Ventas y de Lista de artículos (pero no del catálogo
  /// global) hasta que se desarchive a mano o se le suba stock — ver el
  /// filtro en [ProductRepository].
  final bool archived;

  /// Última vez que se vendió (lo actualiza un trigger en la base de datos
  /// cada vez que aparece en una venta) — null si nunca se ha vendido.
  final DateTime? lastSoldAt;

  /// Oferta temporal: mientras estemos entre [promoStartsAt] y
  /// [promoEndsAt], el precio de venta pasa a ser [promoPrice] en vez de
  /// [price] (ver [effectivePrice]).
  final double? promoPrice;
  final DateTime? promoStartsAt;
  final DateTime? promoEndsAt;

  /// Fecha de vencimiento del stock actual (se pregunta al registrar una
  /// entrada en Movimientos de stock) — 1 semana antes se avisa en Lista
  /// de artículos y el precio de venta baja solo al de costo hasta que se
  /// venda o se actualice la fecha (ver [isNearExpiry]/[effectivePrice]).
  final DateTime? expirationDate;

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
    this.archived = false,
    this.lastSoldAt,
    this.promoPrice,
    this.promoStartsAt,
    this.promoEndsAt,
    this.expirationDate,
  });

  bool get isVariablePrice => pricingType == 'variable';
  bool get isSoldByWeight => pricingType == 'weight';

  bool get isPromoActive {
    // Solo para precio fijo: en variable se pregunta el precio cada vez, y
    // en peso "price" es por kilo — mezclarlos con una oferta a precio fijo
    // no tiene un significado claro.
    if (pricingType != 'fixed' || promoPrice == null || promoPrice! <= 0) return false;
    final now = DateTime.now();
    if (promoStartsAt != null && now.isBefore(promoStartsAt!)) return false;
    if (promoEndsAt != null && now.isAfter(promoEndsAt!)) return false;
    return true;
  }

  /// true entre 7 días antes de vencer y el día mismo del vencimiento
  /// (inclusive) — mientras esté vigente, la venta se hace al precio de
  /// costo (ver [effectivePrice]) para que no quede sin venderse a tiempo.
  bool get isNearExpiry {
    if (expirationDate == null) return false;
    final now = DateTime.now();
    final warnFrom = expirationDate!.subtract(const Duration(days: 7));
    final endOfExpiryDay =
        DateTime(expirationDate!.year, expirationDate!.month, expirationDate!.day, 23, 59, 59);
    return !now.isBefore(warnFrom) && !now.isAfter(endOfExpiryDay);
  }

  /// true si ya pasó la fecha de vencimiento — a diferencia de
  /// [isNearExpiry], acá ya no se baja el precio solo (el vencimiento ya
  /// pasó, hay que revisar el producto a mano).
  bool get isExpired {
    if (expirationDate == null) return false;
    final endOfExpiryDay =
        DateTime(expirationDate!.year, expirationDate!.month, expirationDate!.day, 23, 59, 59);
    return DateTime.now().isAfter(endOfExpiryDay);
  }

  /// true si [isNearExpiry] y hay un costo válido menor al precio normal —
  /// condición real para aplicar la rebaja automática a precio de costo.
  bool get isMarkedDownForExpiry => isNearExpiry && cost != null && cost! > 0 && cost! < price;

  /// El precio que corresponde cobrar ahora mismo: el de oferta si está
  /// vigente, si no el de costo si está por vencer, si no el normal.
  double get effectivePrice {
    if (isPromoActive) return promoPrice!;
    if (isMarkedDownForExpiry) return cost!;
    return price;
  }

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
  Product copyWith({String? name, double? price, String? imageUrl, double? stockQuantity, bool? archived}) =>
      Product(
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
        archived: archived ?? this.archived,
        lastSoldAt: lastSoldAt,
        promoPrice: promoPrice,
        promoStartsAt: promoStartsAt,
        promoEndsAt: promoEndsAt,
        expirationDate: expirationDate,
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
        archived: map['archived'] as bool? ?? false,
        lastSoldAt: map['last_sold_at'] != null ? DateTime.parse(map['last_sold_at'] as String) : null,
        promoPrice: (map['promo_price'] as num?)?.toDouble(),
        promoStartsAt: map['promo_starts_at'] != null ? DateTime.parse(map['promo_starts_at'] as String) : null,
        promoEndsAt: map['promo_ends_at'] != null ? DateTime.parse(map['promo_ends_at'] as String) : null,
        expirationDate: map['expiration_date'] != null ? DateTime.parse(map['expiration_date'] as String) : null,
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
        'archived': archived,
        'promo_price': promoPrice,
        'promo_starts_at': promoStartsAt?.toUtc().toIso8601String(),
        'promo_ends_at': promoEndsAt?.toUtc().toIso8601String(),
        'expiration_date': expirationDate != null
            ? '${expirationDate!.year.toString().padLeft(4, '0')}-${expirationDate!.month.toString().padLeft(2, '0')}-${expirationDate!.day.toString().padLeft(2, '0')}'
            : null,
        'plu': plu,
        'target_margin_percent': targetMarginPercent,
      };
}
