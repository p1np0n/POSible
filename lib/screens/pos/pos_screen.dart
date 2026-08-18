import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/cart_item.dart';
import '../../models/category.dart';
import '../../models/customer.dart';
import '../../models/discount.dart';
import '../../models/modifier.dart';
import '../../models/open_ticket.dart';
import '../../models/product.dart';
import '../../providers/app_preferences_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/cash_session_provider.dart';
import '../../services/category_repository.dart';
import '../../services/customer_repository.dart';
import '../../services/discount_repository.dart';
import '../../services/modifier_repository.dart';
import '../../services/open_ticket_repository.dart';
import '../../services/product_repository.dart';
import '../../services/reports_repository.dart';
import '../../widgets/currency_text.dart';
import '../inventory/product_form_screen.dart';
import '../scan/barcode_scanner_screen.dart';
import 'cart_panel.dart';
import 'cash_session_sheet.dart';
import 'modifier_picker_sheet.dart';
import 'open_tickets_sheet.dart';
import 'quick_item_dialog.dart';

/// A partir de este ancho, Ventas se divide lado a lado (productos +
/// carrito); antes de eso queda apilado (productos arriba, carrito abajo),
/// pero el carrito SIEMPRE está visible en pantalla, nunca hay que abrirlo.
const double _splitLayoutBreakpoint = 900;

/// Ancho aproximado de cada mosaico de producto — a partir de esto se
/// calculan cuántas columnas caben según el ancho real de la pantalla (en
/// una tablet ancha da unas 5 por línea, como se pidió).
const double _targetTileWidth = 168.0;

/// Colores de fondo para productos sin foto (se elige uno según el nombre,
/// para que cada uno se distinga a simple vista en la grilla).
const List<Color> _placeholderPalette = [
  Color(0xFFE3C097),
  Color(0xFFB5D8CC),
  Color(0xFFF2C6C2),
  Color(0xFFC9D6EA),
  Color(0xFFEAD7B7),
  Color(0xFFCBE4B4),
  Color(0xFFE6C9E0),
  Color(0xFFBEE3DB),
];

