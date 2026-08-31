import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/current_store.dart';
import '../models/product.dart';
import '../utils/query_timeout.dart';
import '../utils/search_normalize.dart';

class ProductRepository {
  final SupabaseClient _client = Supabase.instance.client;

  /// Trae TODOS los productos, sin importar cuántos sean. Se pide en
  /// bloques de 1000 filas: Supabase limita cada consulta a un máximo de
  /// filas configurado en el proyecto (1000 por defecto) sin
  /// avisar si el resultado quedó incompleto, así que un solo select()
  /// directo podía recortar el catálogo en silencio en tiendas con más
  /// productos que ese límite (a diferencia de [getPage], que ya paginaba
  /// explícitamente).
  Future<List<Product>> getAll({bool onlyActive = true, bool includeArchived = false}) async {
    const chunkSize = 1000;
    final all = <Product>[];
    var offset = 0;
    while (true) {
      var query = _client.from('products').select();
      if (onlyActive) {
        query = query.eq('active', true);
      }
      if (!includeArchived) {
        query = query.eq('archived', false);
      }
      final data = await query.order('name').range(offset, offset + chunkSize - 1).withTimeout();
      final page = (data as List).map((e) => Product.fromMap(e as Map<String, dynamic>)).toList();
      all.addAll(page);
      if (page.length < chunkSize) break;
      offset += chunkSize;
    }
    return all;
  }

  /// Trae una página de productos activos, ya filtrados y ordenados en el
  /// servidor (para no tener que bajar todo el catálogo de una vez cuando
  /// hay cientos o miles de productos). Devuelve como máximo [pageSize].
  Future<List<Product>> getPage({
    required int offset,
    required int pageSize,
    String? categoryId,
    bool onlyUncategorized = false,
    String? search,
    bool onlyOutOfStock = false,
    String orderBy = 'name',
    bool ascending = true,
    bool onlyArchived = false,
  }) async {
    var query = _client.from('products').select().eq('active', true).eq('archived', onlyArchived);
    if (onlyUncategorized) {
      query = query.isFilter('category_id', null);
    } else if (categoryId != null) {
      query = query.eq('category_id', categoryId);
    }
    if (onlyOutOfStock) {
      query = query.eq('track_stock', true).lte('stock_quantity', 0);
    }
    if (search != null && search.isNotEmpty) {
      // "products_search_text" es una columna calculada (ver sql/schema.sql)
      // que junta nombre+código+sku sin tildes/mayúsculas, para poder
      // buscar "cafe" y encontrar "Café" — el término se normaliza igual
      // acá antes de compararlo.
      final term = normalizeForSearch(search.replaceAll(',', ' '));
      query = query.ilike('products_search_text', '%$term%');
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
        .eq('archived', false)
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

  /// Archivar/desarchivar a mano desde Lista de artículos. Subir stock
  /// (ver [adjustStock]) también desarchiva solo, así que esto es sobre
  /// todo para archivar, o para desarchivar sin necesidad de tocar stock.
  Future<void> setArchived(String id, bool archived) async {
    await _client.from('products').update({'archived': archived}).eq('id', id);
  }
}
