import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/cart_item.dart';
import '../../models/category.dart';
import '../../models/customer.dart';
import '../../models/discount.dart';
import '../../models/modifier.dart';
import '../../models/open_ticket.dart';
import '../../models/pos_page.dart';
import '../../models/pos_page_item.dart';
import '../../models/product.dart';
import '../../providers/app_preferences_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/cash_session_provider.dart';
import '../../services/category_repository.dart';
import '../../services/customer_repository.dart';
import '../../services/discount_repository.dart';
import '../../services/modifier_repository.dart';
import '../../services/open_ticket_repository.dart';
import '../../services/pos_page_repository.dart';
import '../../services/product_catalog_repository.dart';
import '../../services/product_repository.dart';
import '../../services/reports_repository.dart';
import '../../utils/search_normalize.dart';
import '../../widgets/currency_text.dart';
import '../../widgets/number_pad_dialog.dart';
import '../../widgets/product_avatar.dart';
import '../../widgets/status_badge.dart';
import '../inventory/product_form_screen.dart';
import '../scan/barcode_scanner_screen.dart';
import 'cart_panel.dart';
import 'cash_session_sheet.dart';
import 'modifier_picker_sheet.dart';
import 'open_tickets_sheet.dart';
import 'page_item_customize_dialog.dart';
import 'pos_page_manager_sheet.dart';

/// A partir de este ancho, Ventas se divide lado a lado (productos +
/// carrito); antes de eso queda apilado (productos arriba, carrito abajo),
/// pero el carrito SIEMPRE está visible en pantalla, nunca hay que abrirlo.
const double _splitLayoutBreakpoint = 900;

