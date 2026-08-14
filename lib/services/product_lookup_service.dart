import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/catalog_entry.dart';
import 'product_catalog_repository.dart';
import 'shared_catalog_repository.dart';

/// Busca información de un producto por su código de barras, en este orden:
/// 1. Tu propio catálogo (rápido, ya guardado antes).
/// 2. El catálogo compartido entre negocios que usan POSible (si está
///    configurado).
/// 3. Open Food Facts (base de datos pública y gratuita de productos).
///
/// Lo que encuentra lo guarda en tu catálogo propio (y, si corresponde, lo
/// aporta también al catálogo compartido) para la próxima vez.
class ProductLookupService {
  final ProductCatalogRepository _catalogRepository = ProductCatalogRepository();
  final SharedCatalogRepository _sharedCatalogRepository = SharedCatalogRepository();

  Future<CatalogEntry?> lookup(String barcode) async {
    final cached = await _catalogRepository.findByBarcode(barcode);
    if (cached != null) return cached;

    final shared = await _sharedCatalogRepository.findByBarcode(barcode);
    if (shared != null) {
      await _catalogRepository.upsert(
        barcode: shared.barcode,
        name: shared.name,
        brand: shared.brand,
        imageUrl: shared.imageUrl,
        source: 'shared',
      );
      return shared;
    }

    final fromInternet = await _lookupOpenFoodFacts(barcode);
    if (fromInternet != null) {
      await _catalogRepository.upsert(
        barcode: fromInternet.barcode,
        name: fromInternet.name,
        brand: fromInternet.brand,
        imageUrl: fromInternet.imageUrl,
        source: 'openfoodfacts',
      );
      await _sharedCatalogRepository.contribute(
        barcode: fromInternet.barcode,
        name: fromInternet.name,
        brand: fromInternet.brand,
        imageUrl: fromInternet.imageUrl,
      );
      return fromInternet;
    }

    return null;
  }

  Future<CatalogEntry?> _lookupOpenFoodFacts(String barcode) async {
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

      return CatalogEntry(
        barcode: barcode,
        name: name,
        brand: (productData['brands'] as String?)?.trim(),
        imageUrl: productData['image_url'] as String?,
      );
    } catch (_) {
      return null;
    }
  }
}
