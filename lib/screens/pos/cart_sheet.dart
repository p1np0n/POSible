import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../models/customer.dart';
import '../../providers/cart_provider.dart';
import '../../providers/cash_session_provider.dart';
import '../../services/customer_repository.dart';
import '../../services/sales_repository.dart';
import '../../widgets/currency_text.dart';
import '../customers/customer_picker_dialog.dart';

class CartSheet extends StatefulWidget {
  const CartSheet({super.key});

  @override
  State<CartSheet> createState() => _CartSheetState();
}

class _CartSheetState extends State<CartSheet> {
  final SalesRepository _salesRepository = SalesRepository();
  Customer? _selectedCustomer;
  String _paymentMethod = 'cash';
  bool _processing = false;

  Future<void> _pickCustomer() async {
    final customer = await showDialog<Customer>(
      context: context,
      builder: (_) => const CustomerPickerDialog(),
    );
    if (customer != null) setState(() => _selectedCustomer = customer);
  }

  Future<void> _checkout() async {
    final cart = context.read<CartProvider>();
    final cashSession = context.read<CashSessionProvider>();
    if (cart.items.isEmpty || cashSession.current == null) return;

    setState(() => _processing = true);
    try {
      final pointsEarned = (cart.total * AppConfig.loyaltyPointsPerCurrencyUnit).floor();
      await _salesRepository.createSale(
        items: cart.items,
        cashSessionId: cashSession.current!.id,
        customerId: _selectedCustomer?.id,
        paymentMethod: _paymentMethod,
        loyaltyPointsEarned: _selectedCustomer != null ? pointsEarned : 0,
      );

      if (_selectedCustomer != null) {
        await CustomerRepository().addPointsAndSpend(
          _selectedCustomer!.id,
          pointsDelta: pointsEarned,
          spendDelta: cart.total,
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

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
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
                child: Text('Carrito', style: Theme.of(context).textTheme.titleLarge),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: cart.items.length,
                  itemBuilder: (context, index) {
                    final item = cart.items[index];
                    return ListTile(
                      title: Text(item.product.name),
                      subtitle: CurrencyText(item.product.price),
                      leading: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: () =>
                                context.read<CartProvider>().decrementQuantity(item.product.id),
                          ),
                          Text(item.quantity.toStringAsFixed(0)),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed: () =>
                                context.read<CartProvider>().incrementQuantity(item.product.id),
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
                    const SizedBox(height: 8),
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
                      children: [
                        const Text('Total', style: TextStyle(fontSize: 18)),
                        CurrencyText(cart.total, bold: true, style: const TextStyle(fontSize: 20)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: (_processing || cart.items.isEmpty) ? null : _checkout,
                      child: _processing
                          ? const SizedBox(
                              height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Cobrar'),
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
