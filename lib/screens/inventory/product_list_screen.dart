import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/category.dart';
import '../../models/product.dart';
import '../../providers/app_preferences_provider.dart';
import '../../services/category_repository.dart';
import '../../services/csv_export_service.dart';
import '../../services/product_repository.dart';
import '../../utils/search_normalize.dart';
import '../../widgets/currency_text.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_state.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/product_avatar.dart';
import '../../widgets/status_badge.dart';
import '../scan/barcode_scanner_screen.dart';
import 'product_form_screen.dart';

enum _SortMode { name, stockAsc, stockDesc }

enum _StockFilter { all, lowStock, outOfStock }

const int _pageSize = 50;

/// Valor especial para el filtro de categoría: "Sin categoría" — distinto
/// de `null`, que significa "todas las categorías" (sin filtrar).
const String _uncategorizedFilter = '__sin_categoria__';

/// Debajo de este ancho, la barra de herramientas agrupa ordenar/
/// seleccionar/exportar en un solo menú — a este ancho no caben como
/// íconos sueltos junto al buscador sin apretarlo demasiado.
const double _toolbarCompactBreakpoint = 600;

class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  final ProductRepository _productRepository = ProductRepository();
  final CategoryRepository _categoryRepository = CategoryRepository();
  final CsvExportService _csvExportService = CsvExportService();
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
  String? _error;
  bool _selectionMode = false;
  final Set<String> _selectedIds = {};
  int _requestId = 0;
  bool _exporting = false;

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
      _error = null;
      _products = [];
      _hasMore = true;
    });

    try {
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
        categoryId: _selectedCategoryId == _uncategorizedFilter ? null : _selectedCategoryId,
        onlyUncategorized: _selectedCategoryId == _uncategorizedFilter,
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
    } catch (e) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _error = 'No se pudieron cargar los artículos: $e';
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    final requestId = _requestId;
    setState(() => _loadingMore = true);
    final (orderBy, ascending) = _sortColumn;
    final page = await _productRepository.getPage(
      offset: _products.length,
      pageSize: _pageSize,
      categoryId: _selectedCategoryId == _uncategorizedFilter ? null : _selectedCategoryId,
      onlyUncategorized: _selectedCategoryId == _uncategorizedFilter,
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

    final search = normalizeForSearch(_search);
    final list = _products.where((p) {
      final matchesCategory = _selectedCategoryId == null
          ? true
          : _selectedCategoryId == _uncategorizedFilter
              ? p.categoryId == null
              : p.categoryId == _selectedCategoryId;
      final matchesSearch = search.isEmpty ||
          normalizeForSearch(p.name).contains(search) ||
          (p.barcode != null && normalizeForSearch(p.barcode!).contains(search)) ||
          (p.sku != null && normalizeForSearch(p.sku!).contains(search));
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
        targetMarginPercent: product.targetMarginPercent,
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

  /// Popup con un dropdown de categorías (más "Sin categoría"); devuelve
  /// la categoría elegida, o `(false, null)` si se canceló — el `bool`
  /// distingue "canceló" de "eligió Sin categoría" (que también es `null`).
  Future<(bool confirmed, String? categoryId)> _pickCategoryDialog({
    required String title,
    String? initial,
  }) async {
    String? picked = initial;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(title),
          content: DropdownButtonFormField<String?>(
            value: picked,
            decoration: const InputDecoration(labelText: 'Categoría', border: OutlineInputBorder()),
            items: [
              const DropdownMenuItem(value: null, child: Text('Sin categoría')),
              ..._categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
            ],
            onChanged: (value) => setDialogState(() => picked = value),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Aplicar')),
          ],
        ),
      ),
    );
    return (confirmed == true, picked);
  }

  Product _withCategory(Product product, String? categoryId) => Product(
        id: product.id,
        name: product.name,
        categoryId: categoryId,
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
        targetMarginPercent: product.targetMarginPercent,
      );

  Future<void> _bulkChangeCategory() async {
    final (confirmed, newCategoryId) =
        await _pickCategoryDialog(title: 'Cambiar categoría (${_selectedIds.length} producto(s))');
    if (!confirmed) return;
    final selected = _products.where((p) => _selectedIds.contains(p.id));
    for (final product in selected) {
      await _productRepository.update(product.id, _withCategory(product, newCategoryId));
    }
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
    _resetAndLoad();
  }

  /// Cambia la categoría de un solo producto sin tener que abrirlo (ícono
  /// junto a la categoría, en la fila) — mismo popup que el cambio en lote.
  Future<void> _quickChangeCategory(Product product) async {
    final (confirmed, newCategoryId) = await _pickCategoryDialog(
      title: 'Cambiar categoría — ${product.name}',
      initial: product.categoryId,
    );
    if (!confirmed || newCategoryId == product.categoryId) return;
    await _productRepository.update(product.id, _withCategory(product, newCategoryId));
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
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // En pantallas angostas, ordenar/seleccionar/exportar se
                  // apretaban junto al buscador hasta dejarlo casi inusable —
                  // se agrupan en un solo menú y se deja siempre visible lo
                  // esencial: buscador, escanear y "Nuevo".
                  final compact = constraints.maxWidth < _toolbarCompactBreakpoint;
                  return Row(
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
                      if (compact)
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert),
                          tooltip: 'Más acciones',
                          onSelected: (value) {
                            if (value == 'sort_name') {
                              setState(() => _sortMode = _SortMode.name);
                              _resetAndLoad();
                            } else if (value == 'sort_stock_asc') {
                              setState(() => _sortMode = _SortMode.stockAsc);
                              _resetAndLoad();
                            } else if (value == 'sort_stock_desc') {
                              setState(() => _sortMode = _SortMode.stockDesc);
                              _resetAndLoad();
                            } else if (value == 'select') {
                              _toggleSelectionMode();
                            } else if (value == 'export') {
                              if (!_exporting) _exportCsv();
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(value: 'sort_name', child: Text('Ordenar: Nombre (A-Z)')),
                            const PopupMenuItem(value: 'sort_stock_asc', child: Text('Ordenar: Stock menor a mayor')),
                            const PopupMenuItem(value: 'sort_stock_desc', child: Text('Ordenar: Stock mayor a menor')),
                            const PopupMenuDivider(),
                            PopupMenuItem(
                              value: 'select',
                              child: Text(_selectionMode ? 'Cancelar selección' : 'Seleccionar varios'),
                            ),
                            const PopupMenuItem(value: 'export', child: Text('Exportar a CSV')),
                          ],
                        )
                      else ...[
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
                      ],
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: () => _openForm(),
                        icon: const Icon(Icons.add),
                        label: const Text('Nuevo'),
                      ),
                    ],
                  );
                },
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
                        const DropdownMenuItem(value: _uncategorizedFilter, child: Text('Sin categoría')),
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
                  ? const LoadingIndicator()
                  : _error != null
                      ? ErrorState(message: _error!, onRetry: _resetAndLoad)
                      : visible.isEmpty
                          ? const EmptyState(message: 'No hay artículos', icon: Icons.inventory_2_outlined)
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
                            final outOfStock = product.trackStock && product.stockQuantity <= 0;
                            const metaStyle = TextStyle(fontSize: 12, color: Colors.grey);
                            return ListTile(
                              leading: _selectionMode
                                  ? Checkbox(
                                      value: selected,
                                      onChanged: (_) => _toggleSelected(product.id),
                                    )
                                  : ProductAvatar(
                                      name: product.name,
                                      categoryId: product.categoryId,
                                      imageUrl: product.imageUrl,
                                    ),
                              selected: selected,
                              title: Text(product.name),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  InkWell(
                                    onTap: _selectionMode ? null : () => _quickChangeCategory(product),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(_categoryName(product.categoryId)),
                                        if (!_selectionMode) ...[
                                          const SizedBox(width: 4),
                                          const Icon(Icons.edit_outlined, size: 13, color: Colors.grey),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 4,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      Text(
                                        product.trackStock
                                            ? 'Stock: ${product.stockQuantity.toStringAsFixed(0)}'
                                            : 'Stock: N/A',
                                        style: metaStyle,
                                      ),
                                      if (margin != null) Text('Margen: ${margin.toStringAsFixed(0)}%', style: metaStyle),
                                      if (product.isVariablePrice) const Text('Precio variable', style: metaStyle),
                                      if (product.isSoldByWeight)
                                        Text('Por peso (PLU ${product.plu ?? '-'})', style: metaStyle),
                                      if (outOfStock)
                                        const StatusBadge(label: 'Sin stock', tone: StatusBadgeTone.danger, dense: true)
                                      else if (product.isLowStock)
                                        const StatusBadge(
                                          label: 'Inventario bajo',
                                          tone: StatusBadgeTone.warning,
                                          dense: true,
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                              trailing: _selectionMode
                                  ? null
                                  : Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        CurrencyText(product.price, bold: true, style: const TextStyle(fontSize: 18)),
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
