import 'package:flutter/material.dart';

import '../../models/category.dart';
import '../../models/product.dart';
import '../../services/category_repository.dart';
import '../../services/product_repository.dart';
import '../../widgets/currency_text.dart';
import 'product_form_screen.dart';

class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  final ProductRepository _productRepository = ProductRepository();
  final CategoryRepository _categoryRepository = CategoryRepository();
  List<Product> _products = [];
  List<Category> _categories = [];
  String _search = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
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

  List<Product> get _filtered =>
      _products.where((p) => _search.isEmpty || p.name.toLowerCase().contains(_search.toLowerCase())).toList();

  Future<void> _openForm([Product? product]) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ProductFormScreen(product: product, categories: _categories)),
    );
    if (changed == true) _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                decoration: const InputDecoration(
                  labelText: 'Buscar producto',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (value) => setState(() => _search = value),
              ),
            ),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
