import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/current_store.dart';
import '../models/cart_item.dart';
import '../utils/query_timeout.dart';

class SalesRepository {
  final SupabaseClient _client = Supabase.instance.client;

  /// Registra la venta completa (la venta, sus ítems, el descuento de
  /// stock y los puntos del cliente) en una sola llamada a la función SQL
  /// "create_sale" — todo o nada: si algo falla a mitad de camino (ej. se
  /// corta la conexión), Postgres deshace todo y no queda nada a medio
  /// registrar, así reintentar nunca duplica la venta.
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
    final itemRows = items
        .map((item) => {
              'product_id': item.product.isQuickItem ? null : item.product.id,
              'product_name': item.product.name,
              'unit_price': item.unitPrice,
              'quantity': item.quantity,
              'subtotal': item.subtotal,
              'modifiers_summary': item.modifiersLabel.isEmpty ? null : item.modifiersLabel,
              'track_stock': item.product.trackStock,
            })
        .toList();

    final result = await _client.rpc('create_sale', params: {
      'p_items': itemRows,
      'p_cash_session_id': cashSessionId,
      'p_customer_id': customerId,
      'p_discount_id': discountId,
      'p_discount_amount': discountAmount,
      'p_tax_amount': taxAmount,
      'p_cash_amount': cashAmount,
      'p_card_amount': cardAmount,
      'p_other_amount': otherAmount,
      'p_loyalty_points_earned': loyaltyPointsEarned,
      'p_store_id': CurrentStore.id,
    }).withTimeout();

    return result as String;
  }
}
