import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/category.dart';
import '../../models/product.dart';
import '../../providers/app_preferences_provider.dart';
import '../../services/product_repository.dart';
import '../scan/barcode_scanner_screen.dart';

class ProductFormScreen extends StatefulWidget {
  final Product? product;
  final List<Category> categories;

  const ProductFormScreen({super.key, this.product, required this.categories});

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final ProductRepository _repository = ProductRepository();

  late final TextEditingController _nameController;
  late final TextEditingController _priceController;
  late final TextEditingController _costController;
  late final TextEditingController _skuController;
  late final TextEditingController _barcodeController;
  late final TextEditingController _stockController;
  bool _trackStock = true;
  String? _categoryId;
  bool _saving = false;

  bool get _isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    _nameController = TextEditingController(text: product?.name ?? '');
    _priceController = TextEditingController(text: product != null ? product.price.toStringAsFixed(2) : '');
    _costController =
        TextEditingController(text: product?.cost != null ? product!.cost!.toStringAsFixed(2) : '');
    _skuController = TextEditingController(text: product?.sku ?? '');
    _barcodeController = TextEditingController(text: product?.barcode ?? '');
    _stockController =
        TextEditingController(text: product != null ? product.stockQuantity.toStringAsFixed(0) : '0');
    _trackStock = product?.trackStock ?? true;
    _categoryId = product?.categoryId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _costController.dispose();
    _skuController.dispose();
    _barcodeController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final product = Product(
      id: widget.product?.id ?? '',
      name: _nameController.text.trim(),
      categoryId: _categoryId,
      price: double.parse(_priceController.text),
      cost: _costController.text.isEmpty ? null : double.tryParse(_costController.text),
      sku: _skuController.text.trim().isEmpty ? null : _skuController.text.trim(),
      barcode: _barcodeController.text.trim().isEmpty ? null : _barcodeController.text.trim(),
      stockQuantity: double.tryParse(_stockController.text) ?? 0,
      trackStock: _trackStock,
      active: true,
    );

    try {
      if (_isEditing) {
        await _repository.update(widget.product!.id, product);
      } else {
        await _repository.create(product);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _scanBarcode() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (code != null) setState(() => _barcodeController.text = code);
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar producto'),
        content: const Text('¿Seguro que quieres eliminar este producto?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirmed != true) return;
    await _repository.delete(widget.product!.id);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar producto' : 'Nuevo producto'),
        actions: [
          if (_isEditing) IconButton(icon: const Icon(Icons.delete_outline), onPressed: _delete),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nombre', border: OutlineInputBorder()),
              validator: (value) => (value == null || value.isEmpty) ? 'Requerido' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              value: _categoryId,
              decoration: const InputDecoration(labelText: 'Categoría', border: OutlineInputBorder()),
              items: [
                const DropdownMenuItem(value: null, child: Text('Sin categoría')),
                ...widget.categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
              ],
              onChanged: (value) => setState(() => _categoryId = value),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _priceController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration:
                        const InputDecoration(labelText: 'Precio de venta', border: OutlineInputBorder()),
                    validator: (value) => (double.tryParse(value ?? '') == null) ? 'Precio inválido' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _costController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration:
                        const InputDecoration(labelText: 'Costo (opcional)', border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _skuController,
                    decoration: const InputDecoration(labelText: 'SKU (opcional)', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _barcodeController,
                    decoration: InputDecoration(
                      labelText: 'Código de barras (opcional)',
                      border: const OutlineInputBorder(),
                      suffixIcon: context.watch<AppPreferencesProvider>().cameraScanEnabled
                          ? IconButton(
                              icon: const Icon(Icons.qr_code_scanner),
                              tooltip: 'Escanear',
                              onPressed: _scanBarcode,
                            )
                          : null,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('Controlar inventario'),
              value: _trackStock,
              onChanged: (value) => setState(() => _trackStock = value),
              contentPadding: EdgeInsets.zero,
            ),
            if (_trackStock)
              TextFormField(
                controller: _stockController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Existencias', border: OutlineInputBorder()),
              ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}
