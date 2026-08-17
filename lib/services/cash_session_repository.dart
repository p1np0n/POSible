import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/current_store.dart';
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

  Future<List<CashSession>> getHistory({int limit = 100}) async {
    final data =
        await _client.from('cash_sessions').select().order('opened_at', ascending: false).limit(limit);
    return (data as List).map((e) => CashSession.fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<CashSession> open(double openingAmount) async {
    final user = _client.auth.currentUser!;
    final data = await _client.from('cash_sessions').insert({
      'opening_amount': openingAmount,
      'status': 'open',
      'user_id': user.id,
      'user_email': user.email,
      'store_id': CurrentStore.id,
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
