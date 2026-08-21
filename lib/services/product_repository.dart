import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/current_store.dart';
import '../models/product.dart';
import '../utils/query_timeout.dart';

class ProductRepository {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<Product>> getAll({bool onlyActive = true}) async {
    var query = _client.from('products').select();
    if (onlyActive) {
      query = query.eq('active', true);
    }
    final data = await query.order('name').withTimeout();
    return (data as List).map((e) => Product.fromMap(e as Map<String, dynamic>)).toList();
  }

  /// Trae una página de productos activos, ya filtrados y ordenados en el
  /// servidor (para no tener que bajar todo el catálogo de una vez cuando
  /// hay cientos o miles de productos). Devuelve como máximo [pageSize].
  Future<List<Product>> getPage({
    required int offset,
    required int pageSize,
    String? categoryId,
    String? search,
    bool onlyOutOfStock = false,
    String orderBy = 'name',
    bool ascending = true,
  }) async {
    var query = _client.from('products').select().eq('active', true);
    if (categoryId != null) {
      query = query.eq('category_id', categoryId);
    }
    if (onlyOutOfStock) {
      query = query.eq('track_stock', true).lte('stock_quantity', 0);
    }
    if (search != null && search.isNotEmpty) {
      final term = search.replaceAll(',', ' ');
      query = query.or('name.ilike.%$term%,barcode.ilike.%$term%,sku.ilike.%$term%');
    }
    final data =
        await query.order(orderBy, ascending: ascending).range(offset, offset + pageSize - 1).withTimeout();
    return (data as List).map((e) => Product.fromMap(e as Map<String, dynamic>)).toList();
  }

  /// Solo los productos con un umbral de inventario bajo configurado (ver
  /// Lista de artículos). Suele ser un grupo chico, así que se trae
  /// completo y se filtra por stock <= umbral en la app (Supabase no puede
  /// comparar dos columnas entre sí directamente en un filtro simple).
  Future<List<Product>> getLowStockCandidates() async {
    final data = await _client
        .from('products')
        .select()
        .eq('active', true)
        .eq('track_stock', true)
        .not('low_stock_threshold', 'is', null);
    return (data as List).map((e) => Product.fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<Product?> findByBarcode(String barcode) async {
    final data =
        await _client.from('products').select().eq('barcode', barcode).eq('active', true).maybeSingle();
    if (data == null) return null;
    return Product.fromMap(data);
  }

  /// Trae productos puntuales por id, sin filtrar por activo — para
  /// resolver productos que una pestaña personalizada referencia pero que
  /// todavía no están en el catálogo cargado en memoria (ej. recién
  /// agregados desde otra pantalla en la misma sesión).
  Future<List<Product>> getByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    final data = await _client.from('products').select().inFilter('id', ids);
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
