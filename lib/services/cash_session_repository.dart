import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/cash_session.dart';

class CashSessionRepository {
  final SupabaseClient _client = Supabase.instance.client;

  Future<CashSession?> getOpenSession() async {
    final data = await _client
        .from('cash_sessions')
        .select()
        .eq('status', 'open')
        .order('opened_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (data == null) return null;
    return CashSession.fromMap(data);
  }

  Future<CashSession> open(double openingAmount) async {
    final userId = _client.auth.currentUser!.id;
    final data = await _client.from('cash_sessions').insert({
      'opening_amount': openingAmount,
      'status': 'open',
      'user_id': userId,
    }).select().single();
    return CashSession.fromMap(data);
  }

  Future<void> close(String id, {required double closingAmount, String? notes}) async {
    await _client.from('cash_sessions').update({
      'closing_amount': closingAmount,
      'closed_at': DateTime.now().toIso8601String(),
      'status': 'closed',
      'notes': notes,
    }).eq('id', id);
  }
}
