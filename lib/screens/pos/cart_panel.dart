import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../models/cart_item.dart';
import '../../models/customer.dart';
import '../../models/discount.dart';
import '../../models/open_ticket.dart';
import '../../providers/cart_provider.dart';
import '../../providers/cash_session_provider.dart';
import '../../providers/store_provider.dart';
import '../../services/customer_repository.dart';
import '../../services/open_ticket_repository.dart';
import '../../services/sales_repository.dart';
import '../../services/settings_repository.dart';
import '../../utils/currency_format_cl.dart';
import '../../widgets/currency_text.dart';
import '../customers/customer_picker_dialog.dart';
import 'discount_picker_dialog.dart';

/// El carrito de Ventas, siempre visible (no es un modal): vive al lado o
/// debajo de la búsqueda de productos, según el tamaño de pantalla. El
/// cliente y descuento elegidos se guardan en CartProvider (no aquí), para
/// que sobrevivan si se retoma un ticket en espera desde otra parte de la
/// pantalla.
///
/// [compact]: cuando la pantalla no alcanza para mostrar productos y
/// carrito lado a lado (celular, tablet vertical), el carrito se docka
/// abajo con la lista de artículos y el detalle de pago plegados detrás de
/// una flechita — así el mosaico de productos aprovecha casi toda la
/// pantalla, y solo se despliega el detalle cuando el cajero lo pide. El
/// total y los botones Guardar/Cobrar quedan siempre visibles, plegado o
/// no.
class CartPanel extends StatefulWidget {
  final VoidCallback? onSaleCompleted;
  final VoidCallback? onTicketHeld;
  final bool compact;

  const CartPanel({super.key, this.onSaleCompleted, this.onTicketHeld, this.compact = false});

  @override
  State<CartPanel> createState() => _CartPanelState();
}

