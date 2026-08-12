import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/cash_session_provider.dart';

class CashSessionSheet extends StatefulWidget {
  const CashSessionSheet({super.key});

  @override
  State<CashSessionSheet> createState() => _CashSessionSheetState();
}

class _CashSessionSheetState extends State<CashSessionSheet> {
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  bool _loading = false;

  Future<void> _openSession() async {
    final amount = double.tryParse(_amountController.text) ?? 0;
    setState(() => _loading = true);
    try {
      await context.read<CashSessionProvider>().open(amount);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _closeSession() async {
    final amount = double.tryParse(_amountController.text) ?? 0;
    setState(() => _loading = true);
    try {
      await context
          .read<CashSessionProvider>()
          .close(closingAmount: amount, notes: _notesController.text);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _loading = false);
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cashSession = context.watch<CashSessionProvider>();
    final isOpen = cashSession.isOpen;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(isOpen ? 'Cerrar caja' : 'Abrir caja', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: isOpen ? 'Monto de cierre (efectivo contado)' : 'Monto de apertura',
              border: const OutlineInputBorder(),
            ),
          ),
          if (isOpen) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: 'Notas (opcional)', border: OutlineInputBorder()),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _loading ? null : (isOpen ? _closeSession : _openSession),
            child: _loading
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(isOpen ? 'Cerrar caja' : 'Abrir caja'),
          ),
        ],
      ),
    );
  }
}
