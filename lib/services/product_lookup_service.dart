import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/catalog_entry.dart';
import 'product_catalog_repository.dart';

/// Busca información de un producto por su código de barras, en este orden
/// (se queda con lo primero que encuentre, tratando de juntar la mayor
/// información posible: nombre, marca y foto):
/// 1. El catálogo global (compartido entre todas tus tiendas, ya guardado
///    antes por ti o por otra de tus tiendas).
/// 2. Open Food Facts (base de datos pública de productos, sobre todo de
///    alimentos).
/// 3. UPCitemdb (base de datos pública de productos en general, no solo
///    alimentos — útil para artículos que Open Food Facts no tiene).
///
/// Lo que encuentra en internet lo guarda en el catálogo global para la
/// próxima vez.
class ProductLookupService {
  final ProductCatalogRepository _catalogRepository = ProductCatalogRepository();

  Future<CatalogEntry?> lookup(String barcode) async {
    final cached = await _catalogRepository.findByBarcode(barcode);
    if (cached != null) return cached;

    final results = await Future.wait([
      _lookupOpenFoodFacts(barcode),
      _lookupUpcItemDb(barcode),
    ]);
    final fromOpenFoodFacts = results[0];
    final fromUpcItemDb = results[1];

    // Juntamos lo mejor de las dos fuentes: si una tiene nombre pero no
    // foto (o viceversa), se completan entre sí.
    final name = _firstNotEmpty([fromOpenFoodFacts?.name, fromUpcItemDb?.name]);
    if (name == null) return null;

    final merged = CatalogEntry(
      barcode: barcode,
      name: name,
      brand: _firstNotEmpty([fromOpenFoodFacts?.brand, fromUpcItemDb?.brand]),
      imageUrl: _firstNotEmpty([fromOpenFoodFacts?.imageUrl, fromUpcItemDb?.imageUrl]),
    );

    await _catalogRepository.upsert(
      barcode: merged.barcode,
      name: merged.name,
      brand: merged.brand,
      imageUrl: merged.imageUrl,
      source: 'openfoodfacts',
    );
    return merged;
  }

  String? _firstNotEmpty(List<String?> values) {
    for (final v in values) {
      if (v != null && v.trim().isNotEmpty) return v.trim();
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

  /// Base de datos pública de productos en general (no solo alimentos).
  /// Es de mejor esfuerzo: la cuenta gratuita tiene un límite de consultas
  /// por día, y si en algún momento cambia su formato de respuesta, esto
  /// simplemente no encuentra nada (no rompe el resto de la búsqueda).
  Future<CatalogEntry?> _lookupUpcItemDb(String barcode) async {
    try {
      final uri = Uri.parse('https://api.upcitemdb.com/prod/trial/lookup?upc=$barcode');
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final items = json['items'] as List?;
      if (items == null || items.isEmpty) return null;
      final item = items.first as Map<String, dynamic>;

      final name = (item['title'] as String?)?.trim();
      if (name == null || name.isEmpty) return null;

      final images = item['images'] as List?;
      final imageUrl = (images != null && images.isNotEmpty) ? images.first as String? : null;

      return CatalogEntry(
        barcode: barcode,
        name: name,
        brand: (item['brand'] as String?)?.trim(),
        imageUrl: imageUrl,
      );
    } catch (_) {
      return null;
    }
  }
}
