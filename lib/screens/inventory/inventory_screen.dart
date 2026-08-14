import 'package:flutter/material.dart';

import '../../config/shared_catalog_config.dart';
import '../../models/catalog_entry.dart';
import '../../services/shared_catalog_repository.dart';

/// Catálogo de productos COMPARTIDO entre TODAS las tiendas que usan
/// POSible (no solo la tuya). Vive en un proyecto de Supabase separado —
/// ver lib/config/shared_catalog_config.dart y sql/shared_catalog_schema.sql.
class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final SharedCatalogRepository _repository = SharedCatalogRepository();
  final _searchController = TextEditingController();
  List<CatalogEntry> _entries = [];
  bool _loading = true;
  String _search = '';

  @override
  void initState() {
    super.initState();
    if (SharedCatalogConfig.isConfigured) _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final entries = await _repository.getAll(search: _search);
    setState(() {
      _entries = entries;
      _loading = false;
    });
  }

  Future<void> _openForm({CatalogEntry? entry}) async {
    final result = await showDialog<CatalogEntry>(
      context: context,
      builder: (_) => _CatalogEntryDialog(entry: entry),
    );
    if (result == null) return;
    if (entry == null) {
      await _repository.create(result);
    } else {
      await _repository.update(entry.barcode, result);
    }
    _load();
  }

  Future<void> _delete(CatalogEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar producto'),
        content: Text(
          '¿Seguro que quieres eliminar "${entry.name}" del catálogo compartido? '
          'Esto afecta a TODAS las tiendas que usan POSible, no solo la tuya.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirmed != true) return;
    await _repository.deleteByBarcode(entry.barcode);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (!SharedCatalogConfig.isConfigured) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 48, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                'El catálogo compartido todavía no está configurado.',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Este menú maneja la base de datos de artículos compartida entre '
                'todas las tiendas que usan POSible. Para activarla, sigue los pasos '
                'de "Catálogo compartido" en LEEME.md (crear un proyecto de Supabase '
                'aparte y correr sql/shared_catalog_schema.sql).',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

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
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: 'Buscar por nombre, marca o código de barras',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (value) {
                      _search = value;
                      _load();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: () => _openForm(),
                  icon: const Icon(Icons.add),
                  label: const Text('Nuevo'),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _entries.isEmpty
                    ? const Center(child: Text('No hay productos en el catálogo compartido'))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _entries.length,
                        itemBuilder: (context, index) {
                          final entry = _entries[index];
                          return Card(
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundImage:
                                    entry.imageUrl != null ? NetworkImage(entry.imageUrl!) : null,
                                child: entry.imageUrl == null ? const Icon(Icons.inventory_2) : null,
                              ),
                              title: Text(entry.name),
                              subtitle: Text(
                                [entry.brand, entry.barcode].where((s) => s != null && s.isNotEmpty).join(' · '),
                              ),
                              onTap: () => _openForm(entry: entry),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => _delete(entry),
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

class _CatalogEntryDialog extends StatefulWidget {
  final CatalogEntry? entry;

  const _CatalogEntryDialog({this.entry});

  @override
  State<_CatalogEntryDialog> createState() => _CatalogEntryDialogState();
}

class _CatalogEntryDialogState extends State<_CatalogEntryDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _barcodeController;
  late final TextEditingController _nameController;
  late final TextEditingController _brandController;
  late final TextEditingController _imageUrlController;

  bool get _isEditing => widget.entry != null;

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    _barcodeController = TextEditingController(text: entry?.barcode ?? '');
    _nameController = TextEditingController(text: entry?.name ?? '');
    _brandController = TextEditingController(text: entry?.brand ?? '');
    _imageUrlController = TextEditingController(text: entry?.imageUrl ?? '');
  }

  @override
  void dispose() {
    _barcodeController.dispose();
    _nameController.dispose();
    _brandController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  void _confirm() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      CatalogEntry(
        barcode: _barcodeController.text.trim(),
        name: _nameController.text.trim(),
        brand: _brandController.text.trim().isEmpty ? null : _brandController.text.trim(),
        imageUrl: _imageUrlController.text.trim().isEmpty ? null : _imageUrlController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Editar producto compartido' : 'Nuevo producto compartido'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _barcodeController,
                enabled: !_isEditing,
                decoration: const InputDecoration(labelText: 'Código de barras', border: OutlineInputBorder()),
                validator: (value) => (value == null || value.trim().isEmpty) ? 'Requerido' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nombre', border: OutlineInputBorder()),
                validator: (value) => (value == null || value.trim().isEmpty) ? 'Requerido' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _brandController,
                decoration: const InputDecoration(labelText: 'Marca (opcional)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _imageUrlController,
                decoration:
                    const InputDecoration(labelText: 'URL de imagen (opcional)', border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton(onPressed: _confirm, child: const Text('Guardar')),
      ],
    );
  }
}
