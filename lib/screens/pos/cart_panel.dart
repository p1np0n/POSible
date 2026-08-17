import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../models/customer.dart';
import '../../models/discount.dart';
import '../../providers/cart_provider.dart';
import '../../providers/cash_session_provider.dart';
import '../../providers/store_provider.dart';
import '../../services/customer_repository.dart';
import '../../services/open_ticket_repository.dart';
import '../../services/sales_repository.dart';
import '../../services/settings_repository.dart';
import '../../widgets/currency_text.dart';
import '../customers/customer_picker_dialog.dart';
import 'discount_picker_dialog.dart';

/// El carrito de Ventas, siempre visible (no es un modal): vive al lado o
/// debajo de la búsqueda de productos, según el tamaño de pantalla. El
/// cliente y descuento elegidos se guardan en CartProvider (no aquí), para
/// que sobrevivan si se retoma un ticket en espera desde otra parte de la
/// pantalla.
class CartPanel extends StatefulWidget {
  final VoidCallback? onSaleCompleted;
  final VoidCallback? onTicketHeld;

  const CartPanel({super.key, this.onSaleCompleted, this.onTicketHeld});

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
  double get _taxAmount => _taxableAmount * _taxRatePercent / 100;
  double get _total => _taxableAmount + _taxAmount;

  double get _splitCash => double.tryParse(_cashAmountController.text) ?? 0;
  double get _splitCard => double.tryParse(_cardAmountController.text) ?? 0;
  double get _splitOther => double.tryParse(_otherAmountController.text) ?? 0;
  double get _splitSum => _splitCash + _splitCard + _splitOther;
  bool get _splitValid => (_splitSum - _total).abs() < 0.01;

  void _toggleSplitPayment(bool value) {
    setState(() {
      _splitPayment = value;
      if (value) {
        _cashAmountController.text = _total.toStringAsFixed(2);
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

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();

    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
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
          ),
          Expanded(
            child: cart.items.isEmpty
                ? const Center(
                    child: Text('El carrito está vacío', style: TextStyle(color: Colors.grey)),
                  )
                : ListView.builder(
                    itemCount: cart.items.length,
                    itemBuilder: (context, index) {
                      final item = cart.items[index];
                      return ListTile(
                        dense: true,
                        title: Text(item.product.name),
                        subtitle: item.modifiersLabel.isEmpty
                            ? CurrencyText(item.unitPrice)
                            : Text('${item.modifiersLabel} · \$${item.unitPrice.toStringAsFixed(2)}'),
                        leading: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: () => context.read<CartProvider>().decrementItem(item),
                            ),
                            Text(item.quantity.toStringAsFixed(0)),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              onPressed: () => context.read<CartProvider>().incrementItem(item),
                            ),
                          ],
                        ),
                        trailing: CurrencyText(item.subtotal, bold: true),
                      );
                    },
                  ),
          ),
          const Divider(height: 1),
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
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
                          decoration: const InputDecoration(
                              labelText: 'Efectivo', border: OutlineInputBorder(), isDense: true),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _cardAmountController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                              labelText: 'Tarjeta', border: OutlineInputBorder(), isDense: true),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _otherAmountController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                              labelText: 'Otro', border: OutlineInputBorder(), isDense: true),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _splitValid
                        ? 'Cuadra con el total ✓'
                        : 'Suma: \$${_splitSum.toStringAsFixed(2)} — falta \$${(_total - _splitSum).toStringAsFixed(2)}',
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
                        Text('-\$${_discountAmount.toStringAsFixed(2)}'),
                      ],
                    ),
                  ),
                if (_taxAmount > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Impuesto (${_taxRatePercent.toStringAsFixed(1)}%)'),
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
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: (_holding || _processing || cart.items.isEmpty) ? null : _holdTicket,
                        icon: _holding
                            ? const SizedBox(
                                height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.pause_circle_outline),
                        label: const Text('Dejar en espera'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        onPressed:
                            (_processing || _holding || cart.items.isEmpty || (_splitPayment && !_splitValid))
                                ? null
                                : _checkout,
                        child: _processing
                            ? const SizedBox(
                                height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Cobrar'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
