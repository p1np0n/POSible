import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/catalog_entry.dart';
import 'product_catalog_repository.dart';
import 'settings_repository.dart';

/// Busca información de un producto por su código de barras, en este orden
/// (se queda con lo primero que encuentre, tratando de juntar la mayor
/// información posible: nombre, marca y foto):
/// 1. El catálogo global (compartido entre todas tus tiendas, ya guardado
///    antes por ti o por otra de tus tiendas).
/// 2. Open Food Facts (alimentos), Open Beauty Facts (cosmética/higiene) y
///    Open Products Facts (productos en general) — mismo proyecto, mismo
///    formato, tres bases de datos distintas, todas gratis y sin clave.
/// 3. UPCitemdb (base de datos pública de productos en general).
/// 4. Google Custom Search (búsqueda de imágenes), solo si configuraste tu
///    propia clave en Configuración — último recurso, para cuando ninguna
///    de las fuentes gratuitas de arriba tiene una foto.
///
/// Lo que encuentra en internet lo guarda en el catálogo global para la
/// próxima vez.
class ProductLookupService {
  final ProductCatalogRepository _catalogRepository = ProductCatalogRepository();
  final SettingsRepository _settingsRepository = SettingsRepository();

  Future<CatalogEntry?> lookup(String barcode) async {
    final cached = await _catalogRepository.findByBarcode(barcode);
    if (cached != null) return cached;

    final results = await _lookupFreeSources(barcode);
    final name = _firstNotEmpty(results.map((r) => r?.name));
    if (name == null) return null;

    final brand = _firstNotEmpty(results.map((r) => r?.brand));
    var imageUrl = _firstNotEmpty(results.map((r) => r?.imageUrl));
    imageUrl ??= await _lookupGoogleImage(barcode);

    final merged = CatalogEntry(barcode: barcode, name: name, brand: brand, imageUrl: imageUrl);

    await _catalogRepository.upsert(
      barcode: merged.barcode,
      name: merged.name,
      brand: merged.brand,
      imageUrl: merged.imageUrl,
      source: 'openfoodfacts',
    );
    return merged;
  }

  /// Busca solo una foto por código de barras (sin nombre ni marca), para
  /// completar un producto o una entrada del catálogo que ya tiene esos
  /// datos pero le falta la foto. A diferencia de [lookup], no toca el
  /// catálogo global — eso lo decide quien llama, para no pisar un nombre
  /// ya curado a mano con el que devuelvan las fuentes externas.
  Future<String?> findImageUrl(String barcode) async {
    final results = await _lookupFreeSources(barcode);
    final imageUrl = _firstNotEmpty(results.map((r) => r?.imageUrl));
    if (imageUrl != null) return imageUrl;
    return _lookupGoogleImage(barcode);
  }

  Future<List<CatalogEntry?>> _lookupFreeSources(String barcode) => Future.wait([
        _lookupOpenFoodFactsFamily(barcode, 'world.openfoodfacts.org'),
        _lookupOpenFoodFactsFamily(barcode, 'world.openbeautyfacts.org'),
        _lookupOpenFoodFactsFamily(barcode, 'world.openproductsfacts.org'),
        _lookupUpcItemDb(barcode),
      ]);

  String? _firstNotEmpty(Iterable<String?> values) {
    for (final v in values) {
      if (v != null && v.trim().isNotEmpty) return v.trim();
    }
    return null;
  }

  /// Open Food Facts, Open Beauty Facts y Open Products Facts son el mismo
  /// proyecto y comparten exactamente el mismo formato de API — solo
  /// cambia el dominio según el tipo de producto que catalogan.
  Future<CatalogEntry?> _lookupOpenFoodFactsFamily(String barcode, String host) async {
    try {
      final uri = Uri.parse(
        'https://$host/api/v2/product/$barcode.json'
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

  /// Búsqueda de imagen en Google (Custom Search JSON API, modo imágenes) —
  /// solo funciona si configuraste tu propia clave y motor de búsqueda en
  /// Configuración (gratis hasta 100 consultas/día). Sin eso, simplemente
  /// no se usa esta fuente, sin ningún error visible.
  Future<String?> _lookupGoogleImage(String query) async {
    try {
      final settings = await _settingsRepository.getSettings();
      final apiKey = settings.googleSearchApiKey?.trim();
      final engineId = settings.googleSearchEngineId?.trim();
      if (apiKey == null || apiKey.isEmpty || engineId == null || engineId.isEmpty) return null;

      final uri = Uri.https('www.googleapis.com', '/customsearch/v1', {
        'key': apiKey,
        'cx': engineId,
        'q': query,
        'searchType': 'image',
        'num': '1',
        'safe': 'active',
      });
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final items = json['items'] as List?;
      if (items == null || items.isEmpty) return null;
      final first = items.first as Map<String, dynamic>;
      return (first['link'] as String?)?.trim();
    } catch (_) {
      return null;
    }
  }
}
