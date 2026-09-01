import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/cash_session.dart';
import '../../models/sale.dart';
import '../../providers/cash_session_provider.dart';
import '../../services/cash_session_repository.dart';
import '../../services/receipts_repository.dart';
import '../../utils/date_format_es.dart';
import '../../widgets/currency_text.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_state.dart';
import '../../widgets/loading_indicator.dart';
import 'cash_session_sheet.dart';
import 'turno_detail_sheet.dart';

class TurnoScreen extends StatefulWidget {
  const TurnoScreen({super.key});

  @override
  State<TurnoScreen> createState() => _TurnoScreenState();
}

class _TurnoScreenState extends State<TurnoScreen> {
  final CashSessionRepository _repository = CashSessionRepository();
  final ReceiptsRepository _receiptsRepository = ReceiptsRepository();
  List<CashSession> _history = [];
  Map<String, double> _totalsBySession = {};
  bool _loading = true;
  String? _error;

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
    try {
      final results = await Future.wait([
        _repository.getHistory(),
        _receiptsRepository.getRecent(),
      ]);
      final history = results[0] as List<CashSession>;
      final sales = results[1] as List<Sale>;
      final totals = <String, double>{};
      for (final sale in sales) {
        final id = sale.cashSessionId;
        if (id == null) continue;
        totals[id] = (totals[id] ?? 0) + sale.total;
      }
      if (!mounted) return;
      setState(() {
        _history = history;
        _totalsBySession = totals;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo cargar el historial de turnos';
        _loading = false;
      });
    }
  }

  void _openCashSessionSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const CashSessionSheet(),
    ).then((_) => _load());
  }

  void _openTurnoDetail(CashSession session) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => TurnoDetailSheet(session: session),
    ).then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    final cashSession = context.watch<CashSessionProvider>();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cashSession.isOpen ? 'Caja abierta' : 'Caja cerrada',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (cashSession.isOpen && cashSession.current != null) ...[
                    const SizedBox(height: 8),
                    Text('Apertura: ${formatTimeEs(cashSession.current!.openedAt.toLocal())}'),
                    Row(
                      children: [
                        const Text('Monto de apertura: '),
                        CurrencyText(cashSession.current!.openingAmount),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          onPressed: _openCashSessionSheet,
                          child: Text(cashSession.isOpen ? 'Cerrar caja' : 'Abrir caja'),
                        ),
                      ),
                      if (cashSession.isOpen && cashSession.current != null) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _openTurnoDetail(cashSession.current!),
                            child: const Text('Ver detalle de caja'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text('Historial de turnos', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (_loading)
            const LoadingIndicator()
          else if (_error != null)
            ErrorState(message: _error!, onRetry: _load)
          else if (_history.isEmpty)
            const EmptyState(message: 'Todavía no hay turnos registrados', icon: Icons.schedule_outlined)
          else
            ..._history.map((session) {
              final total = _totalsBySession[session.id] ?? 0;
              return Card(
                child: ListTile(
                  leading: Icon(
                    session.isOpen ? Icons.lock_open : Icons.lock_outline,
                    color: session.isOpen ? Colors.green : Colors.grey.shade700,
                  ),
                  title: Text(session.userEmail ?? 'Desconocido'),
                  subtitle: Text(
                    'Apertura: ${formatDayHeaderEs(session.openedAt.toLocal())} ${formatTimeEs(session.openedAt.toLocal())}\n'
                    '${session.closedAt != null ? 'Cierre: ${formatTimeEs(session.closedAt!.toLocal())}' : 'Turno abierto'}',
                  ),
                  isThreeLine: true,
                  onTap: () => _openTurnoDetail(session),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('Ventas', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                      CurrencyText(total, bold: true),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
