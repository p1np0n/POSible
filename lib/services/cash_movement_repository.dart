import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/current_store.dart';
import '../models/cash_movement.dart';
import '../utils/query_timeout.dart';

class CashMovementRepository {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<CashMovement>> getForSession(String cashSessionId) async {
    final data = await _client
        .from('cash_movements')
        .select()
        .eq('cash_session_id', cashSessionId)
        .order('created_at')
        .withTimeout();
    return (data as List).map((e) => CashMovement.fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<void> create({
    required String cashSessionId,
    required String type,
    required double amount,
    String? note,
  }) async {
    await _client.from('cash_movements').insert({
      'cash_session_id': cashSessionId,
      'type': type,
      'amount': amount,
      'note': note,
      'user_id': _client.auth.currentUser?.id,
      'user_email': _client.auth.currentUser?.email,
      'store_id': CurrentStore.id,
    }).withTimeout();
  }
}
