import 'package:flutter/material.dart';

import '../../models/cash_movement.dart';
import '../../models/cash_session.dart';
import '../../models/sale.dart';
import '../../services/cash_movement_repository.dart';
import '../../services/receipts_repository.dart';
import '../../utils/date_format_es.dart';
import '../../widgets/currency_text.dart';
import '../../widgets/number_pad_dialog.dart';

/// Detalle de tesorería de un turno: cuánto debería haber en la caja
/// (efectivo teórico) y el resumen de ventas por método de pago, como en
/// Loyverse. Sirve tanto para el turno abierto (con opción de registrar
/// depósitos/retiros) como para turnos ya cerrados (solo lectura).
class TurnoDetailSheet extends StatefulWidget {
  final CashSession session;

  const TurnoDetailSheet({super.key, required this.session});

  @override
  State<TurnoDetailSheet> createState() => _TurnoDetailSheetState();
}

class _TurnoDetailSheetState extends State<TurnoDetailSheet> {
  final ReceiptsRepository _receiptsRepository = ReceiptsRepository();
  final CashMovementRepository _movementRepository = CashMovementRepository();
  List<Sale> _sales = [];
  List<CashMovement> _movements = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      _receiptsRepository.getForSession(widget.session.id),
      _movementRepository.getForSession(widget.session.id),
    ]);
    setState(() {
      _sales = results[0] as List<Sale>;
      _movements = results[1] as List<CashMovement>;
      _loading = false;
    });
  }

  double get _grossSales => _sales.fold(0, (sum, s) => sum + s.subtotal);
  double get _discounts => _sales.fold(0, (sum, s) => sum + s.discountAmount);
  double get _netSales => _sales.fold(0, (sum, s) => sum + s.total);
  double get _cashSales => _sales.fold(0, (sum, s) => sum + s.cashAmount);
  double get _cardSales => _sales.fold(0, (sum, s) => sum + s.cardAmount);
  double get _otherSales => _sales.fold(0, (sum, s) => sum + s.otherAmount);
  double get _deposits =>
      _movements.where((m) => m.isDeposit).fold(0, (sum, m) => sum + m.amount);
  double get _withdrawals =>
      _movements.where((m) => !m.isDeposit).fold(0, (sum, m) => sum + m.amount);

  // Todavía no hay función de reembolsos en POSible.
  double get _refunds => 0;

  double get _theoreticalCash =>
      widget.session.openingAmount + _cashSales - _refunds + _deposits - _withdrawals;

  Future<void> _addMovement() async {
    final result = await showDialog<_MovementInput>(
      context: context,
      builder: (_) => const _MovementDialog(),
    );
    if (result == null) return;
    await _movementRepository.create(
      cashSessionId: widget.session.id,
      type: result.type,
      amount: result.amount,
      note: result.note,
    );
    _load();
  }

  Widget _row(String label, double value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: bold ? const TextStyle(fontWeight: FontWeight.bold) : null),
          CurrencyText(value, bold: bold),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        if (_loading) {
          return const Center(child: CircularProgressIndicator());
        }
        return ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              session.isOpen ? 'Turno abierto' : 'Detalle del turno',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(session.userEmail ?? '', style: const TextStyle(color: Colors.grey)),
            Text(
              'Apertura: ${formatDayHeaderEs(session.openedAt.toLocal())} ${formatTimeEs(session.openedAt.toLocal())}'
              '${session.closedAt != null ? '\nCierre: ${formatTimeEs(session.closedAt!.toLocal())}' : ''}',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Text('Cajón de efectivo', style: Theme.of(context).textTheme.titleMedium),
            const Divider(),
            _row('Fondo de caja anterior', session.openingAmount),
            _row('Cobros en efectivo', _cashSales),
            _row('Reembolsos en efectivo', _refunds),
            _row('Depositado', _deposits),
            _row('Pagos/Salidas', _withdrawals),
            const Divider(),
            _row('Efectivo teórico en caja', _theoreticalCash, bold: true),
            const SizedBox(height: 24),
            Text('Resumen de ventas', style: Theme.of(context).textTheme.titleMedium),
            const Divider(),
            _row('Ventas brutas', _grossSales),
            _row('Reembolsos', _refunds),
            _row('Descuentos', _discounts),
            const Divider(),
            _row('Ventas netas', _netSales, bold: true),
            const SizedBox(height: 8),
            _row('Efectivo', _cashSales),
            _row('Tarjeta', _cardSales),
            _row('Otro', _otherSales),
            if (session.isOpen) ...[
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: _addMovement,
                icon: const Icon(Icons.sync_alt),
                label: const Text('Registrar depósito o retiro de caja'),
              ),
            ],
            if (_movements.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Movimientos de caja', style: Theme.of(context).textTheme.titleMedium),
              const Divider(),
              ..._movements.map((m) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(m.isDeposit ? Icons.add_circle_outline : Icons.remove_circle_outline),
                    title: Text(m.isDeposit ? 'Depósito' : 'Pago/Salida'),
                    subtitle: Text(m.note?.isNotEmpty == true ? m.note! : formatTimeEs(m.createdAt.toLocal())),
                    trailing: CurrencyText(m.amount, bold: true),
                  )),
            ],
          ],
        );
      },
    );
  }
}

class _MovementInput {
  final String type;
  final double amount;
  final String? note;

  _MovementInput({required this.type, required this.amount, this.note});
}

class _MovementDialog extends StatefulWidget {
  const _MovementDialog();

  @override
  State<_MovementDialog> createState() => _MovementDialogState();
}

class _MovementDialogState extends State<_MovementDialog> {
  String _type = 'deposit';
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _confirm() {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) return;
    Navigator.of(context).pop(
      _MovementInput(type: _type, amount: amount, note: _noteController.text.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Movimiento de caja'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'deposit', label: Text('Depósito'), icon: Icon(Icons.add)),
              ButtonSegment(value: 'withdrawal', label: Text('Retiro'), icon: Icon(Icons.remove)),
            ],
            selected: {_type},
            onSelectionChanged: (value) => setState(() => _type = value.first),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountController,
            readOnly: true,
            decoration: const InputDecoration(labelText: 'Monto', border: OutlineInputBorder()),
            onTap: () async {
              final amount = await showNumberPadDialog(
                context,
                title: 'Monto',
                initialValue: double.tryParse(_amountController.text),
                prefixText: '\$',
                minValue: 1,
              );
              if (amount != null) setState(() => _amountController.text = amount.round().toString());
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteController,
            decoration: const InputDecoration(labelText: 'Nota (opcional)', border: OutlineInputBorder()),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton(onPressed: _confirm, child: const Text('Guardar')),
      ],
    );
  }
}
