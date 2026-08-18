import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/current_store.dart';
import '../models/cart_item.dart';

class SalesRepository {
  final SupabaseClient _client = Supabase.instance.client;

  Future<String> createSale({
    required List<CartItem> items,
    required String cashSessionId,
    String? customerId,
    String? discountId,
    double discountAmount = 0,
    double taxAmount = 0,
    double cashAmount = 0,
    double cardAmount = 0,
    double otherAmount = 0,
    required int loyaltyPointsEarned,
  }) async {
    final subtotal = items.fold<double>(0, (sum, item) => sum + item.subtotal);
    // El precio de cada artículo ya incluye el IVA — "taxAmount" es solo la
    // porción de ese precio que corresponde a impuesto (para el desglose del
    // ticket), nunca se suma aparte al total.
    final total = subtotal - discountAmount;

    final methodsUsed = [cashAmount, cardAmount, otherAmount].where((amount) => amount > 0).length;
    final paymentMethod = methodsUsed > 1
        ? 'mixed'
        : cardAmount > 0
            ? 'card'
            : otherAmount > 0
                ? 'other'
                : 'cash';

    final saleData = await _client.from('sales').insert({
      'cash_session_id': cashSessionId,
      'customer_id': customerId,
      'discount_id': discountId,
      'discount_amount': discountAmount,
      'tax_amount': taxAmount,
      'subtotal': subtotal,
      'total': total,
      'payment_method': paymentMethod,
      'cash_amount': cashAmount,
      'card_amount': cardAmount,
      'other_amount': otherAmount,
      'loyalty_points_earned': loyaltyPointsEarned,
      'user_id': _client.auth.currentUser?.id,
      'store_id': CurrentStore.id,
    }).select().single();

    final saleId = saleData['id'] as String;

    final itemRows = items
        .map((item) => {
              'sale_id': saleId,
              'product_id': item.product.isQuickItem ? null : item.product.id,
              'product_name': item.product.name,
              'unit_price': item.unitPrice,
              'quantity': item.quantity,
              'subtotal': item.subtotal,
              'modifiers_summary': item.modifiersLabel.isEmpty ? null : item.modifiersLabel,
              'store_id': CurrentStore.id,
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
