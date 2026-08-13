import 'package:flutter/material.dart';

import '../../services/reports_repository.dart';
import '../../widgets/currency_text.dart';

enum ReportRange { today, week, month }

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final ReportsRepository _repository = ReportsRepository();
  ReportRange _range = ReportRange.today;
  SalesSummary? _summary;
  bool _loading = true;

  static const _paymentLabels = {
    'cash': 'Efectivo',
    'card': 'Tarjeta',
    'other': 'Otro',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  DateTime get _fromDate {
    final now = DateTime.now();
    switch (_range) {
      case ReportRange.today:
        return DateTime(now.year, now.month, now.day);
      case ReportRange.week:
        return DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
      case ReportRange.month:
        return DateTime(now.year, now.month, 1);
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final summary = await _repository.getSummary(from: _fromDate, to: DateTime.now());
    setState(() {
      _summary = summary;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<ReportRange>(
            segments: const [
              ButtonSegment(value: ReportRange.today, label: Text('Hoy')),
              ButtonSegment(value: ReportRange.week, label: Text('7 días')),
              ButtonSegment(value: ReportRange.month, label: Text('Este mes')),
            ],
            selected: {_range},
            onSelectionChanged: (value) {
              setState(() => _range = value.first);
              _load();
            },
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
          else if (_summary != null) ...[
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                      label: 'Ventas totales', child: CurrencyText(_summary!.totalSales, bold: true)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    label: 'Transacciones',
                    child: Text('${_summary!.transactionCount}',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _StatCard(label: 'Ticket promedio', child: CurrencyText(_summary!.averageTicket, bold: true)),
            const SizedBox(height: 16),
            Text('Por método de pago', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ..._summary!.byPaymentMethod.entries.map((entry) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(_paymentLabels[entry.key] ?? entry.key),
                  trailing: CurrencyText(entry.value, bold: true),
                )),
            const SizedBox(height: 16),
            Text('Productos más vendidos', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (_summary!.topProducts.isEmpty)
              const Text('Sin ventas en este período')
            else
              ..._summary!.topProducts.map((product) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(product.name),
                    subtitle: Text('${product.quantity.toStringAsFixed(0)} unidades'),
                    trailing: CurrencyText(product.total, bold: true),
                  )),
          ],
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final Widget child;

  const _StatCard({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}
