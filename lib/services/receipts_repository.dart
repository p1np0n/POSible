import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/sale.dart';
import '../models/sale_item.dart';

class ReceiptsRepository {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<Sale>> getRecent({int limit = 300}) async {
    final data = await _client.from('sales').select().order('created_at', ascending: false).limit(limit);
    return (data as List).map((e) => Sale.fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<List<SaleItem>> getItems(String saleId) async {
    final data = await _client.from('sale_items').select().eq('sale_id', saleId);
    return (data as List).map((e) => SaleItem.fromMap(e as Map<String, dynamic>)).toList();
  }
}
