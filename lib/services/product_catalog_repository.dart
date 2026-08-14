import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/catalog_entry.dart';

class ProductCatalogRepository {
  final SupabaseClient _client = Supabase.instance.client;

  Future<CatalogEntry?> findByBarcode(String barcode) async {
    final data = await _client.from('product_catalog').select().eq('barcode', barcode).maybeSingle();
    if (data == null) return null;
    return CatalogEntry.fromMap(data);
  }

  Future<void> upsert({
    required String barcode,
    required String name,
    String? brand,
    String? imageUrl,
    String source = 'manual',
  }) async {
    await _client.from('product_catalog').upsert({
      'barcode': barcode,
      'name': name,
      'brand': brand,
      'image_url': imageUrl,
      'source': source,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }
}
