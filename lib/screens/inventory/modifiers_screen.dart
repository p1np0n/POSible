import 'package:flutter/material.dart';

import '../../models/modifier.dart';
import '../../services/modifier_repository.dart';

class ModifiersScreen extends StatefulWidget {
  const ModifiersScreen({super.key});

  @override
  State<ModifiersScreen> createState() => _ModifiersScreenState();
}

class _ModifiersScreenState extends State<ModifiersScreen> {
  final ModifierRepository _repository = ModifierRepository();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  List<Modifier> _modifiers = [];
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final modifiers = await _repository.getAll();
    setState(() {
      _modifiers = modifiers;
      _loading = false;
    });
  }

  Future<void> _add() async {
    final name = _nameController.text.trim();
    final price = double.tryParse(_priceController.text) ?? 0;
    if (name.isEmpty) return;
    setState(() => _saving = true);
    await _repository.create(Modifier(id: '', name: name, priceAdjustment: price, active: true));
    _nameController.clear();
    _priceController.clear();
    setState(() => _saving = false);
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
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Opciones para personalizar un producto al venderlo (ej. "Extra queso +\$500", '
            '"Sin cebolla"). Todavía no se aplican en el carrito de Ventas — por ahora puedes '
            'crearlas y las conectamos con el checkout más adelante.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Nombre (ej. Extra queso)', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _priceController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                  decoration: const InputDecoration(
                    labelText: 'Ajuste de precio (ej. 500 o -500)',
                    border: OutlineInputBorder(),
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
          else if (_modifiers.isEmpty)
            const Text('No hay modificadores todavía')
          else
            ..._modifiers.map((modifier) => Card(
                  child: ListTile(
                    title: Text(modifier.name),
                    subtitle: Text(
                      modifier.priceAdjustment >= 0
                          ? '+\$${modifier.priceAdjustment.toStringAsFixed(2)}'
                          : '-\$${modifier.priceAdjustment.abs().toStringAsFixed(2)}',
                    ),
                    leading: Switch(value: modifier.active, onChanged: (_) => _toggleActive(modifier)),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _delete(modifier),
                    ),
                  ),
                )),
        ],
      ),
    );
  }
}
