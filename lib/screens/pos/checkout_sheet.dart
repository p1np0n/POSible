import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../models/customer.dart';
import '../../models/discount.dart';
import '../../providers/cart_provider.dart';
import '../../providers/cash_session_provider.dart';
import '../../providers/store_provider.dart';
import '../../services/customer_repository.dart';
import '../../services/sales_repository.dart';
import '../../utils/currency_format_cl.dart';
import '../../widgets/currency_text.dart';
import '../customers/customer_picker_dialog.dart';
import 'discount_picker_dialog.dart';

/// Hoja que se abre al presionar "Cobrar" en el carrito: cliente,
/// descuento, forma de pago y el desglose Subtotal/IVA/Total — todo lo que
/// antes vivía siempre visible en el carrito de Ventas se mudó acá, para
/// que el carrito quede mostrando solo los artículos agregados. Al
/// confirmar el cobro, esta misma hoja pasa a un estado de "listo" con un
/// botón "Nueva venta" para volver a Ventas y empezar la próxima.
Future<void> showCheckoutSheet(
  BuildContext context, {
  required double taxRatePercent,
  VoidCallback? onSaleCompleted,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _CheckoutSheet(taxRatePercent: taxRatePercent, onSaleCompleted: onSaleCompleted),
  );
}

class _CheckoutSheet extends StatefulWidget {
  final double taxRatePercent;
  final VoidCallback? onSaleCompleted;

  const _CheckoutSheet({required this.taxRatePercent, this.onSaleCompleted});

  @override
  State<_CheckoutSheet> createState() => _CheckoutSheetState();
}

class _CheckoutSheetState extends State<_CheckoutSheet> {
  final SalesRepository _salesRepository = SalesRepository();
  String _paymentMethod = 'cash';
  bool _processing = false;
  bool _splitPayment = false;
  final _cashAmountController = TextEditingController();
  final _cardAmountController = TextEditingController();
  final _otherAmountController = TextEditingController();
  // Con cuánto efectivo paga el cliente, para calcular el vuelto — solo se
  // usa como ayuda para el cajero, no cambia lo que se registra en la
  // venta (siempre se cobra el total exacto).
  final _cashReceivedController = TextEditingController();
  static const List<double> _cashPresets = [2000, 5000, 10000, 20000];

  // Una vez que la venta se registra, esta hoja pasa a mostrar un botón
  // "Nueva venta" en vez de cerrarse sola — el total del carrito ya no
  // sirve para mostrarlo (se limpia apenas se confirma la venta), así que
  // se guarda una copia acá antes de limpiar.
  bool _success = false;
  double _lastTotal = 0;

  @override
  void dispose() {
    _cashAmountController.dispose();
    _cardAmountController.dispose();
    _otherAmountController.dispose();
    _cashReceivedController.dispose();
    super.dispose();
  }

  double get _subtotal => context.read<CartProvider>().total;
  double get _discountAmount =>
      context.read<CartProvider>().selectedDiscount?.amountFor(_subtotal) ?? 0;
  double get _taxableAmount => _subtotal - _discountAmount;
  double get _taxAmount => widget.taxRatePercent <= 0
      ? 0
      : _taxableAmount - (_taxableAmount / (1 + widget.taxRatePercent / 100));
  double get _total => _taxableAmount;

  double get _splitCash => double.tryParse(_cashAmountController.text) ?? 0;
  double get _splitCard => double.tryParse(_cardAmountController.text) ?? 0;
  double get _splitOther => double.tryParse(_otherAmountController.text) ?? 0;
  double get _splitSum => _splitCash + _splitCard + _splitOther;
  bool get _splitValid => (_splitSum - _total).abs() < 0.01;

  double? get _cashReceived => double.tryParse(_cashAmountReceivedText);
  String get _cashAmountReceivedText => _cashReceivedController.text.trim();
  double get _change => (_cashReceived ?? 0) - _total;

