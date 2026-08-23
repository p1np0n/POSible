import 'package:flutter/material.dart';

import '../../models/discount.dart';
import '../../services/discount_repository.dart';
import '../../utils/currency_format_cl.dart';
import '../../utils/search_normalize.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_state.dart';
import '../../widgets/loading_indicator.dart';

class DiscountsScreen extends StatefulWidget {
  const DiscountsScreen({super.key});

  @override
  State<DiscountsScreen> createState() => _DiscountsScreenState();
}

class _DiscountsScreenState extends State<DiscountsScreen> {
  final DiscountRepository _repository = DiscountRepository();
  List<Discount> _discounts = [];
  bool _loading = true;
  String _search = '';
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
      final discounts = await _repository.getAll();
      if (!mounted) return;
      setState(() {
        _discounts = discounts;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudieron cargar los descuentos';
        _loading = false;
      });
    }
  }

  List<Discount> get _filtered => _discounts
      .where((d) => _search.isEmpty || normalizeForSearch(d.name).contains(normalizeForSearch(_search)))
      .toList();

  Future<void> _add() async {
    final result = await showDialog<Discount>(
      context: context,
      builder: (_) => const _DiscountDialog(),
    );
    if (result == null) return;
    await _repository.create(result);
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
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Buscar descuento',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (value) => setState(() => _search = value),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _add,
                  icon: const Icon(Icons.add),
                  label: const Text('Nuevo'),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const LoadingIndicator()
                : _error != null
                    ? ErrorState(message: _error!, onRetry: _load)
                    : _filtered.isEmpty
                        ? const EmptyState(message: 'No hay descuentos todavía', icon: Icons.percent_outlined)
                        : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _filtered.length,
                        itemBuilder: (context, index) {
                          final discount = _filtered[index];
                          final valueLabel = discount.isPercentage
                              ? '${discount.value.toStringAsFixed(0)}%'
                              : formatCurrencyCl(discount.value);
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
                        },
                      ),
          ),
        ],
      ),
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
