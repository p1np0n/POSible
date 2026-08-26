import 'package:flutter/material.dart';

import '../../models/catalog_entry.dart';
import '../../services/product_catalog_repository.dart';
import '../../services/product_lookup_service.dart';
import '../../utils/currency_format_cl.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_state.dart';
import '../../widgets/loading_indicator.dart';

/// Catálogo global de productos: UNO SOLO, compartido entre todas tus
/// tiendas. Se alimenta automáticamente de lo que cada tienda agrega a su
/// propio inventario (con o sin código de barras); esta pantalla, solo
/// visible para el administrador principal, sirve para revisarlo y
/// curarlo a mano.
class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final ProductCatalogRepository _repository = ProductCatalogRepository();
  final ProductLookupService _lookupService = ProductLookupService();
  final _searchController = TextEditingController();
  List<CatalogEntry> _entries = [];
  bool _loading = true;
  String _search = '';
  String? _error;
  bool _findingImages = false;
  int _findImagesProgress = 0;
  int _findImagesTotal = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final entries = await _repository.getAll(search: _search);
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo cargar el catálogo global';
        _loading = false;
      });
    }
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
      await _repository.update(entry.id, result);
    }
    _load();
  }

  Future<void> _delete(CatalogEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar producto'),
        content: Text(
          '¿Seguro que quieres eliminar "${entry.name}" del catálogo global? '
          'Esto afecta a todas tus tiendas, no solo a una.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirmed != true) return;
    await _repository.deleteById(entry.id);
    _load();
  }

  /// Busca en internet (Open Food Facts, Open Beauty Facts, Open Products
  /// Facts, UPCitemdb y, si la configuraste, Google) la foto de cada
  /// producto del catálogo que tiene código de barras pero todavía no
  /// tiene foto. No toca el nombre ni la marca ya guardados — solo llena
  /// la foto si la encuentra. Es de mejor esfuerzo: si no encuentra nada
  /// para alguno, simplemente sigue con el resto.
  Future<void> _findImagesByBarcode() async {
    final candidates = _entries
        .where((e) =>
            (e.imageUrl == null || e.imageUrl!.trim().isEmpty) &&
            e.barcode != null &&
            e.barcode!.trim().isNotEmpty)
        .toList();
    if (candidates.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No hay productos del catálogo con código de barras y sin foto')),
        );
      }
      return;
    }

    setState(() {
      _findingImages = true;
      _findImagesProgress = 0;
      _findImagesTotal = candidates.length;
    });

    var updated = 0;
    for (final entry in candidates) {
      try {
        final imageUrl = await _lookupService.findImageUrl(entry.barcode!);
        if (imageUrl != null && imageUrl.trim().isNotEmpty) {
          await _repository.update(
            entry.id,
            CatalogEntry(
              id: entry.id,
              barcode: entry.barcode,
              name: entry.name,
              brand: entry.brand,
              imageUrl: imageUrl,
              suggestedPrice: entry.suggestedPrice,
            ),
          );
          updated++;
        }
      } catch (_) {
        // Sigue con el resto aunque uno falle (sin internet, API caída, etc.)
      }
      if (mounted) setState(() => _findImagesProgress++);
    }

    if (!mounted) return;
    setState(() => _findingImages = false);
    _load();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(updated > 0
            ? 'Se encontraron $updated foto(s) nueva(s) de ${candidates.length} producto(s) revisados'
            : 'No se encontró ninguna foto nueva entre ${candidates.length} producto(s) revisados'),
      ),
    );
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
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: 'Buscar por nombre o código de barras',
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
                IconButton(
                  icon: _findingImages
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.image_search_outlined),
                  tooltip: 'Buscar fotos por código de barras',
                  onPressed: _findingImages ? null : _findImagesByBarcode,
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
          if (_findingImages)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(
                    value: _findImagesTotal == 0 ? null : _findImagesProgress / _findImagesTotal,
                  ),
                  const SizedBox(height: 4),
                  Text('Buscando fotos: $_findImagesProgress de $_findImagesTotal',
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          Expanded(
            child: _loading
                ? const LoadingIndicator()
                : _error != null
                    ? ErrorState(message: _error!, onRetry: _load)
                    : _entries.isEmpty
                        ? const EmptyState(
                            message: 'No hay productos en el catálogo global todavía',
                            icon: Icons.public_outlined,
                          )
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
                                [
                                  if (entry.barcode != null) entry.barcode,
                                  if (entry.suggestedPrice != null)
                                    'Sugerido: ${formatCurrencyCl(entry.suggestedPrice!)}',
                                ].whereType<String>().join(' · '),
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
  late final TextEditingController _priceController;
  late final TextEditingController _imageUrlController;

  bool get _isEditing => widget.entry != null;

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    _barcodeController = TextEditingController(text: entry?.barcode ?? '');
    _nameController = TextEditingController(text: entry?.name ?? '');
    _brandController = TextEditingController(text: entry?.brand ?? '');
    _priceController = TextEditingController(text: entry?.suggestedPrice?.round().toString() ?? '');
    _imageUrlController = TextEditingController(text: entry?.imageUrl ?? '');
  }

  @override
  void dispose() {
    _barcodeController.dispose();
    _nameController.dispose();
    _brandController.dispose();
    _priceController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  void _confirm() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      CatalogEntry(
        id: widget.entry?.id ?? '',
        barcode: _barcodeController.text.trim().isEmpty ? null : _barcodeController.text.trim(),
        name: _nameController.text.trim(),
        brand: _brandController.text.trim().isEmpty ? null : _brandController.text.trim(),
        imageUrl: _imageUrlController.text.trim().isEmpty ? null : _imageUrlController.text.trim(),
        suggestedPrice: double.tryParse(_priceController.text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Editar producto del catálogo' : 'Nuevo producto del catálogo'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nombre', border: OutlineInputBorder()),
                validator: (value) => (value == null || value.trim().isEmpty) ? 'Requerido' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _barcodeController,
                decoration:
                    const InputDecoration(labelText: 'Código de barras (opcional)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _brandController,
                decoration: const InputDecoration(labelText: 'Marca (opcional)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _priceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration:
                    const InputDecoration(labelText: 'Precio sugerido (opcional)', border: OutlineInputBorder()),
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
