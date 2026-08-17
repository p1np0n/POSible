import 'package:flutter/material.dart';

import '../../services/reports_repository.dart';
import '../../widgets/currency_text.dart';

enum ReportRange { today, week, month, custom }

String _formatDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final ReportsRepository _repository = ReportsRepository();
  ReportRange _range = ReportRange.today;
  DateTimeRange? _customRange;
  SalesSummary? _summary;
  double? _previousTotal;
  List<NamedTotal> _byCategory = [];
  List<NamedTotal> _byEmployee = [];
  List<ModifierUsage> _byModifier = [];
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
      case ReportRange.custom:
        return _customRange?.start ?? DateTime(now.year, now.month, now.day);
    }
  }

  DateTime get _toDate {
    if (_range == ReportRange.custom && _customRange != null) {
      final end = _customRange!.end;
      return DateTime(end.year, end.month, end.day, 23, 59, 59);
    }
    return DateTime.now();
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: now,
      initialDateRange: _customRange ?? DateTimeRange(start: _fromDate, end: now),
    );
    if (picked == null) return;
    setState(() {
      _range = ReportRange.custom;
      _customRange = picked;
    });
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final from = _fromDate;
    final to = _toDate;
    final duration = to.difference(from);
    final previousTo = from.subtract(const Duration(seconds: 1));
    final previousFrom = previousTo.subtract(duration);

    final results = await Future.wait([
      _repository.getSummary(from: from, to: to),
      _repository.getTotalSales(from: previousFrom, to: previousTo),
      _repository.getByCategory(from: from, to: to),
      _repository.getByEmployee(from: from, to: to),
      _repository.getByModifier(from: from, to: to),
    ]);
    if (!mounted) return;
    setState(() {
      _summary = results[0] as SalesSummary;
      _previousTotal = results[1] as double;
      _byCategory = results[2] as List<NamedTotal>;
      _byEmployee = results[3] as List<NamedTotal>;
      _byModifier = results[4] as List<ModifierUsage>;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary;
    final previous = _previousTotal;
    final percentChange = (summary != null && previous != null && previous > 0)
        ? ((summary.totalSales - previous) / previous) * 100
        : null;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SegmentedButton<ReportRange>(
                segments: const [
                  ButtonSegment(value: ReportRange.today, label: Text('Hoy')),
                  ButtonSegment(value: ReportRange.week, label: Text('7 días')),
                  ButtonSegment(value: ReportRange.month, label: Text('Este mes')),
                ],
                selected: {_range == ReportRange.custom ? ReportRange.today : _range},
                onSelectionChanged: (value) {
                  setState(() => _range = value.first);
                  _load();
                },
              ),
              OutlinedButton.icon(
                onPressed: _pickCustomRange,
                icon: const Icon(Icons.date_range),
                label: Text(_range == ReportRange.custom && _customRange != null
                    ? '${_formatDate(_customRange!.start)} - ${_formatDate(_customRange!.end)}'
                    : 'Rango personalizado'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
          else if (summary != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _StatCard(
                    label: 'Ventas totales',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CurrencyText(summary.totalSales, bold: true),
                        if (percentChange != null)
                          Text(
                            '${percentChange >= 0 ? '+' : ''}${percentChange.toStringAsFixed(1)}% vs período anterior',
                            style: TextStyle(
                              fontSize: 12,
                              color: percentChange >= 0 ? Colors.green : Colors.red,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    label: 'Transacciones',
                    child: Text('${summary.transactionCount}',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _StatCard(label: 'Ticket promedio', child: CurrencyText(summary.averageTicket, bold: true)),
            if (summary.dailyTotals.length > 1) ...[
              const SizedBox(height: 16),
              Text('Ventas por día', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              _DailyBarChart(dailyTotals: summary.dailyTotals),
            ],
            const SizedBox(height: 16),
            Text('Por método de pago', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...summary.byPaymentMethod.entries.map((entry) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(_paymentLabels[entry.key] ?? entry.key),
                  trailing: CurrencyText(entry.value, bold: true),
                )),
            const SizedBox(height: 16),
            Text('Productos más vendidos', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (summary.topProducts.isEmpty)
              const Text('Sin ventas en este período')
            else
              ...summary.topProducts.map((product) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(product.name),
                    subtitle: Text('${product.quantity.toStringAsFixed(0)} unidades'),
                    trailing: CurrencyText(product.total, bold: true),
                  )),
            const SizedBox(height: 16),
            Text('Por categoría', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (_byCategory.isEmpty)
              const Text('Sin ventas en este período')
            else
              ..._byCategory.map((c) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(c.name),
                    trailing: CurrencyText(c.total, bold: true),
                  )),
            const SizedBox(height: 16),
            Text('Por empleado', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (_byEmployee.isEmpty)
              const Text('Sin ventas en este período')
            else
              ..._byEmployee.map((e) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(e.name),
                    trailing: CurrencyText(e.total, bold: true),
                  )),
            if (_byModifier.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Por modificador', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              ..._byModifier.map((m) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(m.name),
                    trailing: Text('${m.count.toStringAsFixed(0)} veces'),
                  )),
            ],
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

/// Gráfico de barras simple hecho con widgets básicos (sin dependencias
/// nuevas): una barra por día, con su altura proporcional a la venta del día.
class _DailyBarChart extends StatelessWidget {
  final List<DailyTotal> dailyTotals;

  const _DailyBarChart({required this.dailyTotals});

  @override
  Widget build(BuildContext context) {
    final maxTotal = dailyTotals.map((d) => d.total).fold<double>(0, (a, b) => a > b ? a : b);
    const chartHeight = 120.0;

    return SizedBox(
      height: chartHeight + 32,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: dailyTotals.map((d) {
            final barHeight = maxTotal == 0 ? 0.0 : (d.total / maxTotal) * chartHeight;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    width: 28,
                    height: barHeight < 2 ? 2 : barHeight,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(_formatDate(d.date), style: const TextStyle(fontSize: 10)),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
