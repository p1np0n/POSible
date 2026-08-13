import 'package:flutter/material.dart';

import '../../models/discount.dart';
import '../../services/discount_repository.dart';

class DiscountPickerDialog extends StatefulWidget {
  const DiscountPickerDialog({super.key});

  @override
  State<DiscountPickerDialog> createState() => _DiscountPickerDialogState();
}

class _DiscountPickerDialogState extends State<DiscountPickerDialog> {
  final DiscountRepository _repository = DiscountRepository();
  List<Discount> _discounts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final discounts = await _repository.getAll(onlyActive: true);
    setState(() {
      _discounts = discounts;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Elegir descuento'),
      content: SizedBox(
        width: double.maxFinite,
        height: 320,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: const Text('Sin descuento'),
                    onTap: () => Navigator.of(context).pop(Discount.none),
                  ),
                  Expanded(
                    child: _discounts.isEmpty
                        ? const Center(child: Text('No hay descuentos activos'))
                        : ListView.builder(
                            itemCount: _discounts.length,
                            itemBuilder: (context, index) {
                              final discount = _discounts[index];
                              final valueLabel = discount.isPercentage
                                  ? '${discount.value.toStringAsFixed(0)}%'
                                  : '\$${discount.value.toStringAsFixed(2)}';
                              return ListTile(
                                title: Text(discount.name),
                                subtitle: Text(valueLabel),
                                onTap: () => Navigator.of(context).pop(discount),
                              );
                            },
                          ),
                  ),
                ],
              ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
      ],
    );
  }
}
