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
import '../../providers/product_cache_provider.dart';
import '../../services/category_repository.dart';
import '../../services/customer_repository.dart';
import '../../services/discount_repository.dart';
import '../../services/modifier_repository.dart';
import '../../services/open_ticket_repository.dart';
import '../../services/pos_page_repository.dart';
import '../../services/product_catalog_repository.dart';
import '../../services/product_repository.dart';
import '../../services/product_search_index.dart';
import '../../services/reports_repository.dart';
import '../../widgets/error_state.dart';
import '../../widgets/number_pad_dialog.dart';
import '../inventory/product_form_screen.dart';
import '../scan/barcode_scanner_screen.dart';
import 'cart_panel.dart';
import 'cash_session_sheet.dart';
import 'modifier_picker_sheet.dart';
import 'open_tickets_sheet.dart';
import 'page_item_customize_dialog.dart';
import 'pos_page_manager_sheet.dart';
import 'pos_product_browser.dart';
import 'pos_quick_sale_bar.dart';
import 'pos_title_row.dart';
import 'product_picker_dialog.dart';

// El manejo de códigos de barras (normal y de balanza) vive en su propio
// archivo, pero como parte de esta misma librería (comparte los campos y
// métodos privados de _PosScreenState tal cual, sin tener que pasarse
// nada por parámetro) — ver pos_screen_scanner.dart.
part 'pos_screen_scanner.dart';

