import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/current_store.dart';
import '../utils/query_timeout.dart';

class TopProduct {
  final String name;
  final double quantity;
  final double total;

  TopProduct({required this.name, required this.quantity, required this.total});
}

class DailyTotal {
  final DateTime date;
  final double total;

  DailyTotal({required this.date, required this.total});
}

class NamedTotal {
  final String name;
  final double total;

  NamedTotal({required this.name, required this.total});
}

class ModifierUsage {
  final String name;
  final double count;

  ModifierUsage({required this.name, required this.count});
}

class SalesSummary {
  final double totalSales;
  final int transactionCount;
  final Map<String, double> byPaymentMethod;
  final List<TopProduct> topProducts;
  final List<DailyTotal> dailyTotals;

  SalesSummary({
    required this.totalSales,
    required this.transactionCount,
    required this.byPaymentMethod,
    required this.topProducts,
    required this.dailyTotals,
  });

  double get averageTicket => transactionCount == 0 ? 0 : totalSales / transactionCount;
}

class ReportsRepository {
  final SupabaseClient _client = Supabase.instance.client;

  Future<SalesSummary> getSummary({required DateTime from, required DateTime to}) async {
    final storeId = CurrentStore.id;
    if (storeId == null) {
      return SalesSummary(totalSales: 0, transactionCount: 0, byPaymentMethod: {}, topProducts: [], dailyTotals: []);
    }
    final sales = await _client
        .from('sales')
        .select('id, total, cash_amount, card_amount, other_amount, created_at')
        .eq('store_id', storeId)
        .gte('created_at', from.toIso8601String())
        .lte('created_at', to.toIso8601String())
        .withTimeout();

    final salesList = (sales as List).cast<Map<String, dynamic>>();
    final saleIds = salesList.map((s) => s['id'] as String).toList();

    double totalSales = 0;
    final byPaymentMethod = <String, double>{};
    final byDay = <DateTime, double>{};
    for (final sale in salesList) {
      final total = (sale['total'] as num).toDouble();
      totalSales += total;
      // Se reparte por método real pagado (cash_amount/card_amount/other_amount)
      // en vez de "payment_method", así una venta con pago dividido cuenta en
      // cada método por la parte que le corresponde.
      final cash = (sale['cash_amount'] as num?)?.toDouble() ?? 0;
      final card = (sale['card_amount'] as num?)?.toDouble() ?? 0;
      final other = (sale['other_amount'] as num?)?.toDouble() ?? 0;
      if (cash > 0) byPaymentMethod['cash'] = (byPaymentMethod['cash'] ?? 0) + cash;
      if (card > 0) byPaymentMethod['card'] = (byPaymentMethod['card'] ?? 0) + card;
      if (other > 0) byPaymentMethod['other'] = (byPaymentMethod['other'] ?? 0) + other;

      final createdAt = DateTime.parse(sale['created_at'] as String).toLocal();
      final day = DateTime(createdAt.year, createdAt.month, createdAt.day);
      byDay[day] = (byDay[day] ?? 0) + total;
    }
    final dailyTotals = byDay.entries.map((e) => DailyTotal(date: e.key, total: e.value)).toList()
      ..sort((a, b) => a.date.compareTo(b.date));

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
      dailyTotals: dailyTotals,
    );
  }

  /// Solo el total vendido en el período (para comparar contra el período
  /// anterior de igual duración, sin traer todo el detalle).
  Future<double> getTotalSales({required DateTime from, required DateTime to}) async {
    final storeId = CurrentStore.id;
    if (storeId == null) return 0;
    final sales = await _client
        .from('sales')
        .select('total')
        .eq('store_id', storeId)
        .gte('created_at', from.toIso8601String())
        .lte('created_at', to.toIso8601String())
        .withTimeout();
    return (sales as List).fold<double>(0, (sum, s) => sum + (s['total'] as num).toDouble());
  }

  /// IDs de los productos más vendidos (por cantidad) en los últimos [days]
  /// días, de mayor a menor. Se usa para la pestaña "Más vendidos" en
  /// Ventas. Ignora líneas sin product_id (artículos rápidos, que no están
  /// en el catálogo).
  Future<List<String>> getTopSellingProductIds({int days = 30, int limit = 12}) async {
    final from = DateTime.now().subtract(Duration(days: days));
    final saleIds = await _saleIdsInRange(from, DateTime.now());
    if (saleIds.isEmpty) return [];

    final items =
        await _client.from('sale_items').select('product_id, quantity').inFilter('sale_id', saleIds);

    final totals = <String, double>{};
    for (final item in (items as List).cast<Map<String, dynamic>>()) {
      final productId = item['product_id'] as String?;
      if (productId == null) continue;
      final qty = (item['quantity'] as num).toDouble();
      totals[productId] = (totals[productId] ?? 0) + qty;
    }
    final sorted = totals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(limit).map((e) => e.key).toList();
  }

  Future<List<String>> _saleIdsInRange(DateTime from, DateTime to) async {
    final storeId = CurrentStore.id;
    if (storeId == null) return [];
    final sales = await _client
        .from('sales')
        .select('id')
        .eq('store_id', storeId)
        .gte('created_at', from.toIso8601String())
        .lte('created_at', to.toIso8601String())
        .withTimeout();
    return (sales as List).map((s) => s['id'] as String).toList();
  }

  Future<List<NamedTotal>> getByCategory({required DateTime from, required DateTime to}) async {
    final saleIds = await _saleIdsInRange(from, to);
    if (saleIds.isEmpty) return [];

    final items = await _client
        .from('sale_items')
        .select('product_id, subtotal')
        .inFilter('sale_id', saleIds);
    final itemsList = (items as List).cast<Map<String, dynamic>>();

    final productIds = itemsList.map((i) => i['product_id'] as String?).whereType<String>().toSet().toList();
    final categoryIdByProduct = <String, String?>{};
    if (productIds.isNotEmpty) {
      final products = await _client.from('products').select('id, category_id').inFilter('id', productIds);
      for (final p in (products as List).cast<Map<String, dynamic>>()) {
        categoryIdByProduct[p['id'] as String] = p['category_id'] as String?;
      }
    }
    final categoryIds = categoryIdByProduct.values.whereType<String>().toSet().toList();
    final categoryNameById = <String, String>{};
    if (categoryIds.isNotEmpty) {
      final categories = await _client.from('categories').select('id, name').inFilter('id', categoryIds);
      for (final c in (categories as List).cast<Map<String, dynamic>>()) {
        categoryNameById[c['id'] as String] = c['name'] as String;
      }
    }

    final totals = <String, double>{};
    for (final item in itemsList) {
      final productId = item['product_id'] as String?;
      final categoryId = productId != null ? categoryIdByProduct[productId] : null;
      final name = categoryId != null ? (categoryNameById[categoryId] ?? 'Sin categoría') : 'Sin categoría';
      final subtotal = (item['subtotal'] as num).toDouble();
      totals[name] = (totals[name] ?? 0) + subtotal;
    }
    return totals.entries.map((e) => NamedTotal(name: e.key, total: e.value)).toList()
      ..sort((a, b) => b.total.compareTo(a.total));
  }

  Future<List<NamedTotal>> getByEmployee({required DateTime from, required DateTime to}) async {
    final storeId = CurrentStore.id;
    if (storeId == null) return [];
    final sales = await _client
        .from('sales')
        .select('user_id, total')
        .eq('store_id', storeId)
        .gte('created_at', from.toIso8601String())
        .lte('created_at', to.toIso8601String())
        .withTimeout();
    final salesList = (sales as List).cast<Map<String, dynamic>>();

    final totals = <String?, double>{};
    for (final s in salesList) {
      final userId = s['user_id'] as String?;
      final total = (s['total'] as num).toDouble();
      totals[userId] = (totals[userId] ?? 0) + total;
    }

    final userIds = totals.keys.whereType<String>().toList();
    final emailById = <String, String>{};
    if (userIds.isNotEmpty) {
      final profiles = await _client.from('profiles').select('id, email').inFilter('id', userIds);
      for (final p in (profiles as List).cast<Map<String, dynamic>>()) {
        emailById[p['id'] as String] = (p['email'] as String?) ?? 'Sin correo';
      }
    }

    return totals.entries.map((e) {
      final name = e.key != null ? (emailById[e.key] ?? 'Empleado eliminado') : 'Sin usuario';
      return NamedTotal(name: name, total: e.value);
    }).toList()
      ..sort((a, b) => b.total.compareTo(a.total));
  }

  /// Cuántas veces se usó cada modificador (no el ingreso exacto que generó,
  /// porque "sale_items" solo guarda el nombre del modificador en un texto,
  /// no su precio en el momento de la venta).
  Future<List<ModifierUsage>> getByModifier({required DateTime from, required DateTime to}) async {
    final saleIds = await _saleIdsInRange(from, to);
    if (saleIds.isEmpty) return [];

    final items = await _client
        .from('sale_items')
        .select('modifiers_summary, quantity')
        .inFilter('sale_id', saleIds)
        .not('modifiers_summary', 'is', null);

    final counts = <String, double>{};
    for (final item in (items as List).cast<Map<String, dynamic>>()) {
      final summary = item['modifiers_summary'] as String?;
      if (summary == null || summary.isEmpty) continue;
      final qty = (item['quantity'] as num).toDouble();
      for (final name in summary.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty)) {
        counts[name] = (counts[name] ?? 0) + qty;
      }
    }
    return counts.entries.map((e) => ModifierUsage(name: e.key, count: e.value)).toList()
      ..sort((a, b) => b.count.compareTo(a.count));
  }
}