/// Ancho aproximado de cada mosaico de producto — a partir de esto se
/// calculan cuántas columnas caben según el ancho real de la pantalla
/// (da mosaicos chicos, unos 5x5 visibles a la vez en una tablet, como se
/// pidió, para ver más productos sin desplazarse).
const double _targetTileWidth = 120.0;

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final ProductRepository _productRepository = ProductRepository();
  final ProductCatalogRepository _catalogRepository = ProductCatalogRepository();
  final CategoryRepository _categoryRepository = CategoryRepository();
  final ModifierRepository _modifierRepository = ModifierRepository();
  final OpenTicketRepository _openTicketRepository = OpenTicketRepository();
  final ReportsRepository _reportsRepository = ReportsRepository();
  final PosPageRepository _pageRepository = PosPageRepository();
  final _searchController = TextEditingController();
  // Con un lector de código de barras USB (funciona como un teclado que
  // "escribe" el código y presiona Enter), el foco tiene que quedarse
  // siempre en este campo — si se pierde (por ejemplo, al tocar un filtro
  // o cerrar un cuadro de diálogo), lo que el lector escanea no llega a
  // ningún lado y parece que "no lee". Por eso se lo devuelve después de
  // cada interacción que pudiera habérselo quitado.
  final _searchFocusNode = FocusNode();

  List<Product> _products = [];
  List<Category> _categories = [];
  List<Modifier> _modifiers = [];
  List<String> _topSellingIds = [];
  List<PosPage> _pages = [];
  Map<String, List<PosPageItem>> _pageItemsByPage = {};
  String? _selectedCategoryId;
  String? _selectedPageId;
  bool _showTopSelling = false;
  String _search = '';
  int _searchSyncId = 0;
  bool _loading = true;
  int _openTicketCount = 0;
  // Si el buscador está desplegado (mostrando el campo de texto) o
  // escondido detrás del ícono de lupa — ver la barra de arriba en build().
  bool _searchExpanded = false;
  // Además de devolverle el foco al buscador explícitamente después de
  // cada interacción conocida (_refocusSearch), este timer revisa cada
  // tanto si el foco se perdió sin que nada más lo esté usando a propósito
  // (ej. un caso que no contemplamos) y lo recupera solo — así el lector
  // USB no puede quedar "roto" en silencio por un hueco que se nos escapó.
  Timer? _scannerFocusWatchdog;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<CashSessionProvider>().refresh();
      _refreshOpenTicketCount();
      _refocusSearch();
    });
    _loadData();
    _scannerFocusWatchdog = Timer.periodic(const Duration(milliseconds: 400), (_) {
      if (!mounted) return;
      if (!context.read<AppPreferencesProvider>().usbScannerModeEnabled) return;
      if (_searchFocusNode.hasFocus) return;
      // Si otra cosa tiene el foco a propósito (un diálogo abierto, un
      // campo de texto de otra pantalla), no se lo quitamos.
      if (FocusManager.instance.primaryFocus != null) return;
      _searchFocusNode.requestFocus();
    });
  }

  /// Le devuelve el foco al campo de búsqueda (el que recibe lo que
  /// escanea el lector USB) después de que termine de dibujarse el frame
  /// actual — así gana por sobre cualquier otro widget que se lo haya
  /// pedido durante la interacción que se acaba de procesar. Solo hace
  /// algo si "Modo lector USB" está activado en Configuración: en una
  /// pantalla táctil sin ese lector, forzar el foco aquí abriría el
  /// teclado en pantalla de más, así que por defecto queda apagado.
  void _refocusSearch() {
    if (!mounted) return;
    if (!context.read<AppPreferencesProvider>().usbScannerModeEnabled) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _scannerFocusWatchdog?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      _productRepository.getAll(),
      _categoryRepository.getAll(),
      _modifierRepository.getAll(onlyActive: true),
      _reportsRepository.getTopSellingProductIds(),
      _pageRepository.getAll(),
      _pageRepository.getAllItems(),
    ]);
    if (!mounted) return;
    final pages = results[4] as List<PosPage>;
    final allItems = results[5] as List<PosPageItem>;
    final grouped = <String, List<PosPageItem>>{};
    for (final item in allItems) {
      grouped.putIfAbsent(item.pageId, () => []).add(item);
    }
    var products = results[0] as List<Product>;
    // Una pestaña puede tener agregado un producto que, por lo que sea, no
    // quedó en este catálogo recién cargado (ej. se agregó desde otra
    // pantalla justo antes) — sin esto, esa pestaña lo mostraría como
    // "(eliminado)" aunque sí exista, y su tarjeta no aparecería en el
    // mosaico.
    final knownIds = products.map((p) => p.id).toSet();
    final missingIds = allItems
        .map((i) => i.productId)
        .whereType<String>()
        .where((id) => !knownIds.contains(id))
        .toSet()
        .toList();
    if (missingIds.isNotEmpty) {
      final missing = await _productRepository.getByIds(missingIds);
      if (!mounted) return;
      products = [...products, ...missing];
    }
    setState(() {
      _products = products;
      _categories = results[1] as List<Category>;
      _modifiers = results[2] as List<Modifier>;
      _topSellingIds = results[3] as List<String>;
      _pages = pages;
      _pageItemsByPage = grouped;
      if (_selectedPageId != null && !pages.any((p) => p.id == _selectedPageId)) {
        _selectedPageId = null;
      }
      _loading = false;
    });
  }

  Future<void> _addToCart(Product product) async {
    try {
      var effective = product;
      if (product.isVariablePrice) {
        final price = await _askVariablePrice(product);
        if (price == null || !mounted) return;
        effective = product.copyWith(price: price);
      }
      // Un artículo de precio variable puede tener un precio distinto cada
      // vez que se agrega (ej. dos servicios del mismo tipo pero cobrados
      // distinto) — addProduct() combinaría ambos en una sola línea por
      // compartir el mismo product.id, perdiendo el segundo precio.
      // addVariableItem() siempre agrega una línea nueva, como ya se hace
      // con los artículos por peso.
      if (_modifiers.isEmpty) {
        if (product.isVariablePrice) {
          context.read<CartProvider>().addVariableItem(effective);
        } else {
          context.read<CartProvider>().addProduct(effective);
        }
        _clearSearch();
        return;
      }
      final selected = await showModalBottomSheet<List<Modifier>>(
        context: context,
        isScrollControlled: true,
        builder: (_) => ModifierPickerSheet(product: effective, modifiers: _modifiers),
      );
      if (selected != null && mounted) {
        if (product.isVariablePrice) {
          context.read<CartProvider>().addVariableItem(effective, modifiers: selected);
        } else {
          context.read<CartProvider>().addProduct(effective, modifiers: selected);
        }
        _clearSearch();
      }
    } finally {
      _refocusSearch();
    }
  }

  /// Deja el buscador listo para el siguiente artículo apenas se agrega
  /// uno al carrito (desde el mosaico, la lista, o un escaneo) — así no
  /// hay que borrar a mano lo que se buscó para encontrar el que se acaba
  /// de agregar antes de buscar el próximo.
  void _clearSearch() {
    if (_search.isEmpty && _searchController.text.isEmpty) return;
    _searchController.clear();
    setState(() => _search = '');
  }

  /// Pide el precio de un artículo de precio variable antes de agregarlo al
  /// carrito (ej. un servicio o algo sin precio fijo en el catálogo).
  Future<double?> _askVariablePrice(Product product) {
    return showNumberPadDialog(
      context,
      title: product.name,
      initialValue: product.price > 0 ? product.price : null,
      prefixText: '\$',
      minValue: 1,
    );
  }

  /// Códigos de balanza (peso variable): 13 dígitos que empiezan con "2".
  /// Dígitos 2-6: código PLU del producto. Dígitos 7-11: peso en gramos. El
  /// último dígito es de control (no se valida). Devuelve null si "code" no
  /// tiene esa forma (no es un código de balanza).
  ({String plu, double weightKg})? _decodeWeightBarcode(String code) {
    if (code.length != 13 || !code.startsWith('2') || int.tryParse(code) == null) return null;
    final plu = code.substring(1, 6);
    final grams = int.tryParse(code.substring(6, 11));
    if (grams == null) return null;
    return (plu: plu, weightKg: grams / 1000);
  }

  /// Si "code" es un código de balanza, busca el producto por PLU y lo
  /// agrega al carrito con el peso escaneado. Devuelve true si "code" se
  /// reconoció como código de balanza (se haya encontrado el producto o
  /// no), para que quien llama no lo trate además como una búsqueda normal.
  Future<bool> _tryAddWeightBarcode(String code) async {
    final decoded = _decodeWeightBarcode(code);
    if (decoded == null) return false;
    Product? product;
    for (final p in _products) {
      if (p.isSoldByWeight && p.plu == decoded.plu) {
        product = p;
        break;
      }
    }
    if (!mounted) return true;
    if (product == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No hay ningún producto por peso con el código ${decoded.plu}')),
      );
      return true;
    }
    if (!context.read<CashSessionProvider>().isOpen) return true;
    context.read<CartProvider>().addVariableItem(product, quantity: decoded.weightKg);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Agregado: ${product.name} (${decoded.weightKg.toStringAsFixed(3)} kg)')),
    );
    return true;
  }

  /// Si "code" coincide exactamente con el código de barras de un producto
  /// (normal, no de balanza), lo agrega de inmediato al carrito — así el
  /// lector de código de barras USB no necesita nada más que este campo
  /// tenga el foco. Devuelve true si "code" coincidió con algún producto,
  /// para que quien llama no lo trate además como una búsqueda de texto.
  Future<bool> _tryAddScannedBarcode(String code) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty) return false;
    Product? product;
    for (final p in _products) {
      if (p.barcode != null && p.barcode == trimmed) {
        product = p;
        break;
      }
    }
    if (product == null) return false;
    if (!mounted) return true;
    if (!context.read<CashSessionProvider>().isOpen) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Abre la caja antes de vender')),
      );
      return true;
    }
    await _addToCart(product);
    return true;
  }

  /// Un código de barras real es solo dígitos (EAN-13, EAN-8, UPC-A, los
  /// numéricos de balanza, etc.) — se usa para distinguir "esto se escaneó
  /// o se tecleó como código" de una búsqueda de texto común que
  /// simplemente no encontró nada, y así no ofrecer "crear producto" ante
  /// cualquier búsqueda sin resultados.
  bool _looksLikeBarcode(String value) => RegExp(r'^\d{6,}$').hasMatch(value);

  /// Maneja lo que llega al buscador (visible o el campo invisible del
  /// lector USB) al presionar Enter — el lector manda el código y un Enter
  /// automático, así que esto es lo que hace que escanear agregue el
  /// producto solo, sin tocar la pantalla. Si el código tiene forma de
  /// código de barras pero no coincide con ningún producto, ofrece crearlo
  /// al toque (ver _offerCreateProductForBarcode).
  Future<void> _handleScanSubmit(String value) async {
    final handled = await _tryAddWeightBarcode(value) || await _tryAddScannedBarcode(value);
    final trimmed = value.trim();
    if (handled || _looksLikeBarcode(trimmed)) {
      if (mounted) {
        _searchController.clear();
        setState(() => _search = '');
      }
    }
    if (!handled && _looksLikeBarcode(trimmed) && mounted) {
      await _offerCreateProductForBarcode(trimmed);
    }
    _refocusSearch();
  }

  /// Avisa que no existe ningún producto con ese código de barras y ofrece
  /// crearlo al toque, sin tener que ir a Lista de artículos ni escanear
  /// una segunda vez.
  Future<void> _offerCreateProductForBarcode(String barcode) async {
    final create = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Artículo no encontrado'),
        content: Text('No hay ningún producto con el código de barras $barcode.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cerrar')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Agregar producto')),
        ],
      ),
    );
    if (create == true && mounted) {
      await _quickCreateProductFromBarcode(barcode);
    }
  }

  /// Crea el producto con el código de barras ya escaneado (pidiendo solo
  /// nombre y precio, lo mínimo para poder cobrarlo) y lo agrega de
  /// inmediato al carrito — así el flujo completo (escanear algo que no
  /// existe → crearlo → venderlo) no necesita una segunda pasada.
  Future<void> _quickCreateProductFromBarcode(String barcode) async {
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    Future<void> pickPrice(StateSetter setState) async {
      final price = await showNumberPadDialog(
        context,
        title: 'Precio',
        initialValue: double.tryParse(priceController.text),
        prefixText: '\$',
        minValue: 1,
      );
      if (price != null) setState(() => priceController.text = price.round().toString());
    }

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Agregar artículo nuevo'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Código de barras: $barcode', style: TextStyle(color: Colors.grey.shade700)),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Nombre', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: priceController,
                readOnly: true,
                decoration: const InputDecoration(labelText: 'Precio', border: OutlineInputBorder()),
                onTap: () => pickPrice(setState),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Agregar')),
          ],
        ),
      ),
    );
    if (saved != true || !mounted) return;
    final name = nameController.text.trim();
    final price = double.tryParse(priceController.text);
    if (name.isEmpty || price == null || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa un nombre y un precio válido')),
      );
      return;
    }
    if (!context.read<CashSessionProvider>().isOpen) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Abre la caja antes de vender')),
      );
      return;
    }
    try {
      final created = await _productRepository.create(Product(
        id: '',
        name: name,
        price: price,
        stockQuantity: 0,
        trackStock: false,
        active: true,
        barcode: barcode,
      ));
      if (!mounted) return;
      setState(() => _products = [..._products, created]);
      try {
        await _catalogRepository.upsert(barcode: barcode, name: name, suggestedPrice: price, source: 'store');
      } catch (_) {
        // Aporte al catálogo global es "mejor esfuerzo" — el producto ya
        // quedó guardado en el inventario propio de todas formas.
      }
      await _addToCart(created);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al crear el producto: $e')));
      }
    }
  }

  bool _matchesSearch(Product product) {
    final search = normalizeForSearch(_search);
    return search.isEmpty ||
        normalizeForSearch(product.name).contains(search) ||
        (product.barcode != null && normalizeForSearch(product.barcode!).contains(search)) ||
        (product.sku != null && normalizeForSearch(product.sku!).contains(search));
  }

  void _onSearchChanged(String value) {
    setState(() => _search = value);
    _syncSearchFromServer(value);
  }

  /// "_products" se carga una sola vez al entrar a Ventas. Si mientras
  /// tanto se agregó un producto nuevo desde otra pantalla (Lista de
  /// artículos) en la misma sesión, buscarlo acá no lo encontraría hasta
  /// volver a entrar a Ventas. Para evitarlo, además del filtro local, se
  /// busca en el servidor y se agregan al catálogo en memoria los
  /// productos que falten (sin sacar nada de lo que ya había).
  Future<void> _syncSearchFromServer(String term) async {
    final trimmed = term.trim();
    if (trimmed.isEmpty) return;
    final requestId = ++_searchSyncId;
    final results = await _productRepository.getPage(offset: 0, pageSize: 30, search: trimmed);
    if (!mounted || requestId != _searchSyncId) return;
    final knownIds = _products.map((p) => p.id).toSet();
    final missing = results.where((p) => !knownIds.contains(p.id)).toList();
    if (missing.isEmpty) return;
    setState(() => _products = [..._products, ...missing]);
  }

  /// Productos de una pestaña personalizada: los agregados uno por uno, más
  /// los de cada categoría completa que se haya agregado, en el orden en
  /// que se agregaron (sin repetir si un producto queda incluido por dos
  /// vías a la vez).
  List<Product> _productsForPage(String pageId) {
    final items = _pageItemsByPage[pageId] ?? const [];
    final byId = {for (final p in _products) p.id: p};
    final byCategory = <String, List<Product>>{};
    for (final p in _products) {
      if (p.categoryId != null) byCategory.putIfAbsent(p.categoryId!, () => []).add(p);
    }
    // Cada producto agregado uno por uno es su propio botón — se muestra
    // siempre, aunque el mismo producto esté agregado más de una vez (ej.
    // "Huevos 5x1000" y "Huevos 4x1000" del mismo producto, con nombre y
    // precio propios cada uno; o simplemente el mismo botón repetido sin
    // querer, para no esconder en silencio algo que sí se guardó). Solo se
    // evita que una categoría completa vuelva a mostrar un producto que ya
    // tiene su propio botón directo, o que ya salió por otra categoría.
    final directProductIds = items.where((i) => i.productId != null).map((i) => i.productId!).toSet();
    final result = <Product>[];
    final seenFromCategory = <String>{};
    for (final item in items) {
      if (item.productId != null) {
        final p = byId[item.productId];
        if (p == null) continue;
        final hasCustom = item.customName != null || item.customPrice != null;
        result.add(hasCustom ? p.copyWith(name: item.customName, price: item.customPrice) : p);
      } else if (item.categoryId != null) {
        for (final p in byCategory[item.categoryId] ?? const []) {
          if (!directProductIds.contains(p.id) && seenFromCategory.add(p.id)) {
            result.add(p);
          }
        }
      }
    }
    return result;
  }

  /// Orden de prioridad: "Más vendidos" > pestaña personalizada elegida >
  /// categoría del menú desplegable (o todas).
  List<Product> get _filteredProducts {
    if (_showTopSelling) {
      final byId = {for (final p in _products) p.id: p};
      return _topSellingIds.map((id) => byId[id]).whereType<Product>().where(_matchesSearch).toList();
    }
    if (_selectedPageId != null) {
      // Mientras no se busque nada, se muestra solo lo que se agregó a
      // mano a esta pestaña — pero en cuanto se escribe algo, se busca en
      // TODO el catálogo (no solo en lo ya agregado), para poder vender
      // cualquier producto sin salir de la pestaña ni tener que agregarlo
      // a ella primero.
      if (_search.trim().isNotEmpty) {
        return _products.where(_matchesSearch).toList();
      }
      return _productsForPage(_selectedPageId!).toList();
    }
    // Mismo criterio que en una pestaña: con una categoría específica
    // elegida, en cuanto se escribe algo en el buscador se busca en todo
    // el catálogo (no solo en esa categoría), para no dejar productos
    // "escondidos" solo porque están en otra categoría.
    if (_search.trim().isNotEmpty) {
      return _products.where(_matchesSearch).toList();
    }
    return _products.where((p) => _selectedCategoryId == null || p.categoryId == _selectedCategoryId).toList();
  }

  /// Editar el stock de un producto directo desde su mosaico en Ventas
  /// (toque en el badge de stock, no en el resto del mosaico — eso sigue
  /// agregando el producto al carrito). Se guarda como un ajuste (delta)
  /// contra el valor actual, con el mismo RPC que usa Inventario, y se
  /// actualiza el mosaico en memoria sin recargar todo el catálogo.
  Future<void> _editStock(Product product) async {
    final newStock = await showNumberPadDialog(
      context,
      title: product.name,
      initialValue: product.stockQuantity,
      allowDecimal: product.isSoldByWeight,
    );
    _refocusSearch();
    if (newStock == null || newStock == product.stockQuantity) return;

    try {
      await _productRepository.adjustStock(product.id, newStock - product.stockQuantity);
      if (!mounted) return;
      setState(() {
        _products = _products
            .map((p) => p.id == product.id ? p.copyWith(stockQuantity: newStock) : p)
            .toList();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al actualizar el stock: $e')));
      }
    }
  }

  Future<void> _createPage() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nueva pestaña'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Nombre',
            hintText: 'Ej. Verduras, Promos',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
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
    if (name == null || name.isEmpty || !mounted) {
      _refocusSearch();
      return;
    }
    final page = await _pageRepository.create(name);
    if (!mounted) return;
    setState(() {
      _pages = [..._pages, page];
      _pageItemsByPage[page.id] = [];
      _selectedPageId = page.id;
      _showTopSelling = false;
    });
    _refocusSearch();
  }

  Future<void> _managePage(PosPage page) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => PosPageManagerSheet(
        page: page,
        allProducts: _products,
        allCategories: _categories,
        items: _pageItemsByPage[page.id] ?? const [],
      ),
    );
    if (mounted) _loadData();
    _refocusSearch();
  }

  Future<void> _quickAddProductToPage(String pageId) async {
    final selected = await showDialog<Product>(
      context: context,
      builder: (_) => _ProductPickerDialog(productRepository: _productRepository),
    );
    if (selected == null || !mounted) {
      _refocusSearch();
      return;
    }
    final customized = await showPageItemCustomizeDialog(context, product: selected);
    if (customized == null || !mounted) {
      _refocusSearch();
      return;
    }
    final (customName, customPrice) = customized;
    try {
      await _pageRepository.addProduct(pageId, selected.id, customName: customName, customPrice: customPrice);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo agregar: $e')),
        );
      }
      _refocusSearch();
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${customName ?? selected.name} agregado a la pestaña')),
    );
    _loadData();
    _refocusSearch();
  }

  Future<void> _openCashSessionSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const CashSessionSheet(),
    );
    _refocusSearch();
  }

  Future<void> _scanBarcode() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (code != null && mounted) {
      final handled = await _tryAddWeightBarcode(code) || await _tryAddScannedBarcode(code);
      if (!handled && mounted) {
        _searchController.text = code;
        setState(() => _search = code);
      }
    }
    _refocusSearch();
  }

  Future<void> _addProduct() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ProductFormScreen(categories: _categories)),
    );
    if (changed == true) _loadData();
    _refocusSearch();
  }

  Future<void> _refreshOpenTicketCount() async {
    final session = context.read<CashSessionProvider>().current;
    if (session == null) {
      if (mounted) setState(() => _openTicketCount = 0);
      return;
    }
    final tickets = await _openTicketRepository.getForSession(session.id);
    if (mounted) setState(() => _openTicketCount = tickets.length);
  }

  Future<void> _openTicketsList() async {
    final session = context.read<CashSessionProvider>().current;
    if (session == null) return;
    final ticket = await showModalBottomSheet<OpenTicket>(
      context: context,
      isScrollControlled: true,
      builder: (_) => OpenTicketsSheet(cashSessionId: session.id),
    );
    if (ticket != null && mounted) {
      await _resumeTicket(ticket);
    }
    _refreshOpenTicketCount();
    _refocusSearch();
  }

  Future<void> _resumeTicket(OpenTicket ticket) async {
    final cart = context.read<CartProvider>();
    if (cart.items.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vacía o cobra el carrito actual antes de retomar un ticket')),
      );
      return;
    }

    final items = ticket.items.map((entry) {
      Product? found;
      if (entry.productId != null) {
        for (final p in _products) {
          if (p.id == entry.productId) {
            found = p;
            break;
          }
        }
      }
      Product product;
      List<Modifier> modifiers;
      if (found == null) {
        product = Product.quickItem(name: entry.productName, price: entry.unitPrice);
        modifiers = const [];
      } else if (found.isVariablePrice) {
        // El precio se definió al venderlo (no hay un "precio actual" del
        // catálogo que tenga sentido usar), así que se conserva el que
        // había cuando se dejó el ticket en espera.
        product = found.copyWith(price: entry.unitPrice);
        modifiers = const [];
      } else {
        product = found;
        modifiers = _modifiers.where((m) => entry.modifierIds.contains(m.id)).toList();
      }
      return CartItem(product: product, quantity: entry.quantity, modifiers: modifiers);
    }).toList();

    Customer? customer;
    if (ticket.customerId != null) {
      customer = await CustomerRepository().getById(ticket.customerId!);
    }
    Discount? discount;
    if (ticket.discountId != null) {
      discount = await DiscountRepository().getById(ticket.discountId!);
    }

    cart.loadItems(items, customer: customer, discount: discount);
    await _openTicketRepository.delete(ticket.id);
    _refreshOpenTicketCount();
  }

  @override
  Widget build(BuildContext context) {
    final cashSession = context.watch<CashSessionProvider>();
    final prefs = context.watch<AppPreferencesProvider>();
    final products = _filteredProducts;

    final banner = (!cashSession.loading && !cashSession.isOpen)
        ? MaterialBanner(
            content: const Text('La caja está cerrada. Ábrela para empezar a vender.'),
            actions: [
              TextButton(onPressed: _openCashSessionSheet, child: const Text('Abrir caja')),
            ],
          )
        : null;

    // Barra de arriba de color (sigue el color primario del tema, como el
    // AppBar del menú, para que se vea como una sola barra continua): el
    // buscador queda escondido detrás de un ícono de lupa hasta que se
    // toca, para que por defecto se vea limpia. El lector de código de
    // barras USB ya NO fuerza que este campo quede desplegado (eso tapaba
    // el botón de menú) — en su lugar, mientras está colapsado se mantiene
    // un campo de tamaño cero con el foco (ver más abajo), para que el
    // lector siga escribiendo ahí y agregando al carrito solo, sin ocupar
    // el lugar del buscador visible ni esconder el menú.
    final onPrimary = Theme.of(context).colorScheme.onPrimary;
    final searchExpanded = _searchExpanded;
    // Todo (menú, título, pestañas, buscador e íconos) en una sola línea:
    // cuando el buscador está colapsado (el caso normal) deja ver el resto;
    // al desplegarlo, ocupa el espacio de las pestañas mientras se escribe.
    final hasDrawer = Scaffold.maybeOf(context)?.hasDrawer ?? false;
    final searchBar = Material(
      color: Theme.of(context).colorScheme.primary,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            children: [
              if (searchExpanded) ...[
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  color: onPrimary,
                  tooltip: 'Cerrar buscador',
                  onPressed: () => setState(() {
                    _searchExpanded = false;
                    _searchController.clear();
                    _search = '';
                  }),
                ),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    autofocus: true,
                    style: TextStyle(color: onPrimary),
                    cursorColor: onPrimary,
                    decoration: InputDecoration(
                      hintText: prefs.usbScannerModeEnabled
                          ? 'Buscar producto o código (o escanea aquí)'
                          : 'Buscar producto o código',
                      hintStyle: TextStyle(color: onPrimary.withOpacity(0.75)),
                      border: InputBorder.none,
                    ),
                    onChanged: _onSearchChanged,
                    onSubmitted: _handleScanSubmit,
                  ),
                ),
              ] else ...[
                if (hasDrawer)
                  IconButton(
                    icon: const Icon(Icons.menu),
                    color: onPrimary,
                    tooltip: 'Menú',
                    onPressed: () => Scaffold.of(context).openDrawer(),
                  ),
                const Expanded(child: SizedBox()),
                // Campo invisible que solo existe para mantener el foco del
                // lector USB mientras el buscador está colapsado — así el
                // escaneo sigue agregando productos solo, sin necesitar que
                // el usuario abra el buscador ni tocar la pantalla. Un
                // tamaño 0x0 (como tenía antes) puede impedir que el campo
                // realmente reciba el foco del teclado en Flutter Web —
                // por eso usa un tamaño chico pero real, oculto con
                // Opacity(0) e IgnorePointer (para que no se pueda tocar
                // sin querer) en vez de tamaño cero.
                if (prefs.usbScannerModeEnabled)
                  SizedBox(
                    width: 36,
                    height: 36,
                    child: IgnorePointer(
                      child: Opacity(
                        opacity: 0,
                        child: TextField(
                          controller: _searchController,
                          focusNode: _searchFocusNode,
                          autofocus: true,
                          decoration: const InputDecoration(border: InputBorder.none),
                          onChanged: _onSearchChanged,
                          onSubmitted: _handleScanSubmit,
                        ),
                      ),
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.search),
                  color: onPrimary,
                  tooltip: 'Buscar producto o código',
                  onPressed: () => setState(() => _searchExpanded = true),
                ),
              ],
              if (prefs.cameraScanEnabled)
                IconButton(
                  icon: const Icon(Icons.qr_code_scanner),
                  color: onPrimary,
                  tooltip: 'Escanear código de barras',
                  onPressed: _scanBarcode,
                ),
              Badge(
                label: Text('$_openTicketCount'),
                isLabelVisible: _openTicketCount > 0,
                child: IconButton(
                  icon: const Icon(Icons.receipt_long_outlined),
                  color: onPrimary,
                  disabledColor: onPrimary.withOpacity(0.45),
                  tooltip: 'Tickets en espera',
                  onPressed: cashSession.isOpen ? _openTicketsList : null,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_box_outlined),
                color: onPrimary,
                tooltip: 'Agregar producto',
                onPressed: _addProduct,
              ),
            ],
          ),
        ),
      ),
    );

    final filtersAndGrid = RefreshIndicator(
      onRefresh: _loadData,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
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
                ..._categories.map((category) => DropdownMenuItem(value: category.id, child: Text(category.name))),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedCategoryId = value;
                  _showTopSelling = false;
                  _selectedPageId = null;
                });
                _refocusSearch();
              },
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : (products.isEmpty && _selectedPageId == null)
                    ? Center(
                        child: Text(_showTopSelling ? 'Todavía no hay ventas para mostrar' : 'No hay productos'),
                      )
                    : prefs.useListLayout
                        ? _buildList(products, cashSession)
                        : _buildTileGrid(products, cashSession),
          ),
        ],
      ),
    );

    final quickSaleBar = _buildQuickSaleBar();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isSplitWide = constraints.maxWidth >= _splitLayoutBreakpoint;
        final cartPanel = CartPanel(
          compact: !isSplitWide,
          onSaleCompleted: () {
            _loadData();
            _refreshOpenTicketCount();
          },
          onTicketHeld: () {
            _loadData();
            _refreshOpenTicketCount();
          },
          onCheckoutClosed: _refocusSearch,
        );
        // Pantalla ancha (tablet horizontal, computador): el carrito va
        // siempre lado a lado, completo, a la derecha, y las pestañas de
        // venta rápida quedan abajo de todo, ocupando el ancho completo.
        if (isSplitWide) {
          return Column(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        children: [
                          if (banner != null) banner,
                          searchBar,
                          Expanded(child: filtersAndGrid),
                        ],
                      ),
                    ),
                    const VerticalDivider(width: 1),
                    SizedBox(width: 400, child: cartPanel),
                  ],
                ),
              ),
              quickSaleBar,
            ],
          );
        }
        // Pantalla angosta (celular, tablet vertical): el carrito va arriba,
        // justo debajo del buscador — no debajo del mosaico — y al
        // desplegarlo ocupa casi toda la pantalla (de lado a lado, y con
        // bastante alto) para revisar el detalle antes de cobrar; el
        // mosaico de productos queda con lo que sobra, y las pestañas de
        // venta rápida quedan al final, abajo de todo.
        return Column(
          children: [
            if (banner != null) banner,
            searchBar,
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: constraints.maxHeight * 0.8),
              child: cartPanel,
            ),
            const Divider(height: 1),
            Expanded(child: filtersAndGrid),
            quickSaleBar,
          ],
        );
      },
    );
  }

  /// Pestañas de acceso rápido (Más vendidos + pestañas personalizadas,
  /// creadas a mano por el usuario con cualquier artículo que quiera para
  /// venta rápida — no son categorías) en su propia barra al final de la
  /// pantalla, cerca de donde se toca para vender, en vez de arriba junto
  /// al buscador. El filtro por categoría real del catálogo es aparte
  /// (dropdown "Categoría" arriba del mosaico), para no confundir una cosa
  /// con la otra.
  Widget _buildQuickSaleBar() {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 4,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _quickTabButton(
                  label: 'Más vendidos',
                  icon: Icons.trending_up,
                  selected: _showTopSelling,
                  onTap: () {
                    final value = !_showTopSelling;
                    setState(() {
                      _showTopSelling = value;
                      if (value) {
                        _selectedPageId = null;
                        _selectedCategoryId = null;
                      }
                    });
                    _refocusSearch();
                  },
                ),
                for (final page in _pages) ...[
                  const SizedBox(width: 8),
                  _quickTabButton(
                    label: page.name,
                    selected: _selectedPageId == page.id,
                    onTap: () {
                      final value = _selectedPageId != page.id;
                      setState(() {
                        _selectedPageId = value ? page.id : null;
                        _showTopSelling = false;
                        if (value) _selectedCategoryId = null;
                      });
                      _refocusSearch();
                    },
                  ),
                ],
                const SizedBox(width: 4),
                IconButton(
                  icon: Icon(Icons.add_circle_outline, color: onSurface),
                  tooltip: 'Crear pestaña',
                  onPressed: _createPage,
                ),
                if (_selectedPageId != null)
                  IconButton(
                    icon: Icon(Icons.settings_outlined, color: onSurface),
                    tooltip: 'Editar esta pestaña',
                    onPressed: () {
                      final page = _pages.where((p) => p.id == _selectedPageId);
                      if (page.isNotEmpty) _managePage(page.first);
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Botón cuadrado (esquinas apenas redondeadas, no en píldora) y más
  /// grande que un Chip normal de Material — para que "Más vendidos" y cada
  /// pestaña personalizada sean fáciles de tocar y de leer de un vistazo
  /// mientras se vende.
  Widget _quickTabButton({
    required String label,
    IconData? icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final bg = selected ? colorScheme.primary : colorScheme.surfaceContainerHighest;
    final fg = selected ? colorScheme.onPrimary : colorScheme.onSurface;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        constraints: const BoxConstraints(minWidth: 88, minHeight: 60),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: selected ? null : Border.all(color: colorScheme.outlineVariant),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20, color: fg),
              const SizedBox(height: 4),
            ],
            Text(
              label,
              style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 14),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _priceLabel(Product product, {bool bold = false, Color? color}) {
    final baseStyle = TextStyle(color: color, fontSize: bold ? 14 : 12);
    if (product.isVariablePrice) {
      return Text('Precio variable', style: baseStyle.copyWith(fontStyle: FontStyle.italic));
    }
    if (product.isSoldByWeight) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CurrencyText(product.price, bold: bold, style: TextStyle(color: color)),
          Text(' /kg', style: baseStyle),
        ],
      );
    }
    return CurrencyText(product.price, bold: bold, style: TextStyle(color: color));
  }

  /// Mosaico de productos, parecido a una vitrina: foto de fondo con el
  /// precio arriba y el nombre superpuesto abajo para los que tienen foto,
  /// un círculo gris con precio y nombre para los que no. La cantidad de
  /// columnas se ajusta sola al ancho disponible (unas 5 en una tablet
  /// ancha, menos en un celular). En una pestaña personalizada, mantener
  /// presionado en cualquier parte (o tocar el mosaico "Agregar producto"
  /// al final) abre el buscador para agregar un producto ahí.
  Widget _buildTileGrid(List<Product> products, CashSessionProvider cashSession) {
    final pageId = _selectedPageId;
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = (constraints.maxWidth / _targetTileWidth).floor().clamp(2, 8).toInt();
        final grid = GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.92,
          ),
          itemCount: products.length + (pageId != null ? 1 : 0),
          itemBuilder: (context, index) {
            if (pageId != null && index == products.length) {
              return _addTile(pageId);
            }
            return _buildTile(products[index], cashSession);
          },
        );
        if (pageId == null) return grid;
        return GestureDetector(
          onLongPress: () => _quickAddProductToPage(pageId),
          child: grid,
        );
      },
    );
  }

  Widget _addTile(String pageId) {
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      color: Colors.grey.shade100,
      child: InkWell(
        onTap: () => _quickAddProductToPage(pageId),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_circle_outline, size: 32, color: Colors.grey),
              SizedBox(height: 6),
              Text('Agregar\nproducto', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTile(Product product, CashSessionProvider cashSession) {
    // "Agotado" es solo informativo (el badge de abajo) — se puede seguir
    // vendiendo igual, y el stock queda en negativo (se avisa antes de
    // cobrar, ver _confirmNegativeStock en checkout_sheet.dart).
    final outOfStock = product.trackStock && product.stockQuantity <= 0;
    final hasImage = product.imageUrl != null && product.imageUrl!.isNotEmpty;
    final canTap = cashSession.isOpen;

    return _ProductTile(
      cardColor: hasImage ? null : Colors.grey.shade50,
      onTap: canTap ? () => _addToCart(product) : null,
      child: hasImage ? _photoTile(product, outOfStock) : _placeholderTile(product, outOfStock),
    );
  }

  Widget _priceBadge(Product product, {required bool overlay}) {
    final label = _priceLabel(product, bold: true, color: overlay ? Colors.white : Colors.black87);
    if (!overlay) return label;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(6),
      ),
      child: label,
    );
  }

  /// Solo aparece si el producto controla inventario (igual que "Agotado").
  /// Tocarlo abre el popup para editar el stock (ver _editStock) — el resto
  /// del mosaico sigue agregando el producto al carrito con normalidad.
  Widget _stockBadge(Product product, {required bool overlay}) {
    if (!product.trackStock) return const SizedBox.shrink();
    final label = product.isSoldByWeight
        ? product.stockQuantity.toStringAsFixed(3)
        : product.stockQuantity.toStringAsFixed(0);
    final fg = overlay ? Colors.white : Colors.black87;
    return GestureDetector(
      onTap: () => _editStock(product),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: overlay ? Colors.black.withOpacity(0.6) : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inventory_2_outlined, size: 12, color: fg),
            const SizedBox(width: 3),
            Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
          ],
        ),
      ),
    );
  }

  /// Foto a pantalla completa, precio arriba en una etiqueta y el nombre en
  /// una franja oscura abajo.
  Widget _photoTile(Product product, bool outOfStock) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.network(
          product.imageUrl!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade200),
        ),
        Positioned(
          top: 6,
          left: 6,
          child: _priceBadge(product, overlay: true),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(8, 18, 8, 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withOpacity(0.75)],
              ),
            ),
            child: Text(
              product.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ),
        if (outOfStock)
          Container(
            color: Colors.black.withOpacity(0.55),
            alignment: Alignment.center,
            child: const StatusBadge(label: 'AGOTADO', tone: StatusBadgeTone.danger),
          ),
        Positioned(
          top: 6,
          right: 6,
          child: _stockBadge(product, overlay: true),
        ),
      ],
    );
  }

  /// Sin foto: precio arriba, un círculo gris (como una estantería sin
  /// etiqueta) y el nombre debajo — para que la grilla se vea igual de
  /// ordenada aunque no todos los productos tengan foto todavía.
  Widget _placeholderTile(Product product, bool outOfStock) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _priceBadge(product, overlay: false),
              _stockBadge(product, overlay: false),
            ],
          ),
          Expanded(
            child: Center(
              child: ProductAvatar(name: product.name, categoryId: product.categoryId, radius: 28),
            ),
          ),
          Text(
            product.name,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black87),
          ),
          if (outOfStock)
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: StatusBadge(label: 'Agotado', tone: StatusBadgeTone.danger, dense: true),
            ),
        ],
      ),
    );
  }

  Widget _buildList(List<Product> products, CashSessionProvider cashSession) {
    return ListView.builder(
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        final outOfStock = product.trackStock && product.stockQuantity <= 0;
        return ListTile(
          leading: ProductAvatar(name: product.name, categoryId: product.categoryId, imageUrl: product.imageUrl),
          title: Text(product.name),
          subtitle: outOfStock
              ? const Align(alignment: Alignment.centerLeft, child: StatusBadge(label: 'Agotado', tone: StatusBadgeTone.danger, dense: true))
              : product.trackStock
                  ? Text('Stock: ${product.stockQuantity.toStringAsFixed(0)}')
                  : null,
          trailing: _priceLabel(product, bold: true),
          enabled: cashSession.isOpen,
          onTap: () => _addToCart(product),
        );
      },
    );
  }
}

