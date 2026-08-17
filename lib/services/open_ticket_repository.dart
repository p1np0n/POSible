import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/current_store.dart';
import '../models/open_ticket.dart';

class OpenTicketRepository {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<OpenTicket>> getForSession(String cashSessionId) async {
    final data = await _client
        .from('open_tickets')
        .select()
        .eq('cash_session_id', cashSessionId)
        .order('created_at');
    return (data as List).map((e) => OpenTicket.fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<void> create({
    required String cashSessionId,
    String? customerId,
    String? discountId,
    String? label,
    required List<OpenTicketItem> items,
  }) async {
    await _client.from('open_tickets').insert({
      'cash_session_id': cashSessionId,
      'customer_id': customerId,
      'discount_id': discountId,
      'label': label,
      'items_json': items.map((e) => e.toMap()).toList(),
      'user_id': _client.auth.currentUser?.id,
      'user_email': _client.auth.currentUser?.email,
      'store_id': CurrentStore.id,
    });
  }

  Future<void> delete(String id) async {
    await _client.from('open_tickets').delete().eq('id', id);
  }
}
