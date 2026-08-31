import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/current_store.dart';
import '../models/stock_movement.dart';
import '../utils/query_timeout.dart';

class StockMovementRepository {
  final SupabaseClient _client = Supabase.instance.client;

  Future<void> create({
    String? productId,
    required String productName,
    required String type,
    required double quantity,
    String? note,
    double? costAtTime,
  }) async {
    await _client.from('stock_movements').insert({
      'product_id': productId,
      'product_name': productName,
      'type': type,
      'quantity': quantity,
      'note': note,
      'cost_at_time': costAtTime,
      'user_id': _client.auth.currentUser?.id,
      'user_email': _client.auth.currentUser?.email,
      'store_id': CurrentStore.id,
    });
  }

  Future<List<StockMovement>> getRecent({int limit = 50}) async {
    final data = await _client
        .from('stock_movements')
        .select()
        .order('created_at', ascending: false)
        .limit(limit)
        .withTimeout();
    return (data as List).map((e) => StockMovement.fromMap(e as Map<String, dynamic>)).toList();
  }

  /// Suma el gasto total en mercadería tomada por el dueño para uso propio
  /// (cantidad × costo unitario al momento de cada movimiento), de todos
  /// los tiempos.
  Future<double> getOwnerUseTotal() async {
    final data = await _client
        .from('stock_movements')
        .select('quantity, cost_at_time')
        .eq('type', 'owner_use')
        .withTimeout();
    return _sumCost(data as List);
  }

  /// Suma cuánto se gastó en mercadería agregada al inventario (entradas,
  /// cantidad × costo unitario al momento de cada movimiento) dentro de un
  /// rango de fechas, para mostrar en Reportes. .toUtc() es necesario acá
  /// por el mismo motivo que en reports_repository.dart: from/to vienen en
  /// hora local y Postgres interpretaría un string sin zona horaria como
  /// UTC.
  Future<double> getInboundCostTotal({required DateTime from, required DateTime to}) async {
    final storeId = CurrentStore.id;
    if (storeId == null) return 0;
    final data = await _client
        .from('stock_movements')
        .select('quantity, cost_at_time')
        .eq('store_id', storeId)
        .eq('type', 'in')
        .gte('created_at', from.toUtc().toIso8601String())
        .lte('created_at', to.toUtc().toIso8601String())
        .withTimeout();
    return _sumCost(data as List);
  }

  double _sumCost(List data) => data.cast<Map<String, dynamic>>().fold<double>(0, (sum, m) {
        final cost = (m['cost_at_time'] as num?)?.toDouble() ?? 0;
        final qty = (m['quantity'] as num).toDouble();
        return sum + (cost * qty);
      });
}
