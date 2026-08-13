import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/customer.dart';

class CustomerRepository {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<Customer>> getAll({String? search}) async {
    var query = _client.from('customers').select();
    if (search != null && search.isNotEmpty) {
      query = query.ilike('name', '%$search%');
    }
    final data = await query.order('name');
    return (data as List).map((e) => Customer.fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<Customer> create(Customer customer) async {
    final data = await _client.from('customers').insert(customer.toMap()).select().single();
    return Customer.fromMap(data);
  }

  Future<void> update(String id, Customer customer) async {
    await _client.from('customers').update(customer.toMap()).eq('id', id);
  }

  Future<void> delete(String id) async {
    await _client.from('customers').delete().eq('id', id);
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
    });
  }
}
