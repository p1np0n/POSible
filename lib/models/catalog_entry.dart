class CatalogEntry {
  final String barcode;
  final String name;
  final String? brand;
  final String? imageUrl;
  final DateTime? contributedAt;

  CatalogEntry({
    required this.barcode,
    required this.name,
    this.brand,
    this.imageUrl,
    this.contributedAt,
  });

  factory CatalogEntry.fromMap(Map<String, dynamic> map) => CatalogEntry(
        barcode: map['barcode'] as String,
        name: map['name'] as String,
        brand: map['brand'] as String?,
        imageUrl: map['image_url'] as String?,
        contributedAt:
            map['contributed_at'] != null ? DateTime.parse(map['contributed_at'] as String) : null,
      );
}