Color _colorForName(String name) => _placeholderPalette[name.hashCode.abs() % _placeholderPalette.length];

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> with SingleTickerProviderStateMixin {
  final ProductRepository _productRepository = ProductRepository();
  final CategoryRepository _categoryRepository = CategoryRepository();
  final ModifierRepository _modifierRepository = ModifierRepository();
  final OpenTicketRepository _openTicketRepository = OpenTicketRepository();
  final ReportsRepository _reportsRepository = ReportsRepository();
  final _searchController = TextEditingController();

  List<Product> _products = [];
  List<Category> _categories = [];
  List<Modifier> _modifiers = [];
  List<String> _topSellingIds = [];
  String _search = '';
  bool _loading = true;
  int _openTicketCount = 0;
  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<CashSessionProvider>().refresh();
      _refreshOpenTicketCount();
    });
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      _productRepository.getAll(),
      _categoryRepository.getAll(),
      _modifierRepository.getAll(onlyActive: true),
      _reportsRepository.getTopSellingProductIds(),
    ]);
    if (!mounted) return;
    final categories = results[1] as List<Category>;
    setState(() {
      _products = results[0] as List<Product>;
      _categories = categories;
      _modifiers = results[2] as List<Modifier>;
      _topSellingIds = results[3] as List<String>;
      _loading = false;
    });
    // "Más vendidos" + "Todos" + una pestaña por categoría. Se arranca en
    // "Todos" (índice 1) para no confundir a una tienda nueva sin ventas
    // todavía, pero "Más vendidos" queda a un toque de distancia.
    _ensureTabController(categories.length + 2, defaultIndex: 1);
  }

  void _ensureTabController(int length, {int defaultIndex = 0}) {
    if (_tabController != null && _tabController!.length == length) return;
    final previousIndex = _tabController?.index ?? defaultIndex;
    _tabController?.dispose();
    _tabController = TabController(
      length: length,
      vsync: this,
      initialIndex: previousIndex < length ? previousIndex : 0,
    );
    if (mounted) setState(() {});
  }

  Future<void> _addToCart(Product product) async {
    var effective = product;
    if (product.isVariablePrice) {
      final price = await _askVariablePrice(product);
      if (price == null || !mounted) return;
      effective = product.copyWith(price: price);
    }
    if (_modifiers.isEmpty) {
      context.read<CartProvider>().addProduct(effective);
      return;
    }
    final selected = await showModalBottomSheet<List<Modifier>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ModifierPickerSheet(product: effective, modifiers: _modifiers),
    );
    if (selected != null && mounted) {
      context.read<CartProvider>().addProduct(effective, modifiers: selected);
    }
  }

  /// Pide el precio de un artículo de precio variable antes de agregarlo al
  /// carrito (ej. un servicio o algo sin precio fijo en el catálogo).
  Future<double?> _askVariablePrice(Product product) async {
    final controller = TextEditingController(
      text: product.price > 0 ? product.price.round().toString() : '',
    );
    return showDialog<double>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(product.name),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Precio', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              final price = double.tryParse(controller.text);
              if (price == null || price <= 0) return;
              Navigator.of(context).pop(price);
            },
            child: const Text('Agregar'),
          ),
        ],
      ),
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

  bool _matchesSearch(Product product) {
    final search = _search.toLowerCase();
    return search.isEmpty ||
        product.name.toLowerCase().contains(search) ||
        (product.barcode?.toLowerCase().contains(search) ?? false) ||
        (product.sku?.toLowerCase().contains(search) ?? false);
  }

  /// Productos para la pestaña "index": 0 = Más vendidos (ordenados de más a
  /// menos, según ventas de los últimos 30 días), 1 = Todos, 2 en adelante =
  /// una categoría cada una (en el mismo orden que "_categories").
  List<Product> _productsForTab(int index) {
    if (index == 0) {
      final byId = {for (final p in _products) p.id: p};
      return _topSellingIds.map((id) => byId[id]).whereType<Product>().where(_matchesSearch).toList();
    }
    if (index == 1) {
      return _products.where(_matchesSearch).toList();
    }
    final category = _categories[index - 2];
    return _products.where((p) => p.categoryId == category.id && _matchesSearch(p)).toList();
  }

  void _openCashSessionSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const CashSessionSheet(),
    );
  }

  Future<void> _scanBarcode() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (code != null && mounted) {
      final handled = await _tryAddWeightBarcode(code);
      if (!handled && mounted) {
        _searchController.text = code;
        setState(() => _search = code);
      }
    }
  }

  Future<void> _addProduct() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ProductFormScreen(categories: _categories)),
    );
    if (changed == true) _loadData();
  }

  Future<void> _addQuickItem() async {
    final product = await showDialog<Product>(
      context: context,
      builder: (_) => const QuickItemDialog(),
    );
    if (product != null && mounted) {
      context.read<CartProvider>().addProduct(product);
    }
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
    final tabController = _tabController;

    final productsPanel = RefreshIndicator(
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
                    onSubmitted: (value) async {
                      final handled = await _tryAddWeightBarcode(value);
                      if (handled && mounted) {
                        _searchController.clear();
                        setState(() => _search = '');
                      }
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_box_outlined),
                  tooltip: 'Agregar producto',
                  onPressed: _addProduct,
                ),
                if (prefs.cameraScanEnabled)
                  IconButton(
                    icon: const Icon(Icons.qr_code_scanner),
                    tooltip: 'Escanear código de barras',
                    onPressed: _scanBarcode,
                  ),
                IconButton(
                  icon: const Icon(Icons.flash_on),
                  tooltip: 'Artículo rápido',
                  onPressed: cashSession.isOpen ? _addQuickItem : null,
                ),
                Badge(
                  label: Text('$_openTicketCount'),
                  isLabelVisible: _openTicketCount > 0,
                  child: IconButton(
                    icon: const Icon(Icons.receipt_long_outlined),
                    tooltip: 'Tickets en espera',
                    onPressed: cashSession.isOpen ? _openTicketsList : null,
                  ),
                ),
              ],
            ),
          ),
          if (tabController != null)
            TabBar(
              controller: tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                const Tab(text: 'Más vendidos'),
                const Tab(text: 'Todos'),
                ..._categories.map((category) => Tab(text: category.name)),
              ],
            ),
          const SizedBox(height: 4),
          Expanded(
            child: _loading || tabController == null
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: tabController,
                    children: List.generate(tabController.length, (index) {
                      final products = _productsForTab(index);
                      if (products.isEmpty) {
                        return Center(
                          child: Text(index == 0 ? 'Todavía no hay ventas para mostrar' : 'No hay productos'),
                        );
                      }
                      return prefs.useListLayout
                          ? _buildList(products, cashSession)
                          : _buildTileGrid(products, cashSession);
                    }),
                  ),
          ),
        ],
      ),
    );

    final cartPanel = CartPanel(
      onSaleCompleted: () {
        _loadData();
        _refreshOpenTicketCount();
      },
      onTicketHeld: () {
        _loadData();
        _refreshOpenTicketCount();
      },
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isSplitWide = constraints.maxWidth >= _splitLayoutBreakpoint;
        if (isSplitWide) {
          return Row(
            children: [
              Expanded(flex: 3, child: productsPanel),
              const VerticalDivider(width: 1),
              SizedBox(width: 400, child: cartPanel),
            ],
          );
        }
        return Column(
          children: [
            Expanded(child: productsPanel),
            const Divider(height: 1),
            SizedBox(height: constraints.maxHeight * 0.42, child: cartPanel),
          ],
        );
      },
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

  /// Mosaico de fotos (como una vitrina): la cantidad de columnas se ajusta
  /// sola al ancho disponible (unas 5 en una tablet ancha, menos en un
  /// celular), en vez de un número fijo.
  Widget _buildTileGrid(List<Product> products, CashSessionProvider cashSession) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = (constraints.maxWidth / _targetTileWidth).floor().clamp(2, 8).toInt();
        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.92,
          ),
          itemCount: products.length,
          itemBuilder: (context, index) => _buildTile(products[index], cashSession),
        );
      },
    );
  }

  Widget _buildTile(Product product, CashSessionProvider cashSession) {
    final outOfStock = product.trackStock && product.stockQuantity <= 0;
    final hasImage = product.imageUrl != null && product.imageUrl!.isNotEmpty;
    final canTap = !outOfStock && cashSession.isOpen;

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: canTap ? () => _addToCart(product) : null,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (hasImage)
              Image.network(
                product.imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(color: _colorForName(product.name)),
              )
            else ...[
              Container(color: _colorForName(product.name)),
              const Center(
                child: Icon(Icons.inventory_2_outlined, size: 34, color: Colors.black26),
              ),
            ],
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(8, 18, 8, 6),
                decoration: hasImage
                    ? BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black.withOpacity(0.75)],
                        ),
                      )
                    : null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: hasImage ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    _priceLabel(product, color: hasImage ? Colors.white : Colors.black87),
                  ],
                ),
              ),
            ),
            if (outOfStock)
              Container(
                color: Colors.black54,
                alignment: Alignment.center,
                child: const Text(
                  'AGOTADO',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
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
          trailing: _priceLabel(product, bold: true),
          enabled: !outOfStock && cashSession.isOpen,
          onTap: () => _addToCart(product),
        );
      },
    );
  }
}
