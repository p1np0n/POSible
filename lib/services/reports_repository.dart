import 'package:supabase_flutter/supabase_flutter.dart';

class TopProduct {
  final String name;
  final double quantity;
  final double total;

  TopProduct({required this.name, required this.quantity, required this.total});
}

class SalesSummary {
  final double totalSales;
  final int transactionCount;
  final Map<String, double> byPaymentMethod;
  final List<TopProduct> topProducts;

  SalesSummary({
    required this.totalSales,
    required this.transactionCount,
    required this.byPaymentMethod,
    required this.topProducts,
  });

  double get averageTicket => transactionCount == 0 ? 0 : totalSales / transactionCount;
}

class ReportsRepository {
  final SupabaseClient _client = Supabase.instance.client;

  Future<SalesSummary> getSummary({required DateTime from, required DateTime to}) async {
    final sales = await _client
        .from('sales')
        .select('id, total, payment_method')
        .gte('created_at', from.toIso8601String())
        .lte('created_at', to.toIso8601String());

    final salesList = (sales as List).cast<Map<String, dynamic>>();
    final saleIds = salesList.map((s) => s['id'] as String).toList();

    double totalSales = 0;
    final byPaymentMethod = <String, double>{};
    for (final sale in salesList) {
      final total = (sale['total'] as num).toDouble();
      totalSales += total;
      final method = sale['payment_method'] as String;
      byPaymentMethod[method] = (byPaymentMethod[method] ?? 0) + total;
    }

    final productTotals = <String, TopProduct>{};
    if (saleIds.isNotEmpty) {
      final items = await _client
          .from('sale_items')
          .select('product_name, quantity, subtotal, sale_id')
          .inFilter('sale_id', saleIds);
      for (final item in (items as List).cast<Map<String, dynamic>>()) {
        final name = item['product_name'] as String;
        final qty = (item['quantity'] as num).toDouble();
        final subtotal = (item['subtotal'] as num).toDouble();
        final existing = productTotals[name];
        if (existing == null) {
          productTotals[name] = TopProduct(name: name, quantity: qty, total: subtotal);
        } else {
          productTotals[name] = TopProduct(
            name: name,
            quantity: existing.quantity + qty,
            total: existing.total + subtotal,
          );
        }
      }
    }

    final topProducts = productTotals.values.toList()..sort((a, b) => b.total.compareTo(a.total));

    return SalesSummary(
      totalSales: totalSales,
      transactionCount: salesList.length,
      byPaymentMethod: byPaymentMethod,
      topProducts: topProducts.take(10).toList(),
    );
  }
}
