import 'package:flutter/material.dart';

import '../../models/category.dart';
import '../../models/product.dart';
import '../../services/product_repository.dart';
import '../../utils/currency_format_cl.dart';
import '../../widgets/currency_text.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_state.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/product_avatar.dart';
import 'product_form_screen.dart';

const int _pageSize = 100;

/// Artículos que se archivaron (a mano, o solos por 1 mes sin venderse) —
/// no aparecen en Ventas ni en Lista de artículos mientras estén acá.
/// Desarchivar (o subirle stock desde Inventario) los devuelve a la lista
/// normal. No afecta el catálogo global.
class ArchivedProductsScreen extends StatefulWidget {
  final List<Category> categories;

  const ArchivedProductsScreen({super.key, required this.categories});

  @override
  State<ArchivedProductsScreen> createState() => _ArchivedProductsScreenState();
}

class _ArchivedProductsScreenState extends State<ArchivedProductsScreen> {
  final ProductRepository _repository = ProductRepository();
  final _searchController = TextEditingController();
  List<Product> _products = [];
  String _search = '';
  bool _loading = true;
  String? _error;

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
      final products = await _repository.getPage(
        offset: 0,
        pageSize: _pageSize,
        search: _search,
        onlyArchived: true,
      );
      if (!mounted) return;
      setState(() {
        _products = products;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudieron cargar los artículos archivados: $e';
        _loading = false;
      });
    }
  }

  Future<void> _unarchive(Product product) async {
    try {
      await _repository.setArchived(product.id, false);
      if (!mounted) return;
      setState(() => _products = _products.where((p) => p.id != product.id).toList());
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('"${product.name}" desarchivado')));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al desarchivar: $e')));
      }
    }
  }

  Future<void> _openForm(Product product) async {
    final result = await Navigator.of(context)
        .push<bool>(MaterialPageRoute(builder: (_) => ProductFormScreen(product: product, categories: widget.categories)));
    if (result == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    // Se avisa "true" siempre al volver (no solo si hubo cambios), para que
    // Lista de artículos se refresque y refleje cualquier desarchivo hecho
    // acá sin tener que entrar y salir dos veces.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) Navigator.of(context).pop(true);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Artículos archivados'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  labelText: 'Buscar en archivados',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (value) {
                  _search = value;
                  _load();
                },
              ),
            ),
            Expanded(
              child: _loading
                  ? const LoadingIndicator()
                  : _error != null
                      ? ErrorState(message: _error!, onRetry: _load)
                      : _products.isEmpty
                          ? const EmptyState(
                              message: 'No hay artículos archivados',
                              icon: Icons.inventory_2_outlined,
                            )
                          : ListView.builder(
                              itemCount: _products.length,
                              itemBuilder: (context, index) {
                                final product = _products[index];
                                return ListTile(
                                  leading: ProductAvatar(
                                    name: product.name,
                                    categoryId: product.categoryId,
                                    imageUrl: product.imageUrl,
                                  ),
                                  title: Text(product.name, maxLines: 2, overflow: TextOverflow.ellipsis),
                                  subtitle: Text(
                                    product.trackStock
                                        ? 'Stock: ${formatNumberCl(product.stockQuantity)}'
                                        : 'Stock: N/A',
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      CurrencyText(product.price, bold: true),
                                      const SizedBox(width: 8),
                                      OutlinedButton(
                                        onPressed: () => _unarchive(product),
                                        child: const Text('Desarchivar'),
                                      ),
                                    ],
                                  ),
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
