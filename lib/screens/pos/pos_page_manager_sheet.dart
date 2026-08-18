import 'package:flutter/material.dart';

import '../../models/category.dart';
import '../../models/pos_page.dart';
import '../../models/pos_page_item.dart';
import '../../models/product.dart';
import '../../services/pos_page_repository.dart';

/// Hoja para administrar una pestaña personalizada de Ventas: cambiarle el
/// nombre, agregarle productos o categorías completas, quitar lo que ya
/// tiene, o borrarla. Se cierra devolviendo true si algo cambió (para que
/// Ventas vuelva a cargar).
class PosPageManagerSheet extends StatefulWidget {
  final PosPage page;
  final List<Product> allProducts;
  final List<Category> allCategories;
  final List<PosPageItem> items;

  const PosPageManagerSheet({
    super.key,
    required this.page,
    required this.allProducts,
    required this.allCategories,
    required this.items,
  });

  @override
  State<PosPageManagerSheet> createState() => _PosPageManagerSheetState();
}

class _PosPageManagerSheetState extends State<PosPageManagerSheet> {
  final PosPageRepository _repository = PosPageRepository();
  late final TextEditingController _nameController;
  final _productSearchController = TextEditingController();
  late List<PosPageItem> _items;
  bool _changed = false;
  bool _savingName = false;
  String? _addingCategoryId;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.page.name);
    _items = List.of(widget.items);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _productSearchController.dispose();
    super.dispose();
  }

  Product? _productById(String id) {
    for (final p in widget.allProducts) {
      if (p.id == id) return p;
    }
    return null;
  }

  Category? _categoryById(String id) {
    for (final c in widget.allCategories) {
      if (c.id == id) return c;
    }
    return null;
  }

  Future<void> _saveName() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    setState(() => _savingName = true);
    await _repository.rename(widget.page.id, name);
    _changed = true;
    if (mounted) {
      setState(() => _savingName = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nombre actualizado')));
    }
  }

  Future<void> _deletePage() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar pestaña'),
        content: Text('¿Seguro que quieres eliminar "${widget.page.name}"? Los productos y categorías siguen existiendo, solo se borra esta pestaña.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _repository.delete(widget.page.id);
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _addProduct(Product product) async {
    if (_items.any((i) => i.productId == product.id)) return;
    await _repository.addProduct(widget.page.id, product.id);
    _changed = true;
    _productSearchController.clear();
    final items = await _repository.getAllItems();
    if (!mounted) return;
    setState(() => _items = items.where((i) => i.pageId == widget.page.id).toList());
  }

  Future<void> _addCategory() async {
    final categoryId = _addingCategoryId;
    if (categoryId == null) return;
    if (_items.any((i) => i.categoryId == categoryId)) return;
    await _repository.addCategory(widget.page.id, categoryId);
    _changed = true;
    final items = await _repository.getAllItems();
    if (!mounted) return;
    setState(() {
      _items = items.where((i) => i.pageId == widget.page.id).toList();
      _addingCategoryId = null;
    });
  }

  Future<void> _removeItem(PosPageItem item) async {
    await _repository.removeItem(item.id);
    _changed = true;
    if (mounted) setState(() => _items.removeWhere((i) => i.id == item.id));
  }

  @override
  Widget build(BuildContext context) {
    final search = _productSearchController.text.trim().toLowerCase();
    final searchResults = search.isEmpty
        ? const <Product>[]
        : widget.allProducts
            .where((p) =>
                p.name.toLowerCase().contains(search) || (p.barcode?.toLowerCase().contains(search) ?? false))
            .take(20)
            .toList();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => SafeArea(
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(labelText: 'Nombre de la pestaña', border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: _savingName
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.check),
                      tooltip: 'Guardar nombre',
                      onPressed: _savingName ? null : _saveName,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text('Agregar categoría completa', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        value: _addingCategoryId,
                        decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                        items: widget.allCategories
                            .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                            .toList(),
                        onChanged: (value) => setState(() => _addingCategoryId = value),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _addingCategoryId == null ? null : _addCategory,
                      child: const Text('Agregar'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text('Agregar producto', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                TextField(
                  controller: _productSearchController,
                  decoration: const InputDecoration(
                    labelText: 'Buscar producto o código',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                ...searchResults.map((p) => ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        backgroundImage: p.imageUrl != null ? NetworkImage(p.imageUrl!) : null,
                        child: p.imageUrl == null ? const Icon(Icons.inventory_2, size: 18) : null,
                      ),
                      title: Text(p.name),
                      trailing: const Icon(Icons.add_circle_outline),
                      onTap: () => _addProduct(p),
                    )),
                const SizedBox(height: 20),
                const Divider(),
                Text('Contenido de esta pestaña (${_items.length})', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                if (_items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('Todavía no agregaste nada — busca un producto o elige una categoría arriba.'),
                  )
                else
                  ..._items.map((item) {
                    final product = item.productId != null ? _productById(item.productId!) : null;
                    final category = item.categoryId != null ? _categoryById(item.categoryId!) : null;
                    return ListTile(
                      dense: true,
                      leading: Icon(item.productId != null ? Icons.inventory_2_outlined : Icons.category_outlined),
                      title: Text(product?.name ?? category?.name ?? '(eliminado)'),
                      subtitle: item.categoryId != null ? const Text('Categoría completa') : null,
                      trailing: IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        tooltip: 'Quitar',
                        onPressed: () => _removeItem(item),
                      ),
                    );
                  }),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: _deletePage,
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  label: const Text('Eliminar esta pestaña', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          ),
        ),
      );
  }
}

