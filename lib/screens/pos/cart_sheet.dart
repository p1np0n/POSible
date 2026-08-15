import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../models/customer.dart';
import '../../models/discount.dart';
import '../../models/open_ticket.dart';
import '../../providers/cart_provider.dart';
import '../../providers/cash_session_provider.dart';
import '../../services/customer_repository.dart';
import '../../services/open_ticket_repository.dart';
import '../../services/sales_repository.dart';
import '../../services/settings_repository.dart';
import '../../widgets/currency_text.dart';
import '../customers/customer_picker_dialog.dart';
import 'discount_picker_dialog.dart';

class CartSheet extends StatefulWidget {
  final Customer? initialCustomer;
  final Discount? initialDiscount;

  const CartSheet({super.key, this.initialCustomer, this.initialDiscount});

  @override
  State<CartSheet> createState() => _CartSheetState();
}

class _CartSheetState extends State<CartSheet> {
  final SalesRepository _salesRepository = SalesRepository();
  final SettingsRepository _settingsRepository = SettingsRepository();
  final OpenTicketRepository _openTicketRepository = OpenTicketRepository();
  Customer? _selectedCustomer;
  Discount? _selectedDiscount;
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
    _selectedCustomer = widget.initialCustomer;
    _selectedDiscount = widget.initialDiscount;
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
  double get _discountAmount => _selectedDiscount?.amountFor(_subtotal) ?? 0;
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
    if (customer != null) setState(() => _selectedCustomer = customer);
  }

  Future<void> _pickDiscount() async {
    final discount = await showDialog<Discount>(
      context: context,
      builder: (_) => const DiscountPickerDialog(),
    );
    if (discount != null) {
      setState(() => _selectedDiscount = discount.isNone ? null : discount);
    }
  }

  Future<void> _checkout() async {
    final cart = context.read<CartProvider>();
    final cashSession = context.read<CashSessionProvider>();
    if (cart.items.isEmpty || cashSession.current == null) return;
    if (_splitPayment && !_splitValid) return;

    setState(() => _processing = true);
    try {
      final total = _total;
      final pointsEarned = (total * AppConfig.loyaltyPointsPerCurrencyUnit).floor();
      await _salesRepository.createSale(
        items: cart.items,
        cashSessionId: cashSession.current!.id,
        customerId: _selectedCustomer?.id,
        discountId: _selectedDiscount?.id,
        discountAmount: _discountAmount,
        taxAmount: _taxAmount,
        cashAmount: _splitPayment ? _splitCash : (_paymentMethod == 'cash' ? total : 0),
        cardAmount: _splitPayment ? _splitCard : (_paymentMethod == 'card' ? total : 0),
        otherAmount: _splitPayment ? _splitOther : (_paymentMethod == 'other' ? total : 0),
        loyaltyPointsEarned: _selectedCustomer != null ? pointsEarned : 0,
      );

      if (_selectedCustomer != null) {
        await CustomerRepository().addPointsAndSpend(
          _selectedCustomer!.id,
          pointsDelta: pointsEarned,
          spendDelta: total,
        );
      }

      cart.clear();
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Venta registrada')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al registrar la venta: $e')));
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _holdTicket() async {
    final cart = context.read<CartProvider>();
    final cashSession = context.read<CashSessionProvider>();
    if (cart.items.isEmpty || cashSession.current == null) return;

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
        customerId: _selectedCustomer?.id,
        discountId: _selectedDiscount?.id,
        label: _selectedCustomer?.name,
        items: items,
      );
      cart.clear();
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ticket guardado en espera')));
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
    context.read<CartProvider>().clear();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();

    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Carrito', style: Theme.of(context).textTheme.titleLarge),
                    if (cart.items.isNotEmpty)
                      TextButton.icon(
                        onPressed: (_processing || _holding) ? null : _voidCart,
                        icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                        label: const Text('Anular venta', style: TextStyle(color: Colors.red)),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: cart.items.length,
                  itemBuilder: (context, index) {
                    final item = cart.items[index];
                    return ListTile(
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
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(_selectedCustomer?.name ?? 'Sin cliente (opcional)'),
                      leading: const Icon(Icons.person_outline),
                      trailing: TextButton(onPressed: _pickCustomer, child: const Text('Elegir')),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(_selectedDiscount?.name ?? 'Sin descuento'),
                      leading: const Icon(Icons.sell_outlined),
                      trailing: TextButton(onPressed: _pickDiscount, child: const Text('Elegir')),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
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
                              decoration: const InputDecoration(labelText: 'Efectivo', border: OutlineInputBorder(), isDense: true),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _cardAmountController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(labelText: 'Tarjeta', border: OutlineInputBorder(), isDense: true),
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
                            onPressed: (_processing || _holding || cart.items.isEmpty || (_splitPayment && !_splitValid))
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
      },
    );
  }
}
