import 'package:flutter/material.dart';

import '../../models/modifier.dart';
import '../../services/modifier_repository.dart';
import '../../utils/currency_format_cl.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_state.dart';
import '../../widgets/loading_indicator.dart';

class ModifiersScreen extends StatefulWidget {
  const ModifiersScreen({super.key});

  @override
  State<ModifiersScreen> createState() => _ModifiersScreenState();
}

class _ModifiersScreenState extends State<ModifiersScreen> {
  final ModifierRepository _repository = ModifierRepository();
  List<Modifier> _modifiers = [];
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
      final modifiers = await _repository.getAll();
      if (!mounted) return;
      setState(() {
        _modifiers = modifiers;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudieron cargar los modificadores';
        _loading = false;
      });
    }
  }

  List<Modifier> get _filtered => _modifiers
      .where((m) => _search.isEmpty || m.name.toLowerCase().contains(_search.toLowerCase()))
      .toList();

  Future<void> _add() async {
    final result = await showDialog<Modifier>(
      context: context,
      builder: (_) => const _ModifierDialog(),
    );
    if (result == null) return;
    await _repository.create(result);
    _load();
  }

  Future<void> _toggleActive(Modifier modifier) async {
    await _repository.update(
      modifier.id,
      Modifier(id: modifier.id, name: modifier.name, priceAdjustment: modifier.priceAdjustment, active: !modifier.active),
    );
    _load();
  }

  Future<void> _delete(Modifier modifier) async {
    await _repository.delete(modifier.id);
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Opciones para personalizar un producto al venderlo (ej. "Extra queso +\$500", '
                  '"Sin cebolla"). Si hay modificadores activos, al tocar un producto en Ventas '
                  'aparecerá primero la lista para elegir cuáles aplicar.',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(
                          labelText: 'Buscar modificador',
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
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const LoadingIndicator()
                : _error != null
                    ? ErrorState(message: _error!, onRetry: _load)
                    : _filtered.isEmpty
                        ? const EmptyState(message: 'No hay modificadores todavía', icon: Icons.tune)
                        : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _filtered.length,
                        itemBuilder: (context, index) {
                          final modifier = _filtered[index];
                          return Card(
                            child: ListTile(
                              title: Text(modifier.name),
                              subtitle: Text(
                                modifier.priceAdjustment >= 0
                                    ? '+${formatCurrencyCl(modifier.priceAdjustment)}'
                                    : '-${formatCurrencyCl(modifier.priceAdjustment.abs())}',
                              ),
                              leading: Switch(value: modifier.active, onChanged: (_) => _toggleActive(modifier)),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => _delete(modifier),
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
