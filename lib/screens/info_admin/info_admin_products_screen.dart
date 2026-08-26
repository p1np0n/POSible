import 'package:flutter/material.dart';

import '../../models/product.dart';
import '../../services/product_repository.dart';
import '../../utils/search_normalize.dart';
import '../../widgets/currency_text.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_state.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/product_avatar.dart';
import '../../widgets/status_badge.dart';

/// "Lista de artículos" de Info Admin: buscar y ver el catálogo (nombre,
/// precio, stock) sin poder crear, editar ni borrar nada — para consultar
/// rápido desde el celular del administrador, no para gestionar el catálogo.
class InfoAdminProductsScreen extends StatefulWidget {
  const InfoAdminProductsScreen({super.key});

  @override
  State<InfoAdminProductsScreen> createState() => _InfoAdminProductsScreenState();
}

class _InfoAdminProductsScreenState extends State<InfoAdminProductsScreen> {
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
      final products = await _repository.getAll();
      if (!mounted) return;
      setState(() {
        _products = products;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo cargar la lista de artículos';
        _loading = false;
      });
    }
  }

  List<Product> get _filtered {
    if (_search.trim().isEmpty) return _products;
    final term = normalizeForSearch(_search);
    return _products
        .where((p) =>
            normalizeForSearch(p.name).contains(term) ||
            (p.barcode != null && normalizeForSearch(p.barcode!).contains(term)) ||
            (p.sku != null && normalizeForSearch(p.sku!).contains(term)))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              labelText: 'Buscar artículo',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (value) => setState(() => _search = value),
          ),
        ),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildBody() {
    if (_loading) return const LoadingIndicator();
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);
    final products = _filtered;
    if (products.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: const [
            SizedBox(height: 120),
            EmptyState(message: 'No hay artículos', icon: Icons.inventory_2_outlined),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        itemCount: products.length,
        itemBuilder: (context, index) {
          final product = products[index];
          final outOfStock = product.trackStock && product.stockQuantity <= 0;
          return ListTile(
            leading: ProductAvatar(name: product.name, categoryId: product.categoryId, imageUrl: product.imageUrl),
            title: Text(product.name),
            subtitle: outOfStock
                ? const Align(
                    alignment: Alignment.centerLeft,
                    child: StatusBadge(label: 'Agotado', tone: StatusBadgeTone.danger, dense: true),
                  )
                : product.isLowStock
                    ? const Align(
                        alignment: Alignment.centerLeft,
                        child: StatusBadge(label: 'Stock bajo', tone: StatusBadgeTone.warning, dense: true),
                      )
                    : product.trackStock
                        ? Text('Stock: ${product.stockQuantity.toStringAsFixed(0)}')
                        : null,
            trailing: CurrencyText(product.price, bold: true),
          );
        },
      ),
    );
  }
}
