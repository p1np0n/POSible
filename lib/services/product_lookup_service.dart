import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/catalog_entry.dart';
import 'product_catalog_repository.dart';

/// Busca información de un producto por su código de barras: primero en tu
/// propio catálogo (rápido, ya guardado antes), y si no está, en Open Food
/// Facts (base de datos pública y gratuita de productos, sin necesidad de
/// llave de API). Lo que encuentra en internet lo guarda en tu catálogo para
/// la próxima vez.
class ProductLookupService {
  final ProductCatalogRepository _catalogRepository = ProductCatalogRepository();

  Future<CatalogEntry?> lookup(String barcode) async {
    final cached = await _catalogRepository.findByBarcode(barcode);
    if (cached != null) return cached;

    try {
      final uri = Uri.parse(
        'https://world.openfoodfacts.org/api/v2/product/$barcode.json'
        '?fields=product_name,brands,image_url,status',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (json['status'] != 1) return null;

      final productData = json['product'] as Map<String, dynamic>?;
      if (productData == null) return null;

      final name = (productData['product_name'] as String?)?.trim();
      if (name == null || name.isEmpty) return null;

      final entry = CatalogEntry(
        barcode: barcode,
        name: name,
        brand: (productData['brands'] as String?)?.trim(),
        imageUrl: productData['image_url'] as String?,
      );

      await _catalogRepository.upsert(
        barcode: entry.barcode,
        name: entry.name,
        brand: entry.brand,
        imageUrl: entry.imageUrl,
        source: 'openfoodfacts',
      );

      return entry;
    } catch (_) {
      return null;
    }
  }
}
