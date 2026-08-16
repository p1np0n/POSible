import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/category.dart';
import '../../models/product.dart';
import '../../providers/app_preferences_provider.dart';
import '../../services/category_repository.dart';
import '../../services/product_repository.dart';
import '../../widgets/currency_text.dart';
import '../scan/barcode_scanner_screen.dart';
import 'product_form_screen.dart';

enum _SortMode { name, stockAsc, stockDesc }

class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  final ProductRepository _productRepository = ProductRepository();
  final CategoryRepository _categoryRepository = CategoryRepository();
  final _searchController = TextEditingController();
  List<Product> _products = [];
  List<Category> _categories = [];
  String _search = '';
  String? _selectedCategoryId;
  _SortMode _sortMode = _SortMode.name;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      _productRepository.getAll(),
      _categoryRepository.getAll(),
    ]);
    setState(() {
      _products = results[0] as List<Product>;
      _categories = results[1] as List<Category>;
      _loading = false;
    });
  }

  String _categoryName(String? id) {
    if (id == null) return 'Sin categoría';
    final match = _categories.where((c) => c.id == id);
    return match.isEmpty ? 'Sin categoría' : match.first.name;
  }

  List<Product> get _filtered {
    final search = _search.toLowerCase();
    final list = _products.where((p) {
      final matchesCategory = _selectedCategoryId == null || p.categoryId == _selectedCategoryId;
      final matchesSearch = search.isEmpty ||
          p.name.toLowerCase().contains(search) ||
          (p.barcode?.toLowerCase().contains(search) ?? false) ||
          (p.sku?.toLowerCase().contains(search) ?? false);
      return matchesCategory && matchesSearch;
    }).toList();

    switch (_sortMode) {
      case _SortMode.name:
        list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case _SortMode.stockAsc:
        list.sort((a, b) => a.stockQuantity.compareTo(b.stockQuantity));
        break;
      case _SortMode.stockDesc:
        list.sort((a, b) => b.stockQuantity.compareTo(a.stockQuantity));
        break;
    }
    return list;
  }

  Future<void> _openForm([Product? product]) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ProductFormScreen(product: product, categories: _categories)),
    );
    if (changed == true) _loadData();
  }

  Future<void> _scanBarcode() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (code != null && mounted) {
      _searchController.text = code;
      setState(() => _search = code);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cameraEnabled = context.watch<AppPreferencesProvider>().cameraScanEnabled;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        labelText: 'Buscar producto o código',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (value) => setState(() => _search = value),
                    ),
                  ),
                  if (cameraEnabled)
                    IconButton(
                      icon: const Icon(Icons.qr_code_scanner),
                      tooltip: 'Escanear código de barras',
                      onPressed: _scanBarcode,
                    ),
                  PopupMenuButton<_SortMode>(
                    icon: const Icon(Icons.sort),
                    tooltip: 'Ordenar',
                    initialValue: _sortMode,
                    onSelected: (mode) => setState(() => _sortMode = mode),
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: _SortMode.name, child: Text('Nombre (A-Z)')),
                      PopupMenuItem(value: _SortMode.stockAsc, child: Text('Stock: menor a mayor')),
                      PopupMenuItem(value: _SortMode.stockDesc, child: Text('Stock: mayor a menor')),
                    ],
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
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: const Text('Todas'),
                      selected: _selectedCategoryId == null,
                      onSelected: (_) => setState(() => _selectedCategoryId = null),
                    ),
                  ),
                  ..._categories.map((category) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(category.name),
                          selected: _selectedCategoryId == category.id,
                          onSelected: (_) => setState(() => _selectedCategoryId = category.id),
                        ),
                      )),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _filtered.isEmpty
                      ? const Center(child: Text('No hay productos'))
                      : ListView.builder(
                          itemCount: _filtered.length,
                          itemBuilder: (context, index) {
                            final product = _filtered[index];
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundImage:
                                    product.imageUrl != null ? NetworkImage(product.imageUrl!) : null,
                                child: product.imageUrl == null ? const Icon(Icons.inventory_2) : null,
                              ),
                              title: Text(product.name),
                              subtitle: Text(
                                '${_categoryName(product.categoryId)} · Stock: ${product.trackStock ? product.stockQuantity.toStringAsFixed(0) : 'N/A'}',
                              ),
                              trailing: CurrencyText(product.price, bold: true),
                              onTap: () => _openForm(product),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
