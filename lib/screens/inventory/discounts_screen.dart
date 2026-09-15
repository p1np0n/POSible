import 'package:flutter/material.dart';

import '../../models/discount.dart';
import '../../services/discount_repository.dart';
import '../../utils/currency_format_cl.dart';
import '../../widgets/simple_crud_list_screen.dart';

class DiscountsScreen extends StatelessWidget {
  const DiscountsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = DiscountRepository();
    return SimpleCrudListScreen<Discount>(
      searchLabel: 'Buscar descuento',
      emptyMessage: 'No hay descuentos todavía',
      emptyIcon: Icons.percent_outlined,
      loadErrorPrefix: 'No se pudieron cargar los descuentos',
      load: repository.getAll,
      titleOf: (discount) => discount.name,
      subtitleOf: (discount) =>
          discount.isPercentage ? '${discount.value.toStringAsFixed(0)}%' : formatCurrencyCl(discount.value),
      activeOf: (discount) => discount.active,
      onToggleActive: (discount) => repository.update(
        discount.id,
        Discount(id: discount.id, name: discount.name, type: discount.type, value: discount.value, active: !discount.active),
      ),
      onAdd: (context) async {
        final result = await showDialog<Discount>(
          context: context,
          builder: (_) => const _DiscountDialog(),
        );
        if (result == null) return false;
        await repository.create(result);
        return true;
      },
      onDelete: (discount) => repository.delete(discount.id),
    );
  }
}

class _DiscountDialog extends StatefulWidget {
  const _DiscountDialog();

  @override
  State<_DiscountDialog> createState() => _DiscountDialogState();
}

class _DiscountDialogState extends State<_DiscountDialog> {
  final _nameController = TextEditingController();
  final _valueController = TextEditingController();
  String _type = 'percentage';

  @override
  void dispose() {
    _nameController.dispose();
    _valueController.dispose();
    super.dispose();
  }

  void _confirm() {
    final name = _nameController.text.trim();
    final value = double.tryParse(_valueController.text);
    if (name.isEmpty || value == null) return;
    Navigator.of(context).pop(Discount(id: '', name: name, type: _type, value: value, active: true));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nuevo descuento'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Nombre (ej. Promo verano)', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _type,
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'percentage', child: Text('Porcentaje %')),
                    DropdownMenuItem(value: 'fixed', child: Text('Monto fijo')),
                  ],
                  onChanged: (value) => setState(() => _type = value ?? 'percentage'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _valueController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: _type == 'percentage' ? 'Valor %' : 'Valor \$',
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton(onPressed: _confirm, child: const Text('Agregar')),
      ],
    );
  }
}