class _CartPanelState extends State<CartPanel> {
  final SalesRepository _salesRepository = SalesRepository();
  final SettingsRepository _settingsRepository = SettingsRepository();
  final OpenTicketRepository _openTicketRepository = OpenTicketRepository();
  String _paymentMethod = 'cash';
  double _taxRatePercent = 0;
  bool _processing = false;
  bool _holding = false;
  bool _splitPayment = false;
  // Solo aplica en modo compacto (widget.compact): si el detalle (lista de
  // artículos, cliente/descuento, forma de pago, desglose) está desplegado
  // o plegado detrás de la flechita.
  bool _detailsExpanded = false;
  final _cashAmountController = TextEditingController();
  final _cardAmountController = TextEditingController();
  final _otherAmountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _cashAmountController.dispose();
    _cardAmountController.dispose();
    _otherAmountController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await _settingsRepository.getSettings();
      if (mounted) setState(() => _taxRatePercent = settings.taxRatePercent);
    } catch (_) {
      // Si no hay configuración todavía, seguimos con 0% de impuesto.
    }
  }

  double get _subtotal => context.read<CartProvider>().total;
  double get _discountAmount =>
      context.read<CartProvider>().selectedDiscount?.amountFor(_subtotal) ?? 0;
  double get _taxableAmount => _subtotal - _discountAmount;
  // El precio de cada artículo YA incluye el IVA — nunca se suma aparte. La
  // tasa configurada solo sirve para calcular qué parte de ese precio es
  // impuesto, para mostrarlo desglosado (como pide la ley), no para
  // agregarlo al total.
  double get _taxAmount =>
      _taxRatePercent <= 0 ? 0 : _taxableAmount - (_taxableAmount / (1 + _taxRatePercent / 100));
  double get _total => _taxableAmount;

  double get _splitCash => double.tryParse(_cashAmountController.text) ?? 0;
  double get _splitCard => double.tryParse(_cardAmountController.text) ?? 0;
  double get _splitOther => double.tryParse(_otherAmountController.text) ?? 0;
  double get _splitSum => _splitCash + _splitCard + _splitOther;
  bool get _splitValid => (_splitSum - _total).abs() < 0.01;

  void _toggleSplitPayment(bool value) {
    setState(() {
      _splitPayment = value;
      if (value) {
        _cashAmountController.text = _total.round().toString();
        _cardAmountController.text = '0';
        _otherAmountController.text = '0';
      }
    });
  }

  Future<void> _pickCustomer() async {
    final customer = await showDialog<Customer>(
      context: context,
      builder: (_) => const CustomerPickerDialog(),
    );
    if (customer != null && mounted) context.read<CartProvider>().setCustomer(customer);
  }

  Future<void> _pickDiscount() async {
    final discount = await showDialog<Discount>(
      context: context,
      builder: (_) => const DiscountPickerDialog(),
    );
    if (discount != null && mounted) {
      context.read<CartProvider>().setDiscount(discount.isNone ? null : discount);
    }
  }

  Future<bool> _confirmNegativeStock(CartProvider cart) async {
    final shortItems = cart.items
        .where((item) => item.product.trackStock && item.quantity > item.product.stockQuantity);
    if (shortItems.isEmpty) return true;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Stock insuficiente'),
        content: Text(
          'Estos productos no tienen suficiente inventario y quedarían en negativo:\n\n'
          '${shortItems.map((item) => '• ${item.product.name} (stock: ${item.product.stockQuantity.toStringAsFixed(0)}, vendes: ${item.quantity.toStringAsFixed(0)})').join('\n')}'
          '\n\n¿Quieres continuar con la venta de todas formas?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Vender igual')),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _checkout() async {
    final cart = context.read<CartProvider>();
    final cashSession = context.read<CashSessionProvider>();
    if (cart.items.isEmpty || cashSession.current == null) return;
    if (_splitPayment && !_splitValid) return;
    if (!await _confirmNegativeStock(cart)) return;

    setState(() => _processing = true);
    try {
      final total = _total;
      final customer = cart.selectedCustomer;
      final pointsEarned = (total * AppConfig.loyaltyPointsPerCurrencyUnit).floor();
      await _salesRepository.createSale(
        items: cart.items,
        cashSessionId: cashSession.current!.id,
        customerId: customer?.id,
        discountId: cart.selectedDiscount?.id,
        discountAmount: _discountAmount,
        taxAmount: _taxAmount,
        cashAmount: _splitPayment ? _splitCash : (_paymentMethod == 'cash' ? total : 0),
        cardAmount: _splitPayment ? _splitCard : (_paymentMethod == 'card' ? total : 0),
        otherAmount: _splitPayment ? _splitOther : (_paymentMethod == 'other' ? total : 0),
        loyaltyPointsEarned: customer != null ? pointsEarned : 0,
      );

      if (customer != null) {
        await CustomerRepository().addPointsAndSpend(
          customer.id,
          pointsDelta: pointsEarned,
          spendDelta: total,
        );
      }

      cart.clear();
      if (mounted) {
        setState(() {
          _splitPayment = false;
          _paymentMethod = 'cash';
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Venta registrada')));
        widget.onSaleCompleted?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al registrar la venta: $e')));
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<String?> _promptTicketName() async {
    final cart = context.read<CartProvider>();
    final controller = TextEditingController(text: cart.selectedCustomer?.name ?? '');
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dejar en espera'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Nombre del ticket (opcional)',
            hintText: 'Ej. Mesa 3, Juan Pérez...',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _holdTicket() async {
    final cart = context.read<CartProvider>();
    final cashSession = context.read<CashSessionProvider>();
    if (cart.items.isEmpty || cashSession.current == null) return;

    final name = await _promptTicketName();
    if (name == null || !mounted) return;

    setState(() => _holding = true);
    try {
      final items = cart.items
          .map((item) => OpenTicketItem(
                productId: item.product.isQuickItem ? null : item.product.id,
                productName: item.product.name,
                unitPrice: item.unitPrice,
                quantity: item.quantity,
                modifierIds: item.modifiers.map((m) => m.id).toList(),
              ))
          .toList();
      await _openTicketRepository.create(
        cashSessionId: cashSession.current!.id,
        customerId: cart.selectedCustomer?.id,
        discountId: cart.selectedDiscount?.id,
        label: name.isNotEmpty ? name : cart.selectedCustomer?.name,
        items: items,
      );
      cart.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ticket guardado en espera')));
        widget.onTicketHeld?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al guardar el ticket: $e')));
      }
    } finally {
      if (mounted) setState(() => _holding = false);
    }
  }

  Future<void> _voidCart() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Anular venta'),
        content: const Text('¿Seguro que quieres anular esta venta? Se pierden todos los productos del carrito.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Anular')),
        ],
      ),
    );
    if (confirmed != true) return;
    if (mounted) context.read<CartProvider>().clear();
  }

  /// Resumen chico (Subtotal / IVA incl. / Total) que va junto al título
  /// "Carrito", siempre visible aunque haya que desplazarse por la lista de
  /// artículos o el resto del panel.
  Widget _headerAmount(String label, double amount, {bool emphasize = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: emphasize ? 13 : 12,
            color: emphasize ? null : Colors.grey.shade600,
          ),
        ),
        CurrencyText(
          amount,
          bold: emphasize,
          style: TextStyle(
            fontSize: emphasize ? 15 : 12,
            color: emphasize ? Theme.of(context).colorScheme.primary : Colors.grey.shade700,
          ),
        ),
      ],
    );
  }

  /// Quitar un producto por peso o de precio variable con un solo toque en
  /// "-" es fácil de hacer sin querer (casi nunca su cantidad es un entero
  /// mayor a 1, así que el primer toque ya lo borraba) y se pierde un
  /// pesaje o un precio escrito a mano — para esos casos pide confirmar
  /// antes. Para un producto normal, el "-" sigue funcionando igual que
  /// siempre, sin preguntar.
  Future<void> _decrementOrConfirmRemove(CartItem item) async {
    final needsConfirmation =
        item.quantity <= 1 && (item.product.isSoldByWeight || item.product.isVariablePrice);
    if (!needsConfirmation) {
      context.read<CartProvider>().decrementItem(item);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Quitar del carrito'),
        content: Text('¿Quitar "${item.product.name}" del carrito?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Quitar')),
        ],
      ),
    );
    if (confirmed == true && mounted) context.read<CartProvider>().removeItem(item);
  }

  Widget _buildItemTile(CartItem item) {
    return ListTile(
      dense: true,
      title: Text(item.product.name),
      subtitle: item.modifiersLabel.isEmpty
          ? CurrencyText(item.unitPrice)
          : Text('${item.modifiersLabel} · ${formatCurrencyCl(item.unitPrice)}'),
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: () => _decrementOrConfirmRemove(item),
          ),
          Text(item.product.isSoldByWeight ? item.quantity.toStringAsFixed(3) : item.quantity.toStringAsFixed(0)),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => context.read<CartProvider>().incrementItem(item),
          ),
        ],
      ),
      trailing: CurrencyText(item.subtotal, bold: true),
    );
  }

  /// Cliente/descuento, forma de pago (o pago dividido) y el desglose
  /// Subtotal/Descuento/IVA/Total — todo lo "fino" que no hace falta ver
  /// para cobrar rápido con Efectivo, así que en modo compacto queda
  /// plegado detrás de la flechita.
  Widget _buildPaymentAndBreakdown(CartProvider cart) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (context.watch<StoreProvider>().showCustomers)
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(cart.selectedCustomer?.name ?? 'Sin cliente (opcional)'),
            leading: const Icon(Icons.person_outline),
            trailing: TextButton(onPressed: _pickCustomer, child: const Text('Elegir')),
          ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: Text(cart.selectedDiscount?.name ?? 'Sin descuento'),
          leading: const Icon(Icons.sell_outlined),
          trailing: TextButton(onPressed: _pickDiscount, child: const Text('Elegir')),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: const Text('Dividir pago'),
          subtitle: const Text('Ej. una parte en efectivo y otra con tarjeta'),
          value: _splitPayment,
          onChanged: _toggleSplitPayment,
        ),
        if (_splitPayment) ...[
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _cashAmountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration:
                      const InputDecoration(labelText: 'Efectivo', border: OutlineInputBorder(), isDense: true),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _cardAmountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration:
                      const InputDecoration(labelText: 'Tarjeta', border: OutlineInputBorder(), isDense: true),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _otherAmountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Otro', border: OutlineInputBorder(), isDense: true),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _splitValid
                ? 'Cuadra con el total ✓'
                : 'Suma: ${formatCurrencyCl(_splitSum)} — falta ${formatCurrencyCl(_total - _splitSum)}',
            style: TextStyle(color: _splitValid ? Colors.green : Colors.red, fontSize: 12),
          ),
        ] else
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'cash', label: Text('Efectivo'), icon: Icon(Icons.payments)),
              ButtonSegment(value: 'card', label: Text('Tarjeta'), icon: Icon(Icons.credit_card)),
              ButtonSegment(value: 'other', label: Text('Otro'), icon: Icon(Icons.more_horiz)),
            ],
            selected: {_paymentMethod},
            onSelectionChanged: (value) => setState(() => _paymentMethod = value.first),
          ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [const Text('Subtotal'), CurrencyText(cart.total)],
        ),
        if (_discountAmount > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Descuento'),
                Text('-${formatCurrencyCl(_discountAmount)}'),
              ],
            ),
          ),
        if (_taxAmount > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('IVA incluido (${_taxRatePercent.toStringAsFixed(1)}%)'),
                CurrencyText(_taxAmount),
              ],
            ),
          ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Total', style: TextStyle(fontSize: 18)),
            CurrencyText(_total, bold: true, style: const TextStyle(fontSize: 20)),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButtons(CartProvider cart) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: (_holding || _processing || cart.items.isEmpty) ? null : _holdTicket,
            icon: _holding
                ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.pause_circle_outline),
            label: const Text('Guardar'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: FilledButton(
            onPressed: (_processing || _holding || cart.items.isEmpty || (_splitPayment && !_splitValid))
                ? null
                : _checkout,
            child: _processing
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Cobrar'),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    return widget.compact ? _buildCompactPanel(context, cart) : _buildFullPanel(context, cart);
  }

  /// Panel lado a lado (pantalla ancha): siempre a la vista completa, sin
  /// plegar nada — hay espacio de sobra al lado del mosaico de productos.
  Widget _buildFullPanel(BuildContext context, CartProvider cart) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Carrito', style: Theme.of(context).textTheme.titleLarge),
                    if (cart.items.isNotEmpty)
                      TextButton.icon(
                        onPressed: (_processing || _holding) ? null : _voidCart,
                        icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                        label: const Text('Anular', style: TextStyle(color: Colors.red)),
                      ),
                  ],
                ),
                if (cart.items.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 16,
                    runSpacing: 2,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _headerAmount('Subtotal', _taxableAmount),
                      if (_taxAmount > 0) _headerAmount('IVA incl.', _taxAmount),
                      _headerAmount('Total', _total, emphasize: true),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: cart.items.isEmpty
                ? const Center(
                    child: Text('El carrito está vacío', style: TextStyle(color: Colors.grey)),
                  )
                : ListView.builder(
                    itemCount: cart.items.length,
                    itemBuilder: (context, index) => _buildItemTile(cart.items[index]),
                  ),
          ),
          const Divider(height: 1),
          // Flexible (no un simple SingleChildScrollView suelto) para que
          // nunca empuje el botón "Cobrar" fuera de la pantalla: si el
          // carrito tiene muchos artículos y queda poco espacio, esta franja
          // se achica y scrollea dentro de lo que le toca, en vez de
          // desbordarse por debajo del panel (donde quedaba invisible).
          Flexible(
            flex: 2,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildPaymentAndBreakdown(cart),
                  const SizedBox(height: 12),
                  _buildActionButtons(cart),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Panel compacto (celular, tablet vertical): el carrito se docka abajo
  /// del mosaico de productos con solo una franja fija siempre visible
  /// (total y los botones Guardar/Cobrar); la lista de artículos y el
  /// detalle de pago quedan plegados detrás de la flechita, para que el
  /// mosaico de productos aproveche casi toda la pantalla mientras se
  /// vende. "mainAxisSize: min" es la clave: sin eso, esta columna
  /// ocuparía todo el alto que le da el ConstrainedBox de pos_screen.dart
  /// aunque esté plegada, dejando un hueco vacío en vez de devolverle el
  /// espacio al mosaico.
  Widget _buildCompactPanel(BuildContext context, CartProvider cart) {
    final hasItems = cart.items.isNotEmpty;
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Carrito', style: Theme.of(context).textTheme.titleMedium),
                        if (hasItems)
                          Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: Text(
                              '${cart.items.length} ${cart.items.length == 1 ? "artículo" : "artículos"}',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                            ),
                          ),
                      ],
                    ),
                    if (hasItems)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                            tooltip: 'Anular',
                            visualDensity: VisualDensity.compact,
                            onPressed: (_processing || _holding) ? null : _voidCart,
                          ),
                          IconButton(
                            icon: Icon(_detailsExpanded ? Icons.expand_less : Icons.expand_more),
                            tooltip: _detailsExpanded ? 'Ocultar detalle' : 'Ver detalle',
                            visualDensity: VisualDensity.compact,
                            onPressed: () => setState(() => _detailsExpanded = !_detailsExpanded),
                          ),
                        ],
                      ),
                  ],
                ),
                if (hasItems) ...[
                  const SizedBox(height: 2),
                  Wrap(
                    spacing: 16,
                    runSpacing: 2,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _headerAmount('Subtotal', _taxableAmount),
                      if (_taxAmount > 0) _headerAmount('IVA incl.', _taxAmount),
                      _headerAmount('Total', _total, emphasize: true),
                    ],
                  ),
                ] else ...[
                  const SizedBox(height: 2),
                  const Text('El carrito está vacío', style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
                const SizedBox(height: 10),
                _buildActionButtons(cart),
              ],
            ),
          ),
          if (hasItems && _detailsExpanded) ...[
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ...cart.items.map(_buildItemTile),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: _buildPaymentAndBreakdown(cart),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
