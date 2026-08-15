import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/cash_movement.dart';

class CashMovementRepository {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<CashMovement>> getForSession(String cashSessionId) async {
    final data = await _client
        .from('cash_movements')
        .select()
        .eq('cash_session_id', cashSessionId)
        .order('created_at');
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
    });
  }
}
