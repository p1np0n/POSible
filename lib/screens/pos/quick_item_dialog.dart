import 'package:flutter/material.dart';

import '../../models/product.dart';

/// Diálogo para agregar al carrito un ítem con nombre y precio libres,
/// sin que esté cargado en el inventario (ej. algo pesado en el momento,
/// un cargo especial, un producto que todavía no registraste).
class QuickItemDialog extends StatefulWidget {
  const QuickItemDialog({super.key});

  @override
  State<QuickItemDialog> createState() => _QuickItemDialogState();
}

class _QuickItemDialogState extends State<QuickItemDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _confirm() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      Product.quickItem(
        name: _nameController.text.trim(),
        price: double.parse(_priceController.text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Artículo rápido'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Nombre', border: OutlineInputBorder()),
              validator: (value) => (value == null || value.trim().isEmpty) ? 'Requerido' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _priceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Precio', border: OutlineInputBorder()),
              validator: (value) => (double.tryParse(value ?? '') == null) ? 'Precio inválido' : null,
              onFieldSubmitted: (_) => _confirm(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton(onPressed: _confirm, child: const Text('Agregar')),
      ],
    );
  }
}
