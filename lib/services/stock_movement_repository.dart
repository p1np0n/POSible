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
  }) async {
    await _client.from('stock_movements').insert({
      'product_id': productId,
      'product_name': productName,
      'type': type,
      'quantity': quantity,
      'note': note,
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
}
