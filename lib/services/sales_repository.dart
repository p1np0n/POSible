import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/cart_item.dart';

class SalesRepository {
  final SupabaseClient _client = Supabase.instance.client;

  Future<String> createSale({
    required List<CartItem> items,
    required String cashSessionId,
    String? customerId,
    required String paymentMethod,
    required int loyaltyPointsEarned,
  }) async {
    final subtotal = items.fold<double>(0, (sum, item) => sum + item.subtotal);

    final saleData = await _client.from('sales').insert({
      'cash_session_id': cashSessionId,
      'customer_id': customerId,
      'subtotal': subtotal,
      'total': subtotal,
      'payment_method': paymentMethod,
      'loyalty_points_earned': loyaltyPointsEarned,
      'user_id': _client.auth.currentUser?.id,
    }).select().single();

    final saleId = saleData['id'] as String;

    final itemRows = items
        .map((item) => {
              'sale_id': saleId,
              'product_id': item.product.id,
              'product_name': item.product.name,
              'unit_price': item.product.price,
              'quantity': item.quantity,
              'subtotal': item.subtotal,
            })
        .toList();

    await _client.from('sale_items').insert(itemRows);

    for (final item in items) {
      if (item.product.trackStock) {
        await _client.rpc('adjust_product_stock', params: {
          'p_id': item.product.id,
          'p_delta': -item.quantity,
        });
      }
    }

    return saleId;
  }
}
