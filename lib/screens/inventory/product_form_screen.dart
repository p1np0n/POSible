import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/category.dart';
import '../../models/product.dart';
import '../../providers/app_preferences_provider.dart';
import '../../services/photo_upload_service.dart';
import '../../services/product_catalog_repository.dart';
import '../../services/product_lookup_service.dart';
import '../../services/product_repository.dart';
import '../../services/shared_catalog_repository.dart';
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
  final ProductLookupService _lookupService = ProductLookupService();
  final ProductCatalogRepository _catalogRepository = ProductCatalogRepository();
  final SharedCatalogRepository _sharedCatalogRepository = SharedCatalogRepository();
  final PhotoUploadService _photoService = PhotoUploadService();

  late final TextEditingController _nameController;
  late final TextEditingController _priceController;
  late final TextEditingController _costController;
  late final TextEditingController _skuController;
  late final TextEditingController _barcodeController;
  late final TextEditingController _stockController;
  late final TextEditingController _lowStockController;
  bool _trackStock = true;
  String? _categoryId;
  String? _imageUrl;
  bool _saving = false;
  bool _looking = false;
  bool _uploadingPhoto = false;

  bool get _isEditing => widget.product != null;

  String? get _marginText {
    final price = double.tryParse(_priceController.text);
    final cost = double.tryParse(_costController.text);
    if (price == null || cost == null || price == 0 || cost == 0) return null;
    final margin = ((price - cost) / price) * 100;
    return 'Margen: ${margin.toStringAsFixed(1)}%';
  }

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
    _lowStockController = TextEditingController(
        text: product?.lowStockThreshold != null ? product!.lowStockThreshold!.toStringAsFixed(0) : '');
    _trackStock = product?.trackStock ?? true;
    _categoryId = product?.categoryId;
    _imageUrl = product?.imageUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _costController.dispose();
    _skuController.dispose();
    _barcodeController.dispose();
    _stockController.dispose();
    _lowStockController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final barcode = _barcodeController.text.trim().isEmpty ? null : _barcodeController.text.trim();
    final name = _nameController.text.trim();
    final product = Product(
      id: widget.product?.id ?? '',
      name: name,
      categoryId: _categoryId,
      price: double.parse(_priceController.text),
      cost: _costController.text.isEmpty ? null : double.tryParse(_costController.text),
      sku: _skuController.text.trim().isEmpty ? null : _skuController.text.trim(),
      barcode: barcode,
      imageUrl: _imageUrl,
      stockQuantity: double.tryParse(_stockController.text) ?? 0,
      trackStock: _trackStock,
      active: true,
      lowStockThreshold:
          _trackStock && _lowStockController.text.isNotEmpty ? double.tryParse(_lowStockController.text) : null,
    );

    try {
      if (_isEditing) {
        await _repository.update(widget.product!.id, product);
      } else {
        await _repository.create(product);
      }
      if (barcode != null) {
        // Guardamos en el catálogo propio para no tener que buscarlo de
        // nuevo la próxima vez que agregues un producto con este código, y
        // lo aportamos al catálogo compartido (si está configurado) para
        // que otros negocios que usan POSible también se beneficien.
        await _catalogRepository.upsert(barcode: barcode, name: name, imageUrl: _imageUrl);
        await _sharedCatalogRepository.contribute(barcode: barcode, name: name, imageUrl: _imageUrl);
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
    if (code != null) {
      setState(() => _barcodeController.text = code);
      _lookupBarcode();
    }
  }

  Future<void> _lookupBarcode() async {
    final barcode = _barcodeController.text.trim();
    if (barcode.isEmpty) return;
    setState(() => _looking = true);
    final entry = await _lookupService.lookup(barcode);
    if (!mounted) return;
    setState(() {
      _looking = false;
      if (entry != null) {
        if (_nameController.text.trim().isEmpty) _nameController.text = entry.name;
        if (entry.imageUrl != null && entry.imageUrl!.isNotEmpty) _imageUrl = entry.imageUrl;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(entry != null
          ? 'Encontrado: ${entry.name}'
          : 'No se encontró información en internet para ese código. Ingrésalo tú.'),
    ));
  }

  Future<void> _choosePhotoSource() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Tomar foto'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Elegir de la galería'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    setState(() => _uploadingPhoto = true);
    try {
      final url = await _photoService.pickAndUploadPhoto(source);
      if (url != null && mounted) setState(() => _imageUrl = url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al subir la foto: $e')));
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
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
    final cameraEnabled = context.watch<AppPreferencesProvider>().cameraScanEnabled;

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
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 44,
                    backgroundImage: _imageUrl != null ? NetworkImage(_imageUrl!) : null,
                    child: _imageUrl == null ? const Icon(Icons.inventory_2, size: 36) : null,
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _uploadingPhoto ? null : _choosePhotoSource,
                    icon: _uploadingPhoto
                        ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.add_a_photo_outlined),
                    label: Text(_imageUrl == null ? 'Agregar foto' : 'Cambiar foto'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
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
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _costController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration:
                        const InputDecoration(labelText: 'Costo (opcional)', border: OutlineInputBorder()),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            if (_marginText != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(_marginText!, style: Theme.of(context).textTheme.bodySmall),
              ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _skuController,
              decoration: const InputDecoration(labelText: 'SKU (opcional)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _barcodeController,
              decoration: InputDecoration(
                labelText: 'Código de barras (opcional)',
                border: const OutlineInputBorder(),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_looking)
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    else
                      IconButton(
                        icon: const Icon(Icons.search),
                        tooltip: 'Buscar en internet',
                        onPressed: _lookupBarcode,
                      ),
                    if (cameraEnabled)
                      IconButton(
                        icon: const Icon(Icons.qr_code_scanner),
                        tooltip: 'Escanear',
                        onPressed: _scanBarcode,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('Controlar inventario'),
              value: _trackStock,
              onChanged: (value) => setState(() => _trackStock = value),
              contentPadding: EdgeInsets.zero,
            ),
            if (_trackStock) ...[
              TextFormField(
                controller: _stockController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Existencias', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _lowStockController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Alertar cuando el stock llegue a (opcional)',
                  helperText: 'Déjalo vacío si no quieres alerta de inventario bajo para este producto',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
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
