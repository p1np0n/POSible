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
import '../../widgets/currency_text.dart';
import '../scan/barcode_scanner_screen.dart';
import 'cart_sheet.dart';
import 'cash_session_sheet.dart';
import 'modifier_picker_sheet.dart';
import 'open_tickets_sheet.dart';
import 'quick_item_dialog.dart';

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final ProductRepository _productRepository = ProductRepository();
  final CategoryRepository _categoryRepository = CategoryRepository();
  final ModifierRepository _modifierRepository = ModifierRepository();
  final OpenTicketRepository _openTicketRepository = OpenTicketRepository();
  final _searchController = TextEditingController();

  List<Product> _products = [];
  List<Category> _categories = [];
  List<Modifier> _modifiers = [];
  String? _selectedCategoryId;
  String _search = '';
  bool _loading = true;
  int _openTicketCount = 0;

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
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      _productRepository.getAll(),
      _categoryRepository.getAll(),
      _modifierRepository.getAll(onlyActive: true),
    ]);
    setState(() {
      _products = results[0] as List<Product>;
      _categories = results[1] as List<Category>;
      _modifiers = results[2] as List<Modifier>;
      _loading = false;
    });
  }

  Future<void> _addToCart(Product product) async {
    if (_modifiers.isEmpty) {
      context.read<CartProvider>().addProduct(product);
      return;
    }
    final selected = await showModalBottomSheet<List<Modifier>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ModifierPickerSheet(product: product, modifiers: _modifiers),
    );
    if (selected != null && mounted) {
      context.read<CartProvider>().addProduct(product, modifiers: selected);
    }
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
    ).then((_) {
      _loadData();
      _refreshOpenTicketCount();
    });
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
      final product = found ?? Product.quickItem(name: entry.productName, price: entry.unitPrice);
      final modifiers = _modifiers.where((m) => entry.modifierIds.contains(m.id)).toList();
      return CartItem(product: product, quantity: entry.quantity, modifiers: modifiers);
    }).toList();

    cart.loadItems(items);
    await _openTicketRepository.delete(ticket.id);

    Customer? customer;
    if (ticket.customerId != null) {
      customer = await CustomerRepository().getById(ticket.customerId!);
    }
    Discount? discount;
    if (ticket.discountId != null) {
      discount = await DiscountRepository().getById(ticket.discountId!);
    }

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => CartSheet(initialCustomer: customer, initialDiscount: discount),
    ).then((_) {
      _loadData();
      _refreshOpenTicketCount();
    });
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
            onTap: (outOfStock || !cashSession.isOpen) ? null : () => _addToCart(product),
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
          onTap: () => _addToCart(product),
        );
      },
    );
  }
}
