import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/category.dart';
import '../../models/product.dart';
import '../../providers/app_preferences_provider.dart';
import '../../services/category_repository.dart';
import '../../services/csv_export_service.dart';
import '../../services/product_lookup_service.dart';
import '../../services/product_repository.dart';
import '../../widgets/currency_text.dart';
import '../scan/barcode_scanner_screen.dart';
import 'product_form_screen.dart';

enum _SortMode { name, stockAsc, stockDesc }

enum _StockFilter { all, lowStock, outOfStock }

const int _pageSize = 50;

class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  final ProductRepository _productRepository = ProductRepository();
  final CategoryRepository _categoryRepository = CategoryRepository();
  final CsvExportService _csvExportService = CsvExportService();
  final ProductLookupService _lookupService = ProductLookupService();
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  List<Product> _products = [];
  List<Category> _categories = [];
  String _search = '';
  String? _selectedCategoryId;
  _SortMode _sortMode = _SortMode.name;
  _StockFilter _stockFilter = _StockFilter.all;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  bool _selectionMode = false;
  final Set<String> _selectedIds = {};
  int _requestId = 0;
  bool _exporting = false;
  bool _findingImages = false;
  int _findImagesProgress = 0;
  int _findImagesTotal = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _categoryRepository.getAll().then((categories) {
      if (mounted) setState(() => _categories = categories);
    });
    _resetAndLoad();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_stockFilter == _StockFilter.lowStock || !_hasMore || _loading || _loadingMore) return;
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 300) {
      _loadMore();
    }
  }

  (String orderBy, bool ascending) get _sortColumn => switch (_sortMode) {
        _SortMode.name => ('name', true),
        _SortMode.stockAsc => ('stock_quantity', true),
        _SortMode.stockDesc => ('stock_quantity', false),
      };

  /// Vuelve a cargar desde cero (al cambiar búsqueda, categoría, filtro de
  /// inventario, orden, o al hacer pull-to-refresh). Descarta la respuesta
  /// si mientras tanto se disparó otra búsqueda más nueva (evita que una
  /// respuesta lenta y vieja pise el resultado de la más reciente).
  Future<void> _resetAndLoad() async {
    final requestId = ++_requestId;
    setState(() {
      _loading = true;
      _products = [];
      _hasMore = true;
    });

    if (_stockFilter == _StockFilter.lowStock) {
      // Grupo chico (solo productos con umbral configurado): se trae
      // completo y se filtra/ordena en la app, sin paginar.
      final candidates = await _productRepository.getLowStockCandidates();
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _products = candidates;
        _hasMore = false;
        _loading = false;
      });
      return;
    }

    final (orderBy, ascending) = _sortColumn;
    final page = await _productRepository.getPage(
      offset: 0,
      pageSize: _pageSize,
      categoryId: _selectedCategoryId,
      search: _search,
      onlyOutOfStock: _stockFilter == _StockFilter.outOfStock,
      orderBy: orderBy,
      ascending: ascending,
    );
    if (!mounted || requestId != _requestId) return;
    setState(() {
      _products = page;
      _hasMore = page.length == _pageSize;
      _loading = false;
    });
  }

  Future<void> _loadMore() async {
    final requestId = _requestId;
    setState(() => _loadingMore = true);
    final (orderBy, ascending) = _sortColumn;
    final page = await _productRepository.getPage(
      offset: _products.length,
      pageSize: _pageSize,
      categoryId: _selectedCategoryId,
      search: _search,
      onlyOutOfStock: _stockFilter == _StockFilter.outOfStock,
      orderBy: orderBy,
      ascending: ascending,
    );
    if (!mounted || requestId != _requestId) return;
    setState(() {
      _products = [..._products, ...page];
      _hasMore = page.length == _pageSize;
      _loadingMore = false;
    });
  }

  String _categoryName(String? id) {
    if (id == null) return 'Sin categoría';
    final match = _categories.where((c) => c.id == id);
    return match.isEmpty ? 'Sin categoría' : match.first.name;
  }

  /// Para "Inventario bajo" (que no se filtra ni se ordena en el servidor)
  /// se aplican búsqueda, categoría, umbral y orden aquí mismo. Para los
  /// demás casos ya viene todo resuelto del servidor.
  List<Product> get _visibleProducts {
    if (_stockFilter != _StockFilter.lowStock) return _products;

    final search = _search.toLowerCase();
    final list = _products.where((p) {
      final matchesCategory = _selectedCategoryId == null || p.categoryId == _selectedCategoryId;
      final matchesSearch = search.isEmpty ||
          p.name.toLowerCase().contains(search) ||
          (p.barcode?.toLowerCase().contains(search) ?? false) ||
          (p.sku?.toLowerCase().contains(search) ?? false);
      return matchesCategory && matchesSearch && p.isLowStock;
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
    if (changed == true) {
      final categories = await _categoryRepository.getAll();
      if (mounted) setState(() => _categories = categories);
      _resetAndLoad();
    }
  }

  Future<void> _scanBarcode() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (code != null && mounted) {
      _searchController.text = code;
      setState(() => _search = code);
      _resetAndLoad();
    }
  }

  Future<void> _quickEditPriceCost(Product product) async {
    final priceController = TextEditingController(text: product.price.round().toString());
    final costController = TextEditingController(text: product.cost?.round().toString() ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(product.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: priceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Precio de venta', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: costController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Costo (opcional)', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Guardar')),
        ],
      ),
    );
    if (saved != true) return;
    final newPrice = double.tryParse(priceController.text);
    if (newPrice == null) return;
    final newCost = costController.text.isEmpty ? null : double.tryParse(costController.text);
    await _productRepository.update(
      product.id,
      Product(
        id: product.id,
        name: product.name,
        categoryId: product.categoryId,
        price: newPrice,
        cost: newCost,
        sku: product.sku,
        barcode: product.barcode,
        imageUrl: product.imageUrl,
        stockQuantity: product.stockQuantity,
        trackStock: product.trackStock,
        active: product.active,
        lowStockThreshold: product.lowStockThreshold,
        pricingType: product.pricingType,
        plu: product.plu,
      ),
    );
    _resetAndLoad();
  }

  Future<void> _exportCsv() async {
    setState(() => _exporting = true);
    try {
      final allProducts = await _productRepository.getAll();
      await _csvExportService.exportProducts(allProducts, _categories);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al exportar: $e')));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  /// Busca en internet (Open Food Facts, UPCitemdb, o el catálogo global si
  /// ya la tenía guardada otra tienda) la foto de cada producto que tiene
  /// código de barras pero todavía no tiene foto, y la guarda si la
  /// encuentra. Es de mejor esfuerzo: si no encuentra nada para alguno,
  /// simplemente sigue con el resto.
  Future<void> _findImagesByBarcode() async {
    final allProducts = await _productRepository.getAll();
    final candidates = allProducts
        .where((p) =>
            (p.imageUrl == null || p.imageUrl!.trim().isEmpty) &&
            p.barcode != null &&
            p.barcode!.trim().isNotEmpty)
        .toList();
    if (candidates.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No hay productos con código de barras y sin foto')),
        );
      }
      return;
    }

    setState(() {
      _findingImages = true;
      _findImagesProgress = 0;
      _findImagesTotal = candidates.length;
    });

    var updated = 0;
    for (final product in candidates) {
      try {
        final entry = await _lookupService.lookup(product.barcode!);
        if (entry?.imageUrl != null && entry!.imageUrl!.trim().isNotEmpty) {
          await _productRepository.update(product.id, product.copyWith(imageUrl: entry.imageUrl));
          updated++;
        }
      } catch (_) {
        // Sigue con el resto aunque uno falle (sin internet, API caída, etc.)
      }
      if (mounted) setState(() => _findImagesProgress++);
    }

    if (!mounted) return;
    setState(() => _findingImages = false);
    _resetAndLoad();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(updated > 0
            ? 'Se encontraron $updated foto(s) nueva(s) de ${candidates.length} producto(s) revisados'
            : 'No se encontró ninguna foto nueva entre ${candidates.length} producto(s) revisados'),
      ),
    );
  }

  void _toggleSelectionMode() {
    setState(() {
      _selectionMode = !_selectionMode;
      _selectedIds.clear();
    });
  }

  void _toggleSelected(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  Future<void> _bulkDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar productos'),
        content: Text('¿Seguro que quieres eliminar ${_selectedIds.length} producto(s)?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirmed != true) return;
    for (final id in _selectedIds) {
      await _productRepository.delete(id);
    }
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
    _resetAndLoad();
  }

  Future<void> _bulkChangeCategory() async {
    String? newCategoryId;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Cambiar categoría (${_selectedIds.length} producto(s))'),
          content: DropdownButtonFormField<String?>(
            value: newCategoryId,
            decoration: const InputDecoration(labelText: 'Nueva categoría', border: OutlineInputBorder()),
            items: [
              const DropdownMenuItem(value: null, child: Text('Sin categoría')),
              ..._categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
            ],
            onChanged: (value) => setDialogState(() => newCategoryId = value),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Aplicar')),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    final selected = _products.where((p) => _selectedIds.contains(p.id));
    for (final product in selected) {
      await _productRepository.update(
        product.id,
        Product(
          id: product.id,
          name: product.name,
          categoryId: newCategoryId,
          price: product.price,
          cost: product.cost,
          sku: product.sku,
          barcode: product.barcode,
          imageUrl: product.imageUrl,
          stockQuantity: product.stockQuantity,
          trackStock: product.trackStock,
          active: product.active,
          lowStockThreshold: product.lowStockThreshold,
          pricingType: product.pricingType,
          plu: product.plu,
        ),
      );
    }
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
    _resetAndLoad();
  }

  @override
  Widget build(BuildContext context) {
    final cameraEnabled = context.watch<AppPreferencesProvider>().cameraScanEnabled;
    final visible = _visibleProducts;

    return Scaffold(
      bottomNavigationBar: (_selectionMode && _selectedIds.isNotEmpty)
          ? BottomAppBar(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Text('${_selectedIds.length} seleccionado(s)'),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _bulkChangeCategory,
                      icon: const Icon(Icons.category_outlined),
                      label: const Text('Categoría'),
                    ),
                    TextButton.icon(
                      onPressed: _bulkDelete,
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      label: const Text('Eliminar', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              ),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _resetAndLoad,
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
                      onChanged: (value) {
                        setState(() => _search = value);
                        _resetAndLoad();
                      },
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
                    onSelected: (mode) {
                      setState(() => _sortMode = mode);
                      _resetAndLoad();
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: _SortMode.name, child: Text('Nombre (A-Z)')),
                      PopupMenuItem(value: _SortMode.stockAsc, child: Text('Stock: menor a mayor')),
                      PopupMenuItem(value: _SortMode.stockDesc, child: Text('Stock: mayor a menor')),
                    ],
                  ),
                  IconButton(
                    icon: Icon(_selectionMode ? Icons.close : Icons.checklist),
                    tooltip: _selectionMode ? 'Cancelar selección' : 'Seleccionar varios',
                    onPressed: _toggleSelectionMode,
                  ),
                  IconButton(
                    icon: _exporting
                        ? const SizedBox(
                            height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.download_outlined),
                    tooltip: 'Exportar a CSV',
                    onPressed: _exporting ? null : _exportCsv,
                  ),
                  IconButton(
                    icon: _findingImages
                        ? const SizedBox(
                            height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.image_search_outlined),
                    tooltip: 'Buscar fotos por código de barras',
                    onPressed: _findingImages ? null : _findImagesByBarcode,
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
            if (_findingImages)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LinearProgressIndicator(
                      value: _findImagesTotal == 0 ? null : _findImagesProgress / _findImagesTotal,
                    ),
                    const SizedBox(height: 4),
                    Text('Buscando fotos: $_findImagesProgress de $_findImagesTotal',
                        style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String?>(
                      value: _selectedCategoryId,
                      decoration: const InputDecoration(
                        labelText: 'Categoría',
                        prefixIcon: Icon(Icons.category_outlined),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Todas las categorías')),
                        ..._categories
                            .map((category) => DropdownMenuItem(value: category.id, child: Text(category.name))),
                      ],
                      onChanged: (value) {
                        setState(() => _selectedCategoryId = value);
                        _resetAndLoad();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<_StockFilter>(
                      value: _stockFilter,
                      decoration: const InputDecoration(
                        labelText: 'Inventario',
                        prefixIcon: Icon(Icons.warning_amber_outlined),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: const [
                        DropdownMenuItem(value: _StockFilter.all, child: Text('Todos')),
                        DropdownMenuItem(value: _StockFilter.lowStock, child: Text('Inventario bajo')),
                        DropdownMenuItem(value: _StockFilter.outOfStock, child: Text('Sin stock')),
                      ],
                      onChanged: (value) {
                        setState(() => _stockFilter = value ?? _StockFilter.all);
                        _resetAndLoad();
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : visible.isEmpty
                      ? const Center(child: Text('No hay productos'))
                      : ListView.builder(
                          controller: _scrollController,
                          itemCount: visible.length + (_loadingMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index >= visible.length) {
                              return const Padding(
                                padding: EdgeInsets.all(16),
                                child: Center(child: CircularProgressIndicator()),
                              );
                            }
                            final product = visible[index];
                            final margin = product.marginPercent;
                            final selected = _selectedIds.contains(product.id);
                            return ListTile(
                              leading: _selectionMode
                                  ? Checkbox(
                                      value: selected,
                                      onChanged: (_) => _toggleSelected(product.id),
                                    )
                                  : CircleAvatar(
                                      backgroundImage:
                                          product.imageUrl != null ? NetworkImage(product.imageUrl!) : null,
                                      child: product.imageUrl == null ? const Icon(Icons.inventory_2) : null,
                                    ),
                              selected: selected,
                              title: Text(product.name),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${_categoryName(product.categoryId)} · Stock: ${product.trackStock ? product.stockQuantity.toStringAsFixed(0) : 'N/A'}'
                                    '${margin != null ? ' · Margen: ${margin.toStringAsFixed(0)}%' : ''}'
                                    '${product.isVariablePrice ? ' · Precio variable' : ''}'
                                    '${product.isSoldByWeight ? ' · Por peso (PLU ${product.plu ?? '-'})' : ''}',
                                  ),
                                  if (product.isLowStock)
                                    const Padding(
                                      padding: EdgeInsets.only(top: 2),
                                      child: Text(
                                        'Inventario bajo',
                                        style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12),
                                      ),
                                    ),
                                ],
                              ),
                              trailing: _selectionMode
                                  ? null
                                  : Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        CurrencyText(product.price, bold: true),
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined, size: 20),
                                          tooltip: 'Editar precio/costo rápido',
                                          onPressed: () => _quickEditPriceCost(product),
                                        ),
                                      ],
                                    ),
                              onTap: _selectionMode ? () => _toggleSelected(product.id) : () => _openForm(product),
                              onLongPress: () {
                                if (!_selectionMode) {
                                  setState(() {
                                    _selectionMode = true;
                                    _selectedIds.add(product.id);
                                  });
                                }
                              },
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
