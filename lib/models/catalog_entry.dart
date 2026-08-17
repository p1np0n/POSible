class CatalogEntry {
  final String id;
  final String? barcode;
  final String name;
  final String? brand;
  final String? imageUrl;
  final double? suggestedPrice;
  final DateTime? updatedAt;

  CatalogEntry({
    this.id = '',
    this.barcode,
    required this.name,
    this.brand,
    this.imageUrl,
    this.suggestedPrice,
    this.updatedAt,
  });

  factory CatalogEntry.fromMap(Map<String, dynamic> map) => CatalogEntry(
        id: map['id'] as String? ?? '',
        barcode: map['barcode'] as String?,
        name: map['name'] as String,
        brand: map['brand'] as String?,
        imageUrl: map['image_url'] as String?,
        suggestedPrice:
            map['suggested_price'] != null ? (map['suggested_price'] as num).toDouble() : null,
        updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at'] as String) : null,
      );
}
