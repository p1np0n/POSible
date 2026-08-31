import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/catalog_entry.dart';
import '../../models/category.dart';
import '../../models/product.dart';
import '../../providers/app_preferences_provider.dart';
import '../../services/category_repository.dart';
import '../../services/invoice_ocr_service.dart';
import '../../services/photo_upload_service.dart';
import '../../services/product_catalog_repository.dart';
import '../../services/product_lookup_service.dart';
import '../../services/product_repository.dart';
import '../../services/settings_repository.dart';
import '../../utils/currency_format_cl.dart';
import '../scan/barcode_scanner_screen.dart';

class ProductFormScreen extends StatefulWidget {
  final Product? product;
  final List<Category> categories;

  /// Código de barras con el que abrir el formulario ya lleno (ej. al crear
  /// un producto nuevo desde un código escaneado en Inventario que no se
  /// encontró). Solo aplica si [product] es null.
  final String? initialBarcode;

  const ProductFormScreen({super.key, this.product, required this.categories, this.initialBarcode});

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final ProductRepository _repository = ProductRepository();
  final ProductLookupService _lookupService = ProductLookupService();
  final ProductCatalogRepository _catalogRepository = ProductCatalogRepository();
  final CategoryRepository _categoryRepository = CategoryRepository();
  final PhotoUploadService _photoService = PhotoUploadService();
  final InvoiceOcrService _ocrService = InvoiceOcrService();
  final SettingsRepository _settingsRepository = SettingsRepository();

  late final TextEditingController _nameController;
  final _nameFocusNode = FocusNode();
  Timer? _nameDebounce;
  List<CatalogEntry> _nameSuggestions = [];
  late final TextEditingController _priceController;
  late final TextEditingController _costController;
  late final TextEditingController _marginController;
  late final TextEditingController _skuController;
  late final TextEditingController _barcodeController;
  late final TextEditingController _stockController;
  late final TextEditingController _lowStockController;
  late final TextEditingController _pluController;
  late final TextEditingController _promoPriceController;
  late List<Category> _categories;
  bool _trackStock = true;
  String? _categoryId;
  String? _imageUrl;
  double? _suggestedPrice;
  String _pricingType = 'fixed';
  bool _promoEnabled = false;
  DateTime? _promoStartsAt;
  DateTime? _promoEndsAt;
  bool _saving = false;
  bool _looking = false;
  bool _uploadingPhoto = false;
  double _defaultMarginPercent = 30;
  double _taxRatePercent = 0;

  bool get _isEditing => widget.product != null;
  bool get _isVariablePrice => _pricingType == 'variable';
  bool get _isSoldByWeight => _pricingType == 'weight';

  String? get _marginText {
    final price = double.tryParse(_priceController.text);
    final cost = double.tryParse(_costController.text);
    if (price == null || cost == null || price == 0 || cost == 0) return null;
    final margin = ((price - cost) / price) * 100;
    return 'Margen actual: ${margin.toStringAsFixed(1)}%';
  }

