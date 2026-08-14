import 'package:flutter/material.dart';

import '../../models/discount.dart';
import '../../services/discount_repository.dart';

class DiscountsScreen extends StatefulWidget {
  const DiscountsScreen({super.key});

  @override
  State<DiscountsScreen> createState() => _DiscountsScreenState();
}

class _DiscountsScreenState extends State<DiscountsScreen> {
  final DiscountRepository _repository = DiscountRepository();
  final _nameController = TextEditingController();
  final _valueController = TextEditingController();
  String _type = 'percentage';
  List<Discount> _discounts = [];
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final discounts = await _repository.getAll();
    setState(() {
      _discounts = discounts;
      _loading = false;
    });
  }

  Future<void> _add() async {
    final name = _nameController.text.trim();
    final value = double.tryParse(_valueController.text);
    if (name.isEmpty || value == null) return;
    setState(() => _saving = true);
    await _repository.create(Discount(id: '', name: name, type: _type, value: value, active: true));
    _nameController.clear();
    _valueController.clear();
    setState(() => _saving = false);
    _load();
  }

  Future<void> _toggleActive(Discount discount) async {
    await _repository.update(
      discount.id,
      Discount(id: discount.id, name: discount.name, type: discount.type, value: discount.value, active: !discount.active),
    );
    _load();
  }

  Future<void> _delete(Discount discount) async {
    await _repository.delete(discount.id);
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _valueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Nombre (ej. Promo verano)', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 8),
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
              const SizedBox(width: 8),
              IconButton.filled(
                icon: _saving
                    ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.add),
                onPressed: _saving ? null : _add,
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
          else if (_discounts.isEmpty)
            const Text('No hay descuentos todavía')
          else
            ..._discounts.map((discount) {
              final valueLabel =
                  discount.isPercentage ? '${discount.value.toStringAsFixed(0)}%' : '\$${discount.value.toStringAsFixed(2)}';
              return Card(
                child: ListTile(
                  title: Text(discount.name),
                  subtitle: Text(valueLabel),
                  leading: Switch(value: discount.active, onChanged: (_) => _toggleActive(discount)),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _delete(discount),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
