import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/discount.dart';

class DiscountRepository {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<Discount>> getAll({bool onlyActive = false}) async {
    var query = _client.from('discounts').select();
    if (onlyActive) {
      query = query.eq('active', true);
    }
    final data = await query.order('name');
    return (data as List).map((e) => Discount.fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<Discount?> getById(String id) async {
    final data = await _client.from('discounts').select().eq('id', id).maybeSingle();
    return data == null ? null : Discount.fromMap(data);
  }

  Future<Discount> create(Discount discount) async {
    final data = await _client.from('discounts').insert(discount.toMap()).select().single();
    return Discount.fromMap(data);
  }

  Future<void> update(String id, Discount discount) async {
    await _client.from('discounts').update(discount.toMap()).eq('id', id);
  }

  Future<void> delete(String id) async {
    await _client.from('discounts').delete().eq('id', id);
  }
}
