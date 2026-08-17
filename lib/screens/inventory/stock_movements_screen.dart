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
import '../scan/barcode_scanner_screen.dart';
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

  List<Product> get _filteredProducts {
    if (_search.trim().isEmpty) return const [];
    final term = _search.toLowerCase();
    return _products
        .where((p) =>
            p.name.toLowerCase().contains(term) ||
            (p.barcode?.toLowerCase().contains(term) ?? false) ||
            (p.sku?.toLowerCase().contains(term) ?? false))
        .take(20)
        .toList();
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
    if (changed == true) _load();
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
    final cameraEnabled = context.watch<AppPreferencesProvider>().cameraScanEnabled;

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
                    labelText: 'Buscar o escanear producto',
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
          if (_search.trim().isNotEmpty)
            Card(
              margin: const EdgeInsets.only(top: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: _filteredProducts.isEmpty
                    ? [const ListTile(title: Text('No se encontró ningún producto'))]
                    : _filteredProducts
                        .map((p) => ListTile(
                              title: Text(p.name),
                              subtitle: Text(p.trackStock ? 'Stock: ${p.stockQuantity.toStringAsFixed(0)}' : ''),
                              onTap: () => _promptMovement(p),
                            ))
                        .toList(),
              ),
            ),
          const SizedBox(height: 24),
          Text('Movimientos recientes', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
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
