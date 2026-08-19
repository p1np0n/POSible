import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/current_store.dart';
import '../models/pos_page.dart';
import '../models/pos_page_item.dart';

class PosPageRepository {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<PosPage>> getAll() async {
    final data = await _client.from('pos_pages').select().order('sort_order').order('created_at');
    return (data as List).map((e) => PosPage.fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<PosPage> create(String name) async {
    final data =
        await _client.from('pos_pages').insert({'name': name, 'store_id': CurrentStore.id}).select().single();
    return PosPage.fromMap(data);
  }

  Future<void> rename(String id, String name) async {
    await _client.from('pos_pages').update({'name': name}).eq('id', id);
  }

  Future<void> delete(String id) async {
    await _client.from('pos_pages').delete().eq('id', id);
  }

  /// Todos los artículos de todas las pestañas de la tienda actual, de una
  /// sola vez (se agrupan por pestaña en la app) — más simple que consultar
  /// pestaña por pestaña.
  Future<List<PosPageItem>> getAllItems() async {
    final data = await _client.from('pos_page_items').select().order('sort_order');
    return (data as List).map((e) => PosPageItem.fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<void> addProduct(
    String pageId,
    String productId, {
    String? customName,
    double? customPrice,
  }) async {
    await _client.from('pos_page_items').insert({
      'page_id': pageId,
      'product_id': productId,
      'store_id': CurrentStore.id,
      'custom_name': customName,
      'custom_price': customPrice,
    });
  }

  /// Cambia el nombre y/o precio propios de un botón ya agregado a una
  /// pestaña. Pasar null en cualquiera de los dos lo deja sin
  /// personalizar (usa el nombre/precio normal del producto).
  Future<void> updateItem(String itemId, {String? customName, double? customPrice}) async {
    await _client.from('pos_page_items').update({
      'custom_name': customName,
      'custom_price': customPrice,
    }).eq('id', itemId);
  }

  Future<void> addCategory(String pageId, String categoryId) async {
    await _client.from('pos_page_items').insert({
      'page_id': pageId,
      'category_id': categoryId,
      'store_id': CurrentStore.id,
    });
  }

  Future<void> removeItem(String itemId) async {
    await _client.from('pos_page_items').delete().eq('id', itemId);
  }
}
