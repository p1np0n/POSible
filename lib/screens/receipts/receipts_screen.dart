import 'package:flutter/material.dart';

import '../../models/sale.dart';
import '../../services/receipts_repository.dart';
import '../../utils/date_format_es.dart';
import '../../widgets/currency_text.dart';
import 'receipt_detail_sheet.dart';

class ReceiptsScreen extends StatefulWidget {
  const ReceiptsScreen({super.key});

  @override
  State<ReceiptsScreen> createState() => _ReceiptsScreenState();
}

class _ReceiptsScreenState extends State<ReceiptsScreen> {
  final ReceiptsRepository _repository = ReceiptsRepository();
  List<Sale> _sales = [];
  String _search = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final sales = await _repository.getRecent();
    setState(() {
      _sales = sales;
      _loading = false;
    });
  }

  List<Sale> get _filtered {
    if (_search.isEmpty) return _sales;
    return _sales.where((s) => s.receiptNumber.toString().contains(_search)).toList();
  }

  Map<String, List<Sale>> get _grouped {
    final groups = <String, List<Sale>>{};
    for (final sale in _filtered) {
      final local = sale.createdAt.toLocal();
      final key = formatDayHeaderEs(local);
      groups.putIfAbsent(key, () => []).add(sale);
    }
    return groups;
  }

  IconData _paymentIcon(String method) {
    switch (method) {
      case 'card':
        return Icons.credit_card;
      case 'other':
        return Icons.more_horiz;
      default:
        return Icons.payments;
    }
  }

  void _openDetail(Sale sale) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => ReceiptDetailSheet(sale: sale),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groups = _grouped;

    return RefreshIndicator(
      onRefresh: _load,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Buscar por número de recibo',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) => setState(() => _search = value),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : groups.isEmpty
                    ? const Center(child: Text('No hay recibos'))
                    : ListView(
                        children: groups.entries.map((entry) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                                child: Text(
                                  entry.key,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              ...entry.value.map((sale) => ListTile(
                                    leading: Icon(_paymentIcon(sale.paymentMethod)),
                                    title: CurrencyText(sale.total, bold: true),
                                    subtitle: Text(formatTimeEs(sale.createdAt.toLocal())),
                                    trailing: Text('#${sale.receiptNumber}'),
                                    onTap: () => _openDetail(sale),
                                  )),
                            ],
                          );
                        }).toList(),
                      ),
          ),
        ],
      ),
    );
  }
}
