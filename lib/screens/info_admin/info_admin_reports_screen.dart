import 'package:flutter/material.dart';

import '../../services/reports_repository.dart';
import '../../utils/currency_format_cl.dart';
import '../../widgets/currency_text.dart';
import '../../widgets/error_state.dart';
import '../../widgets/loading_indicator.dart';

/// "Reportes" de Info Admin: el total vendido hoy, hasta el momento en que
/// se actualiza, más cuánto se pagó con efectivo/tarjeta/otro y cuánto se
/// vendió por categoría — sin rangos de fecha ni el resto de los desgloses
/// del panel completo, para revisar de un vistazo cómo va el día.
class InfoAdminReportsScreen extends StatefulWidget {
  const InfoAdminReportsScreen({super.key});

  @override
  State<InfoAdminReportsScreen> createState() => _InfoAdminReportsScreenState();
}

class _InfoAdminReportsScreenState extends State<InfoAdminReportsScreen> {
  final ReportsRepository _repository = ReportsRepository();
  SalesSummary? _summary;
  List<NamedTotal> _byCategory = [];
  DateTime? _updatedAt;
  bool _loading = true;
  String? _error;

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

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final now = DateTime.now();
    final from = DateTime(now.year, now.month, now.day);
    try {
      final results = await Future.wait([
        _repository.getSummary(from: from, to: now),
        _repository.getByCategory(from: from, to: now),
      ]);
      if (!mounted) return;
      setState(() {
        _summary = results[0] as SalesSummary;
        _byCategory = results[1] as List<NamedTotal>;
        _updatedAt = DateTime.now();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo cargar el total de hoy';
        _loading = false;
      });
    }
  }

  String _formatTime(DateTime time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingIndicator();
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);

    final summary = _summary!;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 24),
          const Text('Ventas de hoy', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: CurrencyText(
              summary.totalSales,
              bold: true,
              style: TextStyle(fontSize: 56, color: Theme.of(context).colorScheme.primary),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Column(
                children: [
                  Text(formatNumberCl(summary.transactionCount), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const Text('Ventas', style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
              Column(
                children: [
                  CurrencyText(summary.averageTicket, bold: true, style: const TextStyle(fontSize: 22)),
                  const Text('Ticket promedio', style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 32),
          Text('Por método de pago', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (summary.byPaymentMethod.isEmpty)
            const Text('Sin ventas todavía', style: TextStyle(color: Colors.grey))
          else
            ...summary.byPaymentMethod.entries.map((entry) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_paymentLabels[entry.key] ?? entry.key),
                      CurrencyText(entry.value, bold: true),
                    ],
                  ),
                )),
          const SizedBox(height: 24),
          Text('Por categoría', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (_byCategory.isEmpty)
            const Text('Sin ventas todavía', style: TextStyle(color: Colors.grey))
          else
            ..._byCategory.map((c) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(c.name),
                      CurrencyText(c.total, bold: true),
                    ],
                  ),
                )),
          const SizedBox(height: 24),
          if (_updatedAt != null)
            Text(
              'Actualizado a las ${_formatTime(_updatedAt!)}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            label: const Text('Actualizar'),
          ),
        ],
      ),
    );
  }
}
