import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/shared_catalog_config.dart';
import '../models/catalog_entry.dart';

/// Se conecta al proyecto de Supabase SEPARADO del catálogo compartido
/// (distinto al de tu negocio). Si no está configurado, todo esto no hace
/// nada y no afecta el resto de la app.
class SharedCatalogRepository {
  SupabaseClient? _client;

  SupabaseClient? get _clientOrNull {
    if (!SharedCatalogConfig.isConfigured) return null;
    return _client ??= SupabaseClient(
      SharedCatalogConfig.supabaseUrl,
      SharedCatalogConfig.supabaseAnonKey,
    );
  }

  Future<CatalogEntry?> findByBarcode(String barcode) async {
    final client = _clientOrNull;
    if (client == null) return null;
    try {
      final data = await client.from('shared_products').select().eq('barcode', barcode).maybeSingle();
      if (data == null) return null;
      return CatalogEntry.fromMap(data);
    } catch (_) {
      return null;
    }
  }

  Future<void> contribute({
    required String barcode,
    required String name,
    String? brand,
    String? imageUrl,
  }) async {
    final client = _clientOrNull;
    if (client == null) return;
    try {
      await client.from('shared_products').insert({
        'barcode': barcode,
        'name': name,
        'brand': brand,
        'image_url': imageUrl,
      });
    } catch (_) {
      // Puede fallar si el código ya existe (no se puede sobrescribir) o
      // por conexión; no debe interrumpir el flujo de agregar el producto.
    }
  }

  /// Lista/busca en el catálogo compartido de TODAS las tiendas que usan
  /// POSible. Se usa desde el menú web "Inventario".
  Future<List<CatalogEntry>> getAll({String? search}) async {
    final client = _clientOrNull;
    if (client == null) return [];
    var query = client.from('shared_products').select();
    if (search != null && search.trim().isNotEmpty) {
      query = query.or('name.ilike.%$search%,barcode.ilike.%$search%,brand.ilike.%$search%');
    }
    final data = await query.order('name');
    return (data as List).map((e) => CatalogEntry.fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<void> create(CatalogEntry entry) async {
    final client = _clientOrNull;
    if (client == null) return;
    await client.from('shared_products').insert({
      'barcode': entry.barcode,
      'name': entry.name,
      'brand': entry.brand,
      'image_url': entry.imageUrl,
    });
  }

  Future<void> update(String barcode, CatalogEntry entry) async {
    final client = _clientOrNull;
    if (client == null) return;
    await client.from('shared_products').update({
      'name': entry.name,
      'brand': entry.brand,
      'image_url': entry.imageUrl,
    }).eq('barcode', barcode);
  }

  Future<void> deleteByBarcode(String barcode) async {
    final client = _clientOrNull;
    if (client == null) return;
    await client.from('shared_products').delete().eq('barcode', barcode);
  }
}
