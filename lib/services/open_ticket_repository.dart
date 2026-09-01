import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/current_store.dart';
import '../models/open_ticket.dart';

class OpenTicketRepository {
  final SupabaseClient _client = Supabase.instance.client;

  /// Todos los tickets en espera de la tienda, sin importar en qué turno se
  /// dejaron — antes se filtraba por cash_session_id, así que un ticket
  /// dejado en un turno quedaba inaccesible en la app apenas se cerraba ese
  /// turno (seguía en la base de datos, pero ninguna consulta lo volvía a
  /// traer). Ahora quedan visibles hasta que alguien los retome o los
  /// borre a mano, cruzando turnos.
  Future<List<OpenTicket>> getAll() async {
    final data = await _client.from('open_tickets').select().order('created_at');
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
