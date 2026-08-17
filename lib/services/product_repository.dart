import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/current_store.dart';
import '../models/product.dart';

class ProductRepository {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<Product>> getAll({bool onlyActive = true}) async {
    var query = _client.from('products').select();
    if (onlyActive) {
      query = query.eq('active', true);
    }
    final data = await query.order('name');
    return (data as List).map((e) => Product.fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<Product> create(Product product) async {
    final data = await _client
        .from('products')
        .insert({...product.toMap(), 'store_id': CurrentStore.id}).select().single();
    return Product.fromMap(data);
  }

  Future<void> update(String id, Product product) async {
    await _client.from('products').update(product.toMap()).eq('id', id);
  }

  Future<void> delete(String id) async {
    await _client.from('products').update({'active': false}).eq('id', id);
  }

  Future<void> adjustStock(String id, double delta) async {
    await _client.rpc('adjust_product_stock', params: {'p_id': id, 'p_delta': delta});
  }
}
