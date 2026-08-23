import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/catalog_entry.dart';
import '../utils/search_normalize.dart';

/// Catálogo global de productos: es UNO SOLO, compartido entre todas tus
/// tiendas (vive en la misma base de datos, no en un proyecto aparte). Se
/// alimenta automáticamente de lo que cada tienda va agregando a su propio
/// inventario (ver product_form_screen.dart), para que las demás tiendas
/// puedan buscar y reutilizar esa información al crear sus propios
/// productos, sin copiar el precio (solo como sugerencia).
class ProductCatalogRepository {
  final SupabaseClient _client = Supabase.instance.client;

  Future<CatalogEntry?> findByBarcode(String barcode) async {
    final data = await _client.from('product_catalog').select().eq('barcode', barcode).maybeSingle();
    if (data == null) return null;
    return CatalogEntry.fromMap(data);
  }

  /// Busca por nombre o código de barras, para sugerir productos ya
  /// cargados por otras tiendas al crear uno nuevo.
  Future<List<CatalogEntry>> search(String query) async {
    if (query.trim().isEmpty) return [];
    final term = normalizeForSearch(query);
    final data = await _client
        .from('product_catalog')
        .select()
        .ilike('product_catalog_search_text', '%$term%')
        .order('name')
        .limit(20);
    return (data as List).map((e) => CatalogEntry.fromMap(e as Map<String, dynamic>)).toList();
  }

  /// Lista/busca todo el catálogo global (se usa desde la pantalla "Catálogo
  /// global", solo visible para el administrador principal).
  Future<List<CatalogEntry>> getAll({String? search}) async {
    var query = _client.from('product_catalog').select();
    if (search != null && search.trim().isNotEmpty) {
      query = query.ilike('product_catalog_search_text', '%${normalizeForSearch(search)}%');
    }
    final data = await query.order('name');
    return (data as List).map((e) => CatalogEntry.fromMap(e as Map<String, dynamic>)).toList();
  }

  /// Aporta o actualiza una entrada del catálogo global. Si tiene código de
  /// barras se usa como clave (evita duplicados); si no, se agrega como una
  /// entrada nueva.
  Future<void> upsert({
    String? barcode,
    required String name,
    String? brand,
    String? imageUrl,
    double? suggestedPrice,
    String source = 'manual',
  }) async {
    if (barcode != null && barcode.isNotEmpty) {
      await _client.from('product_catalog').upsert({
        'barcode': barcode,
        'name': name,
        'brand': brand,
        'image_url': imageUrl,
        'suggested_price': suggestedPrice,
        'source': source,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'barcode');
    } else {
      await _client.from('product_catalog').insert({
        'name': name,
        'brand': brand,
        'image_url': imageUrl,
        'suggested_price': suggestedPrice,
        'source': source,
      });
    }
  }

  Future<void> create(CatalogEntry entry) async {
    await _client.from('product_catalog').insert({
      'barcode': entry.barcode,
      'name': entry.name,
      'brand': entry.brand,
      'image_url': entry.imageUrl,
      'suggested_price': entry.suggestedPrice,
    });
  }

  Future<void> update(String id, CatalogEntry entry) async {
    await _client.from('product_catalog').update({
      'barcode': entry.barcode,
      'name': entry.name,
      'brand': entry.brand,
      'image_url': entry.imageUrl,
      'suggested_price': entry.suggestedPrice,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  Future<void> deleteById(String id) async {
    await _client.from('product_catalog').delete().eq('id', id);
  }
}
