import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/current_store.dart';
import '../models/modifier.dart';

class ModifierRepository {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<Modifier>> getAll({bool onlyActive = false}) async {
    var query = _client.from('modifiers').select();
    if (onlyActive) {
      query = query.eq('active', true);
    }
    final data = await query.order('name');
    return (data as List).map((e) => Modifier.fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<Modifier> create(Modifier modifier) async {
    final data = await _client
        .from('modifiers')
        .insert({...modifier.toMap(), 'store_id': CurrentStore.id}).select().single();
    return Modifier.fromMap(data);
  }

  Future<void> update(String id, Modifier modifier) async {
    await _client.from('modifiers').update(modifier.toMap()).eq('id', id);
  }

  Future<void> delete(String id) async {
    await _client.from('modifiers').delete().eq('id', id);
  }
}
