import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/category.dart';
import '../../models/product.dart';
import '../../models/stock_movement.dart';
import '../../providers/app_preferences_provider.dart';
import '../../services/category_repository.dart';
import '../../services/product_repository.dart';
import '../../services/stock_movement_repository.dart';
import '../../utils/date_format_es.dart';
import '../../utils/search_normalize.dart';
import '../scan/barcode_scanner_screen.dart';
import 'invoice_scan_screen.dart';
import 'product_form_screen.dart';

/// Entradas y salidas de inventario, aparte de lo que ya descuenta una
/// venta: recibir mercadería, ajustar por pérdida/rotura, etc. Escaneando o
/// buscando un producto, pregunta cuántas unidades entran o salen.
class StockMovementsScreen extends StatefulWidget {
  const StockMovementsScreen({super.key});

  @override
  State<StockMovementsScreen> createState() => _StockMovementsScreenState();
}

class _StockMovementsScreenState extends State<StockMovementsScreen> {
  final ProductRepository _productRepository = ProductRepository();
  final CategoryRepository _categoryRepository = CategoryRepository();
  final StockMovementRepository _movementRepository = StockMovementRepository();
  final _searchController = TextEditingController();

  List<Product> _products = [];
  List<Category> _categories = [];
  List<StockMovement> _movements = [];
  String _search = '';
  String? _selectedCategoryId;
  bool _loading = true;

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
    setState(() => _loading = true);
    final results = await Future.wait([
      _productRepository.getAll(),
      _categoryRepository.getAll(),
      _movementRepository.getRecent(),
    ]);
    setState(() {
      _products = results[0] as List<Product>;
      _categories = results[1] as List<Category>;
      _movements = results[2] as List<StockMovement>;
      _loading = false;
    });
  }

  List<Product> get _articleTabProducts {
    var list = _products;
    if (_selectedCategoryId != null) {
      list = list.where((p) => p.categoryId == _selectedCategoryId).toList();
    }
    if (_search.trim().isNotEmpty) {
      final term = normalizeForSearch(_search);
      list = list
          .where((p) =>
              normalizeForSearch(p.name).contains(term) ||
              (p.barcode != null && normalizeForSearch(p.barcode!).contains(term)) ||
              (p.sku != null && normalizeForSearch(p.sku!).contains(term)))
          .toList();
    }
    return list;
  }

  String? _categoryName(String? categoryId) {
    if (categoryId == null) return null;
    for (final c in _categories) {
      if (c.id == categoryId) return c.name;
    }
    return null;
  }

  Future<void> _scanBarcode() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (code == null || !mounted) return;
    final product = await _productRepository.findByBarcode(code);
    if (!mounted) return;
    if (product != null) {
      _promptMovement(product);
    } else {
      _offerCreateProduct(code);
    }
  }

  Future<void> _importInvoice() async {
    final result = await Navigator.of(context).push<Map<String, int>>(
      MaterialPageRoute(builder: (_) => InvoiceScanScreen(products: _products)),
    );
    if (result == null || !mounted) return;
    _load();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
        '${result['updated']} producto(s) actualizados, ${result['created']} creados. '
        'Revisa el precio de los nuevos en Lista de artículos.',
      ),
    ));
  }

  Future<void> _offerCreateProduct(String barcode) async {
    final create = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Producto no encontrado'),
        content: Text('No hay ningún producto con el código $barcode. ¿Quieres crearlo?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Crear')),
        ],
      ),
    );
    if (create != true || !mounted) return;
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ProductFormScreen(categories: _categories, initialBarcode: barcode),
      ),
    );
    if (changed != true || !mounted) return;
    // Se limpia lo que hubiera en el buscador (ej. el mismo código que no
    // encontraba nada antes de crearlo) — si no, el filtro seguía activo y
    // el producto recién creado no aparecía en la lista aunque ya
    // estuviera guardado.
    _searchController.clear();
    setState(() {
      _search = '';
      _selectedCategoryId = null;
    });
    _load();
  }

  Future<void> _promptMovement(Product product) async {
    final formKey = GlobalKey<FormState>();
    final quantityController = TextEditingController(text: '1');
    final noteController = TextEditingController();
    String type = 'in';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(product.name),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.trackStock
                        ? 'Stock actual: ${product.stockQuantity.toStringAsFixed(0)}'
                        : 'Este producto no controla inventario',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'in', label: Text('Entrada'), icon: Icon(Icons.add_box_outlined)),
                      ButtonSegment(
                          value: 'out', label: Text('Salida'), icon: Icon(Icons.indeterminate_check_box_outlined)),
                    ],
                    selected: {type},
                    onSelectionChanged: (value) => setDialogState(() => type = value.first),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: quantityController,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Cantidad', border: OutlineInputBorder()),
                    validator: (value) {
                      final qty = double.tryParse(value ?? '');
                      return (qty == null || qty <= 0) ? 'Cantidad inválida' : null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: noteController,
                    decoration: const InputDecoration(
                      labelText: 'Motivo (opcional)',
                      hintText: 'Ej. Compra a proveedor, pérdida, rotura',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                Navigator.of(context).pop(true);
              },
              child: const Text('Confirmar'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;
    final quantity = double.parse(quantityController.text);
    final note = noteController.text.trim().isEmpty ? null : noteController.text.trim();

    try {
      await _productRepository.adjustStock(product.id, type == 'in' ? quantity : -quantity);
      await _movementRepository.create(
        productId: product.id,
        productName: product.name,
        type: type,
        quantity: quantity,
        note: note,
      );
      if (!mounted) return;
      _searchController.clear();
      setState(() => _search = '');
      _load();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(type == 'in'
            ? '+${quantity.toStringAsFixed(0)} ${product.name}'
            : '-${quantity.toStringAsFixed(0)} ${product.name}'),
      ));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo registrar: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.surface,
            child: const TabBar(
              tabs: [
                Tab(text: 'Artículos'),
                Tab(text: 'Movimientos'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildArticlesTab(),
                _buildMovementsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArticlesTab() {
    final cameraEnabled = context.watch<AppPreferencesProvider>().cameraScanEnabled;
    final products = _articleTabProducts;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: 'Buscar artículo',
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(),
                    isDense: true,
                    suffixIcon: cameraEnabled
                        ? IconButton(icon: const Icon(Icons.qr_code_scanner), onPressed: _scanBarcode)
                        : null,
                  ),
                  onChanged: (value) => setState(() => _search = value),
                ),
              ),
              if (!cameraEnabled) ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.qr_code_scanner),
                  tooltip: 'Escanear código de barras',
                  onPressed: _scanBarcode,
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String?>(
            value: _selectedCategoryId,
            decoration: const InputDecoration(
              labelText: 'Categoría',
              prefixIcon: Icon(Icons.category_outlined),
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('Todas las categorías')),
              ..._categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
            ],
            onChanged: (value) => setState(() => _selectedCategoryId = value),
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
          else if (products.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('No hay artículos que coincidan'),
            )
          else
            ...products.map((p) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(p.name),
                    subtitle: Text(_categoryName(p.categoryId) ?? 'Sin categoría'),
                    trailing: p.trackStock
                        ? Text(
                            p.stockQuantity.toStringAsFixed(p.stockQuantity == p.stockQuantity.roundToDouble() ? 0 : 2),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: p.isLowStock ? Colors.orange : null,
                            ),
                          )
                        : const Text('No controla stock', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    onTap: () => _promptMovement(p),
                  ),
                )),
        ],
      ),
    );
  }

  Widget _buildMovementsTab() {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _importInvoice,
                  icon: const Icon(Icons.receipt_long_outlined),
                  label: const Text('Importar factura (foto)'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.qr_code_scanner),
                tooltip: 'Escanear para registrar movimiento',
                onPressed: _scanBarcode,
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
          else if (_movements.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('Todavía no hay movimientos de inventario'),
            )
          else
            ..._movements.map((m) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    m.isIn ? Icons.add_circle_outline : Icons.remove_circle_outline,
                    color: m.isIn ? Colors.green : Colors.red,
                  ),
                  title: Text(m.productName),
                  subtitle: Text(
                    '${formatDayHeaderEs(m.createdAt.toLocal())} · ${formatTimeEs(m.createdAt.toLocal())}'
                    '${m.note != null ? ' · ${m.note}' : ''}'
                    '${m.userEmail != null ? ' · ${m.userEmail}' : ''}',
                  ),
                  trailing: Text(
                    '${m.isIn ? '+' : '-'}${m.quantity.toStringAsFixed(0)}',
                    style: TextStyle(
                      color: m.isIn ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )),
        ],
      ),
    );
  }
}
