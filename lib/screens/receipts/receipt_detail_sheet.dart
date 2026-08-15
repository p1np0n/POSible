import 'package:flutter/material.dart';

import '../../models/sale.dart';
import '../../models/sale_item.dart';
import '../../services/receipts_repository.dart';
import '../../utils/date_format_es.dart';
import '../../widgets/currency_text.dart';

class ReceiptDetailSheet extends StatefulWidget {
  final Sale sale;

  const ReceiptDetailSheet({super.key, required this.sale});

  @override
  State<ReceiptDetailSheet> createState() => _ReceiptDetailSheetState();
}

class _ReceiptDetailSheetState extends State<ReceiptDetailSheet> {
  final ReceiptsRepository _repository = ReceiptsRepository();
  List<SaleItem> _items = [];
  bool _loading = true;

  static const _paymentLabels = {'cash': 'Efectivo', 'card': 'Tarjeta', 'other': 'Otro', 'mixed': 'Pago dividido'};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await _repository.getItems(widget.sale.id);
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final sale = widget.sale;
    final createdAtLocal = sale.createdAt.toLocal();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(16),
            children: [
              Text('Recibo #${sale.receiptNumber}', style: Theme.of(context).textTheme.titleLarge),
              Text(
                '${formatDayHeaderEs(createdAtLocal)} · ${formatTimeEs(createdAtLocal)}',
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              if (_loading)
                const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
              else
                ..._items.map((item) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(item.productName),
                      subtitle: Text(
                        item.modifiersSummary == null || item.modifiersSummary!.isEmpty
                            ? '${item.quantity.toStringAsFixed(0)} x \$${item.unitPrice.toStringAsFixed(2)}'
                            : '${item.quantity.toStringAsFixed(0)} x \$${item.unitPrice.toStringAsFixed(2)} · ${item.modifiersSummary}',
                      ),
                      trailing: CurrencyText(item.subtotal, bold: true),
                    )),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [const Text('Subtotal'), CurrencyText(sale.subtotal)],
              ),
              if (sale.discountAmount > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [const Text('Descuento'), Text('-\$${sale.discountAmount.toStringAsFixed(2)}')],
                  ),
                ),
              if (sale.taxAmount > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [const Text('Impuesto'), CurrencyText(sale.taxAmount)],
                  ),
                ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  CurrencyText(sale.total, bold: true, style: const TextStyle(fontSize: 20)),
                ],
              ),
              const SizedBox(height: 8),
              Text('Pago: ${_paymentLabels[sale.paymentMethod] ?? sale.paymentMethod}'),
              if (sale.isSplitPayment) ...[
                if (sale.cashAmount > 0) Text('  · Efectivo: \$${sale.cashAmount.toStringAsFixed(2)}'),
                if (sale.cardAmount > 0) Text('  · Tarjeta: \$${sale.cardAmount.toStringAsFixed(2)}'),
                if (sale.otherAmount > 0) Text('  · Otro: \$${sale.otherAmount.toStringAsFixed(2)}'),
              ],
            ],
          );
        },
      ),
    );
  }
}