/// Envuelve un mosaico de producto para dar un feedback breve (rebote +
/// ícono de check) al tocarlo y agregarlo al carrito, en vez de que el
/// único cambio visible sea en el panel del carrito (que puede quedar
/// fuera de foco en pantallas angostas).
class _ProductTile extends StatefulWidget {
  final Widget child;
  final Color? cardColor;
  final VoidCallback? onTap;

  const _ProductTile({required this.child, required this.cardColor, required this.onTap});

  @override
  State<_ProductTile> createState() => _ProductTileState();
}

class _ProductTileState extends State<_ProductTile> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _checkOpacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 260));
    _scale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.94), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 0.94, end: 1.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _checkOpacity = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 2),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    final onTap = widget.onTap;
    if (onTap == null) return;
    onTap();
    _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Transform.scale(
          scale: _scale.value,
          child: Card(
            clipBehavior: Clip.antiAlias,
            margin: EdgeInsets.zero,
            color: widget.cardColor,
            child: Stack(
              fit: StackFit.expand,
              children: [
                InkWell(onTap: widget.onTap == null ? null : _handleTap, child: widget.child),
                if (_checkOpacity.value > 0)
                  IgnorePointer(
                    child: Opacity(
                      opacity: _checkOpacity.value,
                      child: Container(
                        color: Colors.black.withOpacity(0.25),
                        alignment: Alignment.center,
                        child: const Icon(Icons.check_circle, color: Colors.white, size: 40),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Diálogo simple para buscar y elegir un producto — usado para agregarlo a
/// una pestaña personalizada de Ventas.
///
/// Busca directo en el servidor (igual que "Lista de artículos") en vez de
/// filtrar la lista de productos ya cargada en la pantalla de Ventas: así
/// siempre ve el catálogo al día, aunque se haya agregado un producto nuevo
/// desde otra pantalla sin volver a entrar a Ventas.
class _ProductPickerDialog extends StatefulWidget {
  final ProductRepository productRepository;

  const _ProductPickerDialog({required this.productRepository});

  @override
  State<_ProductPickerDialog> createState() => _ProductPickerDialogState();
}

class _ProductPickerDialogState extends State<_ProductPickerDialog> {
  final _controller = TextEditingController();
  List<Product> _results = [];
  bool _loading = true;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search(String term) async {
    final requestId = ++_requestId;
    setState(() => _loading = true);
    final results = await widget.productRepository.getPage(offset: 0, pageSize: 30, search: term.trim());
    if (!mounted || requestId != _requestId) return;
    setState(() {
      _results = results;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Buscar producto para agregar'),
      content: SizedBox(
        width: 400,
        height: 400,
        child: Column(
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Buscar producto o código',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: _search,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _results.isEmpty
                      ? const Center(child: Text('Sin resultados'))
                      : ListView.builder(
                          itemCount: _results.length,
                          itemBuilder: (context, index) {
                            final p = _results[index];
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundImage: p.imageUrl != null ? NetworkImage(p.imageUrl!) : null,
                                child: p.imageUrl == null ? const Icon(Icons.inventory_2, size: 18) : null,
                              ),
                              title: Text(p.name),
                              onTap: () => Navigator.of(context).pop(p),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
      ],
    );
  }
}
