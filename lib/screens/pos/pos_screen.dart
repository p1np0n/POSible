import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/category.dart';
import '../../models/product.dart';
import '../../providers/app_preferences_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/cash_session_provider.dart';
import '../../services/category_repository.dart';
import '../../services/product_repository.dart';
import '../../widgets/currency_text.dart';
import '../scan/barcode_scanner_screen.dart';
import 'cart_sheet.dart';
import 'cash_session_sheet.dart';

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final ProductRepository _productRepository = ProductRepository();
  final CategoryRepository _categoryRepository = CategoryRepository();
  final _searchController = TextEditingController();

  List<Product> _products = [];
  List<Category> _categories = [];
  String? _selectedCategoryId;
  String _search = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CashSessionProvider>().refresh();
    });
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

  List<Product> get _filteredProducts {
    return _products.where((product) {
      final matchesCategory = _selectedCategoryId == null || product.categoryId == _selectedCategoryId;
      final search = _search.toLowerCase();
      final matchesSearch = _search.isEmpty ||
          product.name.toLowerCase().contains(search) ||
          (product.barcode?.toLowerCase().contains(search) ?? false) ||
          (product.sku?.toLowerCase().contains(search) ?? false);
      return matchesCategory && matchesSearch;
    }).toList();
  }

  void _openCashSessionSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const CashSessionSheet(),
    );
  }

  void _openCart() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const CartSheet(),
    ).then((_) => _loadData());
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
    final cashSession = context.watch<CashSessionProvider>();
    final cart = context.watch<CartProvider>();
    final prefs = context.watch<AppPreferencesProvider>();

    return RefreshIndicator(
      onRefresh: _loadData,
      child: Column(
        children: [
          if (!cashSession.loading && !cashSession.isOpen)
            MaterialBanner(
              content: const Text('La caja está cerrada. Ábrela para empezar a vender.'),
              actions: [
                TextButton(onPressed: _openCashSessionSheet, child: const Text('Abrir caja')),
              ],
            ),
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
                if (prefs.cameraScanEnabled)
                  IconButton(
                    icon: const Icon(Icons.qr_code_scanner),
                    tooltip: 'Escanear código de barras',
                    onPressed: _scanBarcode,
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
                : _filteredProducts.isEmpty
                    ? const Center(child: Text('No hay productos'))
                    : prefs.useListLayout
                        ? _buildList(cashSession)
                        : _buildGrid(cashSession),
          ),
          if (cart.items.isNotEmpty)
            Material(
              elevation: 8,
              child: InkWell(
                onTap: _openCart,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${cart.itemCount} artículo(s) en el carrito'),
                      CurrencyText(cart.total, bold: true),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGrid(CashSessionProvider cashSession) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.4,
      ),
      itemCount: _filteredProducts.length,
      itemBuilder: (context, index) {
        final product = _filteredProducts[index];
        final outOfStock = product.trackStock && product.stockQuantity <= 0;
        return Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: (outOfStock || !cashSession.isOpen) ? null : () => context.read<CartProvider>().addProduct(product),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      if (product.imageUrl != null) ...[
                        CircleAvatar(radius: 14, backgroundImage: NetworkImage(product.imageUrl!)),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: Text(
                          product.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      CurrencyText(product.price),
                      if (outOfStock)
                        const Text('Agotado', style: TextStyle(color: Colors.red, fontSize: 12))
                      else if (product.trackStock)
                        Text('Stock: ${product.stockQuantity.toStringAsFixed(0)}',
                            style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildList(CashSessionProvider cashSession) {
    return ListView.builder(
      itemCount: _filteredProducts.length,
      itemBuilder: (context, index) {
        final product = _filteredProducts[index];
        final outOfStock = product.trackStock && product.stockQuantity <= 0;
        return ListTile(
          leading: CircleAvatar(
            backgroundImage: product.imageUrl != null ? NetworkImage(product.imageUrl!) : null,
            child: product.imageUrl == null ? const Icon(Icons.inventory_2) : null,
          ),
          title: Text(product.name),
          subtitle: outOfStock
              ? const Text('Agotado', style: TextStyle(color: Colors.red))
              : product.trackStock
                  ? Text('Stock: ${product.stockQuantity.toStringAsFixed(0)}')
                  : null,
          trailing: CurrencyText(product.price, bold: true),
          enabled: !outOfStock && cashSession.isOpen,
          onTap: () => context.read<CartProvider>().addProduct(product),
        );
      },
    );
  }
}