/// A partir de este ancho, Ventas se divide lado a lado (productos +
/// carrito); antes de eso queda apilado (productos arriba, carrito abajo),
/// pero el carrito SIEMPRE está visible en pantalla, nunca hay que abrirlo.
const double _splitLayoutBreakpoint = 900;

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
  // Índice local (nombre/código de barras/SKU normalizados + mapas directos
  // por código de barras y PLU) — se reconstruye cada vez que "_products"
  // cambia, para que la búsqueda escrita y el escaneo (USB o cámara) sean
  // rápidos aunque el catálogo tenga miles de artículos. Ver
  // ProductSearchIndex.
  ProductSearchIndex _searchIndex = ProductSearchIndex(const []);
  List<Category> _categories = [];
  List<Modifier> _modifiers = [];
  List<String> _topSellingIds = [];
  List<PosPage> _pages = [];
  Map<String, List<PosPageItem>> _pageItemsByPage = {};
  String? _selectedPageId;
  // En Ventas ya no hay filtro por categoría ni un estado "ninguna pestaña
  // elegida" que muestre todo el catálogo de una — siempre hay exactamente
  // una pestaña de acceso rápido activa (ver PosQuickSaleBar): "Más
  // vendidos" (la de por defecto) o una pestaña personalizada.
  bool _showTopSelling = true;
  String _search = '';
  int _searchSyncId = 0;
  Timer? _searchSyncDebounce;
  // El lector USB "escribe" un código de barras entero (8-13 dígitos) en
  // milisegundos, letra por letra — sin esto, cada dígito recalculaba el
  // filtro del mosaico entero (miles de productos), y se veía el mosaico
  // "buscando" de a poco antes de agregar el producto y limpiar el campo.
  // Con esta espera cortita, una persona escribiendo a mano no nota
  // ninguna diferencia (sigue viéndose instantáneo), pero un escaneo
  // completo termina recalculando el filtro una sola vez en vez de una por
  // cada dígito.
  Timer? _localFilterDebounce;
  // Categorías, modificadores y "más vendidos" cambian poco durante un
  // turno de venta — antes se volvían a pedir al servidor cada vez que se
  // volvía a Ventas desde otra pantalla (el menú lateral destruye y crea de
  // nuevo esta pantalla cada vez), generando conexiones de más sin
  // necesidad. Guardarlos acá (en un campo "static", no de la instancia)
  // hace que sobrevivan aunque se salga y vuelva a entrar a Ventas dentro
  // de la misma sesión; "Sincronizar" (botón de la barra) y "Actualizar
  // catálogo" (deslizar hacia abajo) los limpian para forzar que se pidan
  // de nuevo.
  static List<Category>? _cachedCategories;
  static List<Modifier>? _cachedModifiers;
  static List<String>? _cachedTopSellingIds;
  bool _loading = true;
  String? _error;
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
    _searchSyncDebounce?.cancel();
    _localFilterDebounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final productCache = context.read<ProductCacheProvider>();
      final results = await Future.wait([
        productCache.ensureLoaded(),
        _cachedCategories != null ? Future.value(_cachedCategories!) : _categoryRepository.getAll(),
        _cachedModifiers != null
            ? Future.value(_cachedModifiers!)
            : _modifierRepository.getAll(onlyActive: true),
        _cachedTopSellingIds != null
            ? Future.value(_cachedTopSellingIds!)
            : _reportsRepository.getTopSellingProductIds(),
        _pageRepository.getAll(),
        _pageRepository.getAllItems(),
      ]);
      if (!mounted) return;
      final categories = results[1] as List<Category>;
      final modifiers = results[2] as List<Modifier>;
      final topSellingIds = results[3] as List<String>;
      _cachedCategories = categories;
      _cachedModifiers = modifiers;
      _cachedTopSellingIds = topSellingIds;
      final pages = results[4] as List<PosPage>;
      final allItems = results[5] as List<PosPageItem>;
      final grouped = <String, List<PosPageItem>>{};
      for (final item in allItems) {
        grouped.putIfAbsent(item.pageId, () => []).add(item);
      }
      // El catálogo en sí viene del caché compartido (ver
      // ProductCacheProvider) — se pide una sola vez por sesión, no cada
      // vez que se vuelve a esta pestaña, para no gastar ancho de banda de
      // más. "Actualizar catálogo" (botón de la barra) lo refresca a mano.
      var products = productCache.products;
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
        // Un producto archivado no debe volver a aparecer en Ventas por
        // este camino tampoco (ver getAll(), que ya lo excluye del
        // catálogo principal más arriba).
        final newlyFound = missing.where((p) => !p.archived).toList();
        products = [...products, ...newlyFound];
        for (final p in newlyFound) {
          productCache.upsertLocal(p);
        }
      }
      setState(() {
        _products = products;
        _searchIndex = ProductSearchIndex(products);
        _categories = categories;
        _modifiers = modifiers;
        _topSellingIds = topSellingIds;
        _pages = pages;
        _pageItemsByPage = grouped;
        if (_selectedPageId != null && !pages.any((p) => p.id == _selectedPageId)) {
          _selectedPageId = null;
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo cargar el catálogo de Ventas: $e';
        _loading = false;
      });
    }
  }

  Future<void> _addToCart(Product product) async {
    try {
      var effective = product;
      // Oferta temporal: se vende al precio de oferta mientras esté
      // vigente, sin que el cajero tenga que acordarse de aplicarla.
      if (effective.isPromoActive) {
        effective = effective.copyWith(price: effective.effectivePrice);
      }
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
    _localFilterDebounce?.cancel();
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

  /// Posición de la pestaña de acceso rápido activa dentro de la secuencia
  /// "Más vendidos" + pestañas personalizadas. Siempre hay una elegida (por
  /// defecto "Más vendidos", índice 0) — ya no existe un estado "ninguna
  /// pestaña" que muestre todo el catálogo de una. La usa el gesto de
  /// deslizar para saber a cuál moverse.
  int get _currentQuickTabIndex {
    if (_showTopSelling) return 0;
    final index = _pages.indexWhere((p) => p.id == _selectedPageId);
    return index == -1 ? 0 : index + 1;
  }

  void _selectQuickTabIndex(int index) {
    if (index <= 0) {
      setState(() {
        _showTopSelling = true;
        _selectedPageId = null;
      });
    } else {
      setState(() {
        _showTopSelling = false;
        _selectedPageId = _pages[index - 1].id;
      });
    }
    _refocusSearch();
  }

  /// Deslizar con el dedo sobre el mosaico/lista mueve a la pestaña de
  /// acceso rápido siguiente (izquierda) o anterior (derecha) — un umbral
  /// de velocidad evita que un scroll vertical normal se confunda con el
  /// gesto.
  void _handleQuickTabSwipe(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() < 200) return;
    final current = _currentQuickTabIndex;
    final next = velocity < 0 ? current + 1 : current - 1;
    if (next < 0 || next >= _pages.length + 1) return;
    _selectQuickTabIndex(next);
  }

  /// El catálogo se carga ya ordenado A-Z desde el servidor; agregar un
  /// producto nuevo o "recién encontrado" directo al final de la lista en
  /// memoria (ver arriba) lo dejaría fuera de orden hasta la próxima vez
  /// que se entre a Ventas — se reordena acá para que quede A-Z siempre.
  List<Product> _sortedByName(List<Product> products) =>
      products..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  void _onSearchChanged(String value) {
    _localFilterDebounce?.cancel();
    _localFilterDebounce = Timer(const Duration(milliseconds: 120), () {
      if (mounted) setState(() => _search = value);
    });
    // Sin esperar un poco, cada letra tecleada mandaba su propia consulta
    // al servidor (buscar "coca cola" eran 9 consultas en vez de 1) — el
    // filtro local ya responde casi al instante con lo que hay en memoria,
    // así que esta sincronización con el servidor puede esperar todavía
    // más, a que la persona deje de escribir.
    _searchSyncDebounce?.cancel();
    _searchSyncDebounce = Timer(const Duration(milliseconds: 400), () => _syncSearchFromServer(value));
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
    setState(() {
      _products = _sortedByName([..._products, ...missing]);
      _searchIndex = ProductSearchIndex(_products);
    });
    final productCache = context.read<ProductCacheProvider>();
    for (final p in missing) {
      productCache.upsertLocal(p);
    }
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

  /// La única forma de elegir qué se ve en Ventas son las pestañas de abajo
  /// ("Más vendidos" o una pestaña personalizada) — ya no hay filtro por
  /// categoría ni un estado "ninguna pestaña" que muestre todo el catálogo
  /// de una. En cuanto se escribe algo o se escanea (búsqueda de texto o de
  /// código), se busca de fondo en TODO el catálogo, no solo en la pestaña
  /// activa, usando el índice local (ver ProductSearchIndex) para que sea
  /// rápido aunque haya miles de productos.
  List<Product> get _filteredProducts {
    if (_search.trim().isNotEmpty) {
      return _searchIndex.search(_search);
    }
    if (_selectedPageId != null) {
      return _productsForPage(_selectedPageId!).toList();
    }
    // "Más vendidos": pestaña por defecto y respaldo si por algún motivo no
    // hay ninguna pestaña personalizada elegida.
    final byId = {for (final p in _products) p.id: p};
    return _topSellingIds.map((id) => byId[id]).whereType<Product>().toList();
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
      final updated = product.copyWith(stockQuantity: newStock);
      setState(() {
        _products = _products.map((p) => p.id == product.id ? updated : p).toList();
        _searchIndex = ProductSearchIndex(_products);
      });
      context.read<ProductCacheProvider>().upsertLocal(updated);
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
      builder: (_) => ProductPickerDialog(productRepository: _productRepository),
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

  /// Vuelve a pedir el catálogo entero al servidor (a diferencia de
  /// [_loadData], que reusa el caché compartido si ya estaba cargado) —
  /// para cuando de verdad hace falta ver un cambio reflejado al toque:
  /// tras crear/editar un producto completo, o al tocar "Actualizar
  /// catálogo" a mano.
  Future<void> _reloadCatalogAndData() async {
    _cachedCategories = null;
    _cachedModifiers = null;
    _cachedTopSellingIds = null;
    await context.read<ProductCacheProvider>().refresh();
    await _loadData();
  }

  Future<void> _addProduct() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ProductFormScreen(categories: _categories)),
    );
    if (changed == true) await _reloadCatalogAndData();
    _refocusSearch();
  }

  /// Editar el artículo completo (nombre, precio, foto, categoría, etc.)
  /// sin salir de Ventas — antes solo se podía desde Lista de artículos.
  Future<void> _editProduct(Product product) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ProductFormScreen(product: product, categories: _categories)),
    );
    if (changed == true) await _reloadCatalogAndData();
    _refocusSearch();
  }

  Future<void> _refreshOpenTicketCount() async {
    // Los tickets ya no se limitan al turno actual (ver
    // OpenTicketRepository.getAll) — el contador se muestra igual sin
    // importar si hay una caja abierta ahora mismo.
    final tickets = await _openTicketRepository.getAll();
    if (mounted) setState(() => _openTicketCount = tickets.length);
  }

  Future<void> _openTicketsList() async {
    final session = context.read<CashSessionProvider>().current;
    if (session == null) return;
    final ticket = await showModalBottomSheet<OpenTicket>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const OpenTicketsSheet(),
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
    final titleRow = PosTitleRow(cashSession: cashSession);

    final banner = (!cashSession.loading && !cashSession.isOpen)
        ? MaterialBanner(
            content: const Text('La caja está cerrada. Ábrela para empezar a vender.'),
            actions: [
              TextButton(onPressed: _openCashSessionSheet, child: const Text('Abrir caja')),
            ],
          )
        : null;

    // Barra de arriba clara (tarjeta blanca con borde inferior, igual que el
    // resto de los inputs del nuevo tema, en vez del bloque de color sólido
    // de antes): el buscador queda escondido detrás de un ícono de lupa
    // hasta que se toca, para que por defecto se vea limpia. El lector de
    // código de barras USB ya NO fuerza que este campo quede desplegado (eso
    // tapaba el botón de menú) — en su lugar, mientras está colapsado se
    // mantiene un campo de tamaño cero con el foco (ver más abajo), para que
    // el lector siga escribiendo ahí y agregando al carrito solo, sin ocupar
    // el lugar del buscador visible ni esconder el menú.
    final onPrimary = Theme.of(context).colorScheme.onSurface;
    final searchExpanded = _searchExpanded;
    // Todo (menú, título, pestañas, buscador e íconos) en una sola línea:
    // cuando el buscador está colapsado (el caso normal) deja ver el resto;
    // al desplegarlo, ocupa el espacio de las pestañas mientras se escribe.
    final hasDrawer = Scaffold.maybeOf(context)?.hasDrawer ?? false;
    final searchBar = Material(
      color: Theme.of(context).cardColor,
      child: Container(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
        ),
        child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              if (searchExpanded) ...[
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  color: onPrimary,
                  tooltip: 'Cerrar buscador',
                  onPressed: () {
                    _localFilterDebounce?.cancel();
                    setState(() {
                      _searchExpanded = false;
                      _searchController.clear();
                      _search = '';
                    });
                  },
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
                //
                // A propósito NO lleva "keyboardType: none": se probó y
                // rompía el auto-agregado del lector mientras el buscador
                // está colapsado (Android parece no dejar entrar el texto
                // del lector si el campo nunca recibió un toque real de
                // verdad y su tipo de teclado es "none"). Como este campo
                // nunca se puede tocar (ver IgnorePointer arriba), preferimos
                // que a veces se le escape el teclado de Android a que deje
                // de escanear solo.
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
                icon: const Icon(Icons.sync),
                color: onPrimary,
                disabledColor: onPrimary.withOpacity(0.45),
                tooltip: 'Sincronizar (pedir catálogo, categorías y modificadores al servidor ahora)',
                onPressed: _loading ? null : _reloadCatalogAndData,
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
      ),
    );

    final filtersAndGrid = GestureDetector(
      // Deslizar con el dedo hacia la izquierda o derecha sobre el mosaico
      // mueve a la pestaña de acceso rápido siguiente/anterior, sin tener
      // que ir a tocarla abajo — el umbral de velocidad en
      // _handleQuickTabSwipe evita que se confunda con el scroll vertical
      // normal de la lista/mosaico.
      onHorizontalDragEnd: _handleQuickTabSwipe,
      child: RefreshIndicator(
        // Deslizar hacia abajo para refrescar ahora vuelve a pedir el
        // catálogo completo (no solo lo que ya estaba en caché) — es el
        // gesto natural para "quiero ver los cambios ahora mismo" sin
        // tener que agregar un botón aparte.
        onRefresh: _reloadCatalogAndData,
        child: Column(
          children: [
            const SizedBox(height: 8),
            Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? ErrorState(message: _error!, onRetry: _loadData)
                    : (products.isEmpty && _selectedPageId == null)
                        ? Center(
                            child: Text(_search.trim().isNotEmpty
                                ? 'No se encontraron productos'
                                : (_showTopSelling ? 'Todavía no hay ventas para mostrar' : 'No hay productos')),
                          )
                        : PosProductBrowser(
                            products: products,
                            useListLayout: prefs.useListLayout,
                            cashSession: cashSession,
                            selectedPageId: _selectedPageId,
                            onAddToCart: _addToCart,
                            onEditStock: _editStock,
                            onEditProduct: _editProduct,
                            onQuickAddToPage: _quickAddProductToPage,
                          ),
          ),
        ],
      ),
      ),
    );

    final quickSaleBar = PosQuickSaleBar(
      showTopSelling: _showTopSelling,
      pages: _pages,
      selectedPageId: _selectedPageId,
      onSelectTopSelling: () {
        setState(() {
          _showTopSelling = true;
          _selectedPageId = null;
        });
        _refocusSearch();
      },
      onSelectPage: (page) {
        setState(() {
          _selectedPageId = page.id;
          _showTopSelling = false;
        });
        _refocusSearch();
      },
      onCreatePage: _createPage,
      onManagePage: _managePage,
    );

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
                          titleRow,
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
            titleRow,
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
}