  /// Desglose de IVA del precio ya ingresado (que se asume con el IVA
  /// incluido) — solo informativo, no cambia el precio.
  String? get _ivaBreakdownText {
    final price = double.tryParse(_priceController.text);
    if (price == null || price <= 0 || _taxRatePercent <= 0) return null;
    final net = price / (1 + _taxRatePercent / 100);
    final iva = price - net;
    return 'Neto: ${formatCurrencyCl(net)} · IVA (${_taxRatePercent.toStringAsFixed(1)}%): ${formatCurrencyCl(iva)}';
  }

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    _categories = List.of(widget.categories);
    _nameController = TextEditingController(text: product?.name ?? '');
    _priceController = TextEditingController(text: product != null ? product.price.round().toString() : '');
    _costController =
        TextEditingController(text: product?.cost != null ? product!.cost!.round().toString() : '');
    _marginController = TextEditingController(
        text: product?.targetMarginPercent != null ? product!.targetMarginPercent!.toStringAsFixed(1) : '');
    _skuController = TextEditingController(text: product?.sku ?? '');
    _barcodeController = TextEditingController(text: product?.barcode ?? widget.initialBarcode ?? '');
    _stockController =
        TextEditingController(text: product != null ? product.stockQuantity.toStringAsFixed(0) : '0');
    _lowStockController = TextEditingController(
        text: product?.lowStockThreshold != null ? product!.lowStockThreshold!.toStringAsFixed(0) : '');
    _pluController = TextEditingController(text: product?.plu ?? '');
    _promoPriceController =
        TextEditingController(text: product?.promoPrice != null ? product!.promoPrice!.round().toString() : '');
    _promoEnabled = product?.promoPrice != null;
    _promoStartsAt = product?.promoStartsAt;
    _promoEndsAt = product?.promoEndsAt;
    _trackStock = product?.trackStock ?? true;
    _categoryId = product?.categoryId;
    _imageUrl = product?.imageUrl;
    _pricingType = product?.pricingType ?? 'fixed';
    _nameFocusNode.addListener(() {
      if (!_nameFocusNode.hasFocus && mounted) setState(() => _nameSuggestions = []);
    });
    if (product == null && widget.initialBarcode != null && widget.initialBarcode!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _lookupBarcode());
    }
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await _settingsRepository.getSettings();
      if (mounted) {
        setState(() {
          _defaultMarginPercent = settings.defaultMarginPercent;
          _taxRatePercent = settings.taxRatePercent;
        });
      }
    } catch (_) {
      // Nos quedamos con los valores por defecto (30% de margen, 0% de IVA)
      // si todavía no hay configuración guardada.
    }
  }

  @override
  void dispose() {
    _nameDebounce?.cancel();
    _nameFocusNode.dispose();
    _nameController.dispose();
    _priceController.dispose();
    _costController.dispose();
    _marginController.dispose();
    _skuController.dispose();
    _barcodeController.dispose();
    _stockController.dispose();
    _lowStockController.dispose();
    _pluController.dispose();
    _promoPriceController.dispose();
    super.dispose();
  }

  Future<void> _pickPromoDate({required bool isStart}) async {
    final initial =
        isStart ? (_promoStartsAt ?? DateTime.now()) : (_promoEndsAt ?? DateTime.now().add(const Duration(days: 7)));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _promoStartsAt = DateTime(picked.year, picked.month, picked.day);
      } else {
        _promoEndsAt = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final barcode = _barcodeController.text.trim().isEmpty ? null : _barcodeController.text.trim();
    final name = _nameController.text.trim();
    final price = double.tryParse(_priceController.text) ?? 0;
    final plu = _pluController.text.trim();
    final product = Product(
      id: widget.product?.id ?? '',
      name: name,
      categoryId: _categoryId,
      price: price,
      cost: _costController.text.isEmpty ? null : double.tryParse(_costController.text),
      sku: _skuController.text.trim().isEmpty ? null : _skuController.text.trim(),
      barcode: barcode,
      imageUrl: _imageUrl,
      stockQuantity: double.tryParse(_stockController.text) ?? 0,
      trackStock: _trackStock,
      active: true,
      lowStockThreshold:
          _trackStock && _lowStockController.text.isNotEmpty ? double.tryParse(_lowStockController.text) : null,
      pricingType: _pricingType,
      plu: _isSoldByWeight && plu.isNotEmpty ? plu : null,
      targetMarginPercent:
          _marginController.text.trim().isEmpty ? null : double.tryParse(_marginController.text.trim()),
      archived: widget.product?.archived ?? false,
      promoPrice: _promoEnabled && _pricingType == 'fixed' ? double.tryParse(_promoPriceController.text) : null,
      promoStartsAt: _promoEnabled && _pricingType == 'fixed' ? _promoStartsAt : null,
      promoEndsAt: _promoEnabled && _pricingType == 'fixed' ? _promoEndsAt : null,
    );

    try {
      if (_isEditing) {
        await _repository.update(widget.product!.id, product);
      } else {
        await _repository.create(product);
      }
      // Aportamos este producto al catálogo global (compartido entre todas
      // tus tiendas), con o sin código de barras, para que las demás tiendas
      // puedan encontrarlo al buscar y usarlo como base (nombre, foto y
      // precio sugerido) al crear el suyo. Es "a modo de mejor esfuerzo": si
      // falla, tu producto igual queda guardado en tu inventario, no se
      // debe bloquear ni mostrar como si la venta hubiera fallado.
      try {
        await _catalogRepository.upsert(
          barcode: barcode,
          name: name,
          imageUrl: _imageUrl,
          suggestedPrice: price > 0 ? price : null,
          source: 'store',
        );
      } catch (catalogError) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Guardado, pero no se pudo sumar al catálogo global: $catalogError')),
          );
        }
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

  /// Calcula el precio de venta sugerido a partir del costo y el margen (el
  /// propio de este producto si lo escribió, si no el general de la
  /// tienda), y lo pone en el campo Precio — solo al tocar el botón, nunca
  /// solo.
  void _calculatePriceFromMargin() {
    final cost = double.tryParse(_costController.text);
    if (cost == null || cost <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Ingresa el costo primero')));
      return;
    }
    final margin = _marginController.text.trim().isEmpty
        ? _defaultMarginPercent
        : double.tryParse(_marginController.text.trim()) ?? _defaultMarginPercent;
    if (margin >= 100) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('El margen debe ser menor a 100%')));
      return;
    }
    final price = cost / (1 - margin / 100);
    setState(() => _priceController.text = roundPriceCl(price).toString());
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
        _suggestedPrice = entry.suggestedPrice;
        if (entry.suggestedPrice != null &&
            entry.suggestedPrice! > 0 &&
            _priceController.text.trim().isEmpty) {
          _priceController.text = entry.suggestedPrice!.round().toString();
        }
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(entry != null
          ? 'Encontrado: ${entry.name}'
          : 'No se encontró información en internet para ese código. Ingrésalo tú.'),
    ));
  }

  /// Busca por nombre en el catálogo global (lo que ya cargaron tú u otras
  /// de tus tiendas), para no volver a escribir todo desde cero.
  Future<void> _searchCatalog() async {
    final entry = await showDialog<CatalogEntry>(
      context: context,
      builder: (_) => const _CatalogSearchDialog(),
    );
    if (entry == null) return;
    _applyCatalogSuggestion(entry);
  }

  /// Mientras escribes el nombre de un producto NUEVO, busca en vivo en el
  /// catálogo global (con un pequeño retraso para no buscar en cada letra)
  /// y muestra los resultados debajo del campo, para que no haga falta
  /// encontrar el ícono de búsqueda.
  void _onNameChanged(String value) {
    _nameDebounce?.cancel();
    if (_isEditing || value.trim().length < 2) {
      if (_nameSuggestions.isNotEmpty) setState(() => _nameSuggestions = []);
      return;
    }
    _nameDebounce = Timer(const Duration(milliseconds: 400), () async {
      try {
        final results = await _catalogRepository.search(value.trim());
        if (mounted) setState(() => _nameSuggestions = results);
      } catch (_) {
        // Búsqueda de mejor esfuerzo: si falla, no se muestran sugerencias,
        // pero se puede seguir escribiendo el producto a mano igual.
      }
    });
  }

  /// Al elegir un resultado del catálogo global, carga todos los datos que
  /// tiene guardados (nombre, foto, código de barras y precio) para no
  /// tener que volver a escribirlos — el precio queda editable, por si a tu
  /// tienda le corresponde uno distinto.
  void _applyCatalogSuggestion(CatalogEntry entry) {
    if (!mounted) return;
    setState(() {
      _nameController.text = entry.name;
      if (entry.imageUrl != null && entry.imageUrl!.isNotEmpty) _imageUrl = entry.imageUrl;
      if (entry.barcode != null && entry.barcode!.isNotEmpty) _barcodeController.text = entry.barcode!;
      _suggestedPrice = entry.suggestedPrice;
      if (entry.suggestedPrice != null && entry.suggestedPrice! > 0) {
        _priceController.text = entry.suggestedPrice!.round().toString();
      }
      _nameSuggestions = [];
    });
    _nameFocusNode.unfocus();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Datos cargados del catálogo global: ${entry.name}')),
    );
  }

  Future<void> _addCategoryInline() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nueva categoría'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nombre', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Crear'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    try {
      final category = await _categoryRepository.create(name);
      if (!mounted) return;
      setState(() {
        _categories = [..._categories, category];
        _categoryId = category.id;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('No se pudo crear la categoría: $e')));
      }
    }
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
      final result = await _photoService.pickAndUploadPhoto(source);
      if (result == null || !mounted) return;
      final (url, bytes) = result;
      setState(() => _imageUrl = url);
      if (_nameController.text.trim().isEmpty) {
        unawaited(_suggestNameFromPhoto(bytes));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al subir la foto: $e')));
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  /// Intenta reconocer el texto de la foto recién subida (mismo OCR que
  /// "Importar factura") y, si el nombre sigue vacío cuando termina, lo
  /// llena con la línea más larga del texto reconocido — suele ser el
  /// nombre del producto en el empaque, más que el peso o el código de
  /// barras. Es solo una sugerencia editable: si no encuentra nada legible,
  /// no hace nada (no interrumpe con un error, ya que la foto ya se subió
  /// bien de todas formas).
  Future<void> _suggestNameFromPhoto(Uint8List bytes) async {
    String text;
    try {
      text = await _ocrService.extractText(bytes);
    } catch (_) {
      return;
    }
    final candidate = text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.length >= 3 && RegExp(r'[A-Za-zÁÉÍÓÚÑáéíóúñ]{3,}').hasMatch(line))
        .fold<String?>(null, (best, line) => (best == null || line.length > best.length) ? line : best);
    if (candidate == null || !mounted || _nameController.text.trim().isNotEmpty) return;
    setState(() => _nameController.text = candidate);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Nombre sugerido de la foto: "$candidate" (puedes cambiarlo)')),
    );
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
              focusNode: _nameFocusNode,
              decoration: InputDecoration(
                labelText: 'Nombre',
                helperText: _isEditing ? null : 'Escribe para ver sugerencias del catálogo global',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.travel_explore),
                  tooltip: 'Buscar en catálogo global',
                  onPressed: _searchCatalog,
                ),
              ),
              validator: (value) => (value == null || value.isEmpty) ? 'Requerido' : null,
              onChanged: _onNameChanged,
            ),
            if (_nameSuggestions.isNotEmpty)
              Card(
                margin: const EdgeInsets.only(top: 4),
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: _nameSuggestions.map((entry) {
                    return ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundImage: entry.imageUrl != null ? NetworkImage(entry.imageUrl!) : null,
                        child: entry.imageUrl == null ? const Icon(Icons.inventory_2, size: 16) : null,
                      ),
                      title: Text(entry.name),
                      subtitle: Text(entry.suggestedPrice != null
                          ? 'Sugerido: ${formatCurrencyCl(entry.suggestedPrice!)}'
                          : (entry.barcode ?? 'Del catálogo global')),
                      onTap: () => _applyCatalogSuggestion(entry),
                    );
                  }).toList(),
                ),
              ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    value: _categoryId,
                    decoration: const InputDecoration(labelText: 'Categoría', border: OutlineInputBorder()),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Sin categoría')),
                      ..._categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
                    ],
                    onChanged: (value) => setState(() => _categoryId = value),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  tooltip: 'Nueva categoría',
                  onPressed: _addCategoryInline,
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _pricingType,
              decoration: const InputDecoration(labelText: 'Tipo de precio', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'fixed', child: Text('Fijo')),
                DropdownMenuItem(value: 'variable', child: Text('Variable (se pregunta al vender)')),
                DropdownMenuItem(value: 'weight', child: Text('Por peso (código de balanza)')),
              ],
              onChanged: (value) => setState(() => _pricingType = value ?? 'fixed'),
            ),
            if (_isSoldByWeight) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _pluController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Código PLU (5 dígitos, el que trae la balanza)',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    (_isSoldByWeight && (value == null || value.trim().isEmpty)) ? 'Requerido' : null,
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _priceController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: _isSoldByWeight
                          ? 'Precio por kilo (IVA incluido)'
                          : _isVariablePrice
                              ? 'Precio de referencia (opcional)'
                              : 'Precio de venta (IVA incluido)',
                      helperText: _isVariablePrice ? null : 'Ingresa el precio final, con el IVA ya sumado',
                      border: const OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (_isVariablePrice && (value == null || value.trim().isEmpty)) return null;
                      return (double.tryParse(value ?? '') == null) ? 'Precio inválido' : null;
                    },
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
            if (_ivaBreakdownText != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(_ivaBreakdownText!, style: Theme.of(context).textTheme.bodySmall),
              ),
            if (_isVariablePrice)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'En Ventas se te preguntará el precio cada vez que agregues este artículo al carrito.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _marginController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Margen de este producto (%)',
                      helperText: 'Vacío = usa el margen general '
                          '(${_defaultMarginPercent.toStringAsFixed(0)}%, en Configuración)',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _calculatePriceFromMargin,
                  icon: const Icon(Icons.calculate_outlined),
                  label: const Text('Calcular precio'),
                ),
              ],
            ),
            if (_marginText != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(_marginText!, style: Theme.of(context).textTheme.bodySmall),
              ),
            if (_suggestedPrice != null && _suggestedPrice! > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Precio de ${formatCurrencyCl(_suggestedPrice!)} tomado del catálogo global — puedes cambiarlo.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            if (_pricingType == 'fixed') ...[
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Oferta temporal'),
                subtitle: const Text(
                  'Un precio distinto solo por un tiempo — se muestra en Ventas y Lista de artículos mientras dure.',
                ),
                value: _promoEnabled,
                onChanged: (value) => setState(() {
                  _promoEnabled = value;
                  if (value) {
                    _promoStartsAt ??= DateTime.now();
                    _promoEndsAt ??= DateTime.now().add(const Duration(days: 7));
                  }
                }),
              ),
              if (_promoEnabled) ...[
                TextFormField(
                  controller: _promoPriceController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Precio de oferta', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickPromoDate(isStart: true),
                        icon: const Icon(Icons.date_range),
                        label: Text(_promoStartsAt != null
                            ? 'Desde: ${_promoStartsAt!.day.toString().padLeft(2, '0')}/${_promoStartsAt!.month.toString().padLeft(2, '0')}'
                            : 'Desde'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickPromoDate(isStart: false),
                        icon: const Icon(Icons.date_range),
                        label: Text(_promoEndsAt != null
                            ? 'Hasta: ${_promoEndsAt!.day.toString().padLeft(2, '0')}/${_promoEndsAt!.month.toString().padLeft(2, '0')}'
                            : 'Hasta'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ],
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

class _CatalogSearchDialog extends StatefulWidget {
  const _CatalogSearchDialog();

  @override
  State<_CatalogSearchDialog> createState() => _CatalogSearchDialogState();
}

class _CatalogSearchDialogState extends State<_CatalogSearchDialog> {
  final ProductCatalogRepository _repository = ProductCatalogRepository();
  final _controller = TextEditingController();
  List<CatalogEntry> _results = [];
  bool _loading = false;

  Future<void> _search(String query) async {
    setState(() => _loading = true);
    try {
      final results = await _repository.search(query);
      if (!mounted) return;
      setState(() {
        _results = results;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo buscar: $e')));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Buscar en catálogo global'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Nombre o código de barras',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onSubmitted: _search,
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())
            else if (_results.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('Escribe y presiona Enter para buscar'),
              )
            else
              SizedBox(
                height: 300,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _results.length,
                  itemBuilder: (context, index) {
                    final entry = _results[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: entry.imageUrl != null ? NetworkImage(entry.imageUrl!) : null,
                        child: entry.imageUrl == null ? const Icon(Icons.inventory_2) : null,
                      ),
                      title: Text(entry.name),
                      subtitle: Text(entry.suggestedPrice != null
                          ? 'Sugerido: ${formatCurrencyCl(entry.suggestedPrice!)}'
                          : entry.barcode ?? ''),
                      onTap: () => Navigator.of(context).pop(entry),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cerrar')),
      ],
    );
  }
}
