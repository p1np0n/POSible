import 'package:flutter/material.dart';

import '../../models/modifier.dart';
import '../../models/product.dart';
import '../../utils/currency_format_cl.dart';
import '../../widgets/currency_text.dart';

/// Hoja para elegir modificadores (ej. "Extra queso") antes de agregar un
/// producto al carrito. Devuelve la lista de modificadores elegidos.
class ModifierPickerSheet extends StatefulWidget {
  final Product product;
  final List<Modifier> modifiers;

  const ModifierPickerSheet({super.key, required this.product, required this.modifiers});

  @override
  State<ModifierPickerSheet> createState() => _ModifierPickerSheetState();
}

class _ModifierPickerSheetState extends State<ModifierPickerSheet> {
  final Set<String> _selectedIds = {};

  @override
  Widget build(BuildContext context) {
    final selected = widget.modifiers.where((m) => _selectedIds.contains(m.id)).toList();
    final total = widget.product.price + selected.fold<double>(0, (sum, m) => sum + m.priceAdjustment);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Text(widget.product.name, style: Theme.of(context).textTheme.titleLarge),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                children: widget.modifiers.map((modifier) {
                  return CheckboxListTile(
                    title: Text(modifier.name),
                    subtitle: Text(
                      modifier.priceAdjustment >= 0
                          ? '+${formatCurrencyCl(modifier.priceAdjustment)}'
                          : '-${formatCurrencyCl(modifier.priceAdjustment.abs())}',
                    ),
                    value: _selectedIds.contains(modifier.id),
                    onChanged: (checked) {
                      setState(() {
                        if (checked ?? false) {
                          _selectedIds.add(modifier.id);
                        } else {
                          _selectedIds.remove(modifier.id);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [const Text('Total: '), CurrencyText(total, bold: true)],
                    ),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(selected),
                    child: const Text('Agregar al carrito'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