  void _addCashPreset(double amount) {
    final current = _cashReceived ?? 0;
    setState(() => _cashReceivedController.text = (current + amount).round().toString());
  }

  void _clearCashReceived() {
    if (_cashReceivedController.text.isNotEmpty) {
      setState(() => _cashReceivedController.clear());
    }
  }

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
      widget.onSaleCompleted?.call();
      if (mounted) {
        setState(() {
          _success = true;
          _lastTotal = total;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al registrar la venta: $e')));
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: _success ? _buildSuccess(context) : _buildForm(context),
      ),
    );
  }

  Widget _buildSuccess(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, color: Colors.green.shade600, size: 64),
          const SizedBox(height: 16),
          const Text('Venta registrada', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          CurrencyText(_lastTotal, bold: true, style: const TextStyle(fontSize: 32)),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Nueva venta'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// El Total siempre se ve grande y centrado. Cuando hay vuelto o falta
  /// que mostrar (pago en efectivo con un monto recibido escrito), el
  /// Vuelto/Falta aparece al lado en el mismo tamaño de letra — así el
  /// cajero ve ambos números de un vistazo sin tener que comparar tamaños
  /// distintos.
  Widget _buildTotalAndChange(BuildContext context) {
    final totalColumn = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Total', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: CurrencyText(
            _total,
            bold: true,
            style: TextStyle(fontSize: 56, color: Theme.of(context).colorScheme.primary),
          ),
        ),
      ],
    );

    final showChange = !_splitPayment && _paymentMethod == 'cash' && _cashAmountReceivedText.isNotEmpty;
    if (!showChange) return totalColumn;

    final changeColor = _change >= 0 ? Colors.green.shade700 : Colors.red;
    final changeColumn = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(_change >= 0 ? 'Vuelto' : 'Falta', textAlign: TextAlign.center, style: TextStyle(color: changeColor)),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: CurrencyText(_change.abs(), bold: true, style: TextStyle(fontSize: 56, color: changeColor)),
        ),
      ],
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: totalColumn),
        Expanded(child: changeColumn),
      ],
    );
  }

  Widget _buildForm(BuildContext context) {
    final cart = context.watch<CartProvider>();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Cobrar', style: Theme.of(context).textTheme.titleLarge),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
            ],
          ),
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
              onSelectionChanged: (value) => setState(() {
                _paymentMethod = value.first;
                if (_paymentMethod != 'cash') _cashReceivedController.clear();
              }),
            ),
          if (!_splitPayment && _paymentMethod == 'cash') ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _cashReceivedController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Recibe en efectivo',
                      prefixText: '\$',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                if (_cashAmountReceivedText.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.clear),
                    tooltip: 'Borrar',
                    onPressed: _clearCashReceived,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _cashPresets
                  .map((amount) => ActionChip(
                        label: Text('+${formatCurrencyCl(amount)}'),
                        onPressed: () => _addCashPreset(amount),
                      ))
                  .toList(),
            ),
          ],
          const SizedBox(height: 16),
          _buildTotalAndChange(context),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Subtotal', style: TextStyle(fontSize: 13, color: Colors.grey)),
              CurrencyText(cart.total, style: const TextStyle(fontSize: 13, color: Colors.grey)),
            ],
          ),
          if (_discountAmount > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Descuento', style: TextStyle(fontSize: 13, color: Colors.grey)),
                  Text('-${formatCurrencyCl(_discountAmount)}', style: const TextStyle(fontSize: 13, color: Colors.grey)),
                ],
              ),
            ),
          if (_taxAmount > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('IVA incluido (${widget.taxRatePercent.toStringAsFixed(1)}%)',
                      style: const TextStyle(fontSize: 13, color: Colors.grey)),
                  CurrencyText(_taxAmount, style: const TextStyle(fontSize: 13, color: Colors.grey)),
                ],
              ),
            ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: (_processing || cart.items.isEmpty || (_splitPayment && !_splitValid)) ? null : _checkout,
              child: _processing
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text('Cobrar ${formatCurrencyCl(_total)}'),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
