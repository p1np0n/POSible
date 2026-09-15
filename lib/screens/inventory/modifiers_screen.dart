import 'package:flutter/material.dart';

import '../../models/modifier.dart';
import '../../services/modifier_repository.dart';
import '../../utils/currency_format_cl.dart';
import '../../widgets/simple_crud_list_screen.dart';

class ModifiersScreen extends StatelessWidget {
  const ModifiersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = ModifierRepository();
    return SimpleCrudListScreen<Modifier>(
      searchLabel: 'Buscar modificador',
      emptyMessage: 'No hay modificadores todavía',
      emptyIcon: Icons.tune,
      infoText: 'Opciones para personalizar un producto al venderlo (ej. "Extra queso +\$500", '
          '"Sin cebolla"). Si hay modificadores activos, al tocar un producto en Ventas '
          'aparecerá primero la lista para elegir cuáles aplicar.',
      loadErrorPrefix: 'No se pudieron cargar los modificadores',
      load: repository.getAll,
      titleOf: (modifier) => modifier.name,
      subtitleOf: (modifier) => modifier.priceAdjustment >= 0
          ? '+${formatCurrencyCl(modifier.priceAdjustment)}'
          : '-${formatCurrencyCl(modifier.priceAdjustment.abs())}',
      activeOf: (modifier) => modifier.active,
      onToggleActive: (modifier) => repository.update(
        modifier.id,
        Modifier(id: modifier.id, name: modifier.name, priceAdjustment: modifier.priceAdjustment, active: !modifier.active),
      ),
      onAdd: (context) async {
        final result = await showDialog<Modifier>(
          context: context,
          builder: (_) => const _ModifierDialog(),
        );
        if (result == null) return false;
        await repository.create(result);
        return true;
      },
      onDelete: (modifier) => repository.delete(modifier.id),
    );
  }
}

class _ModifierDialog extends StatefulWidget {
  const _ModifierDialog();

  @override
  State<_ModifierDialog> createState() => _ModifierDialogState();
}

class _ModifierDialogState extends State<_ModifierDialog> {
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _confirm() {
    final name = _nameController.text.trim();
    final price = double.tryParse(_priceController.text) ?? 0;
    if (name.isEmpty) return;
    Navigator.of(context).pop(Modifier(id: '', name: name, priceAdjustment: price, active: true));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nuevo modificador'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Nombre (ej. Extra queso)', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _priceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
            decoration: const InputDecoration(
              labelText: 'Ajuste de precio (ej. 500 o -500)',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _confirm(),
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
