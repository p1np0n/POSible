import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/current_store.dart';
import '../models/customer.dart';
import '../utils/query_timeout.dart';
import '../utils/search_normalize.dart';

class CustomerRepository {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<Customer>> getAll({String? search}) async {
    var query = _client.from('customers').select();
    if (search != null && search.isNotEmpty) {
      query = query.ilike('customers_search_text', '%${normalizeForSearch(search)}%');
    }
    final data = await query.order('name').withTimeout();
    return (data as List).map((e) => Customer.fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<Customer?> getById(String id) async {
    final data = await _client.from('customers').select().eq('id', id).maybeSingle().withTimeout();
    return data == null ? null : Customer.fromMap(data);
  }

  Future<Customer> create(Customer customer) async {
    final data = await _client
        .from('customers')
        .insert({...customer.toMap(), 'store_id': CurrentStore.id}).select().single().withTimeout();
    return Customer.fromMap(data);
  }

  Future<void> update(String id, Customer customer) async {
    await _client.from('customers').update(customer.toMap()).eq('id', id).withTimeout();
  }

  Future<void> delete(String id) async {
    await _client.from('customers').delete().eq('id', id).withTimeout();
  }

  Future<void> addPointsAndSpend(
    String id, {
    required int pointsDelta,
    required double spendDelta,
  }) async {
    await _client.rpc('adjust_customer_loyalty', params: {
      'p_id': id,
      'p_points_delta': pointsDelta,
      'p_spend_delta': spendDelta,
    }).withTimeout();
  }
}
