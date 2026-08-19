import 'package:flutter/material.dart';

import '../../models/product.dart';

/// Diálogo para ponerle nombre y precio propios a un botón de venta rápida
/// (ej. "Huevos 5x1000") antes de agregarlo a una pestaña, o para editar
/// uno que ya está agregado — como en Loyverse, el botón puede mostrar un
/// nombre y precio distintos del producto real que tiene detrás.
///
/// Devuelve `(nombre, precio)` — cualquiera de los dos en null si se deja
/// igual al del producto (no se guarda personalización para ese campo), o
/// null si se cancela.
Future<(String?, double?)?> showPageItemCustomizeDialog(
  BuildContext context, {
  required Product product,
  String? initialName,
  double? initialPrice,
}) {
  final allowCustomPrice = !product.isVariablePrice && !product.isSoldByWeight;
  final nameController = TextEditingController(text: initialName ?? product.name);
  final priceController = TextEditingController(
    text: (initialPrice ?? product.price).round().toString(),
  );

  return showDialog<(String?, double?)>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Botón de venta rápida'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nameController,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Nombre del botón', border: OutlineInputBorder()),
          ),
          if (allowCustomPrice) ...[
            const SizedBox(height: 12),
            TextField(
              controller: priceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Precio', border: OutlineInputBorder()),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () {
            final name = nameController.text.trim();
            final customName = (name.isEmpty || name == product.name) ? null : name;
            double? customPrice;
            if (allowCustomPrice) {
              final price = double.tryParse(priceController.text);
              customPrice = (price == null || price == product.price) ? null : price;
            }
            Navigator.of(context).pop((customName, customPrice));
          },
          child: const Text('Guardar'),
        ),
      ],
    ),
  );
}
