import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/cart_item.dart';
import '../../models/open_ticket.dart';
import '../../providers/cart_provider.dart';
import '../../providers/cash_session_provider.dart';
import '../../services/open_ticket_repository.dart';
import '../../services/settings_repository.dart';
import '../../utils/currency_format_cl.dart';
import '../../widgets/currency_text.dart';
import 'checkout_sheet.dart';

/// El carrito de Ventas, siempre visible (no es un modal): vive al lado o
/// debajo de la búsqueda de productos, según el tamaño de pantalla. Solo
/// muestra los artículos agregados — cliente, descuento, forma de pago y
/// el desglose de montos viven en la hoja que se abre al presionar
/// "Cobrar" (ver checkout_sheet.dart). El cliente y descuento elegidos se
/// guardan en CartProvider (no aquí), para que sobrevivan si se retoma un
/// ticket en espera desde otra parte de la pantalla.
///
/// [compact]: cuando la pantalla no alcanza para mostrar productos y
/// carrito lado a lado (celular, tablet vertical), el carrito se docka
/// abajo con la lista de artículos plegada detrás de una flechita — así
/// el mosaico de productos aprovecha casi toda la pantalla, y solo se
/// despliega la lista cuando el cajero lo pide. Los botones Guardar/
/// Cobrar quedan siempre visibles, plegado o no.
class CartPanel extends StatefulWidget {
  final VoidCallback? onSaleCompleted;
  final VoidCallback? onTicketHeld;
  final bool compact;

  const CartPanel({super.key, this.onSaleCompleted, this.onTicketHeld, this.compact = false});

  @override
  State<CartPanel> createState() => _CartPanelState();
}

class _CartPanelState extends State<CartPanel> {
  final SettingsRepository _settingsRepository = SettingsRepository();
  final OpenTicketRepository _openTicketRepository = OpenTicketRepository();
  double _taxRatePercent = 0;
  bool _holding = false;
  // Solo aplica en modo compacto (widget.compact): si la lista de
  // artículos está desplegada o plegada detrás de la flechita.
  bool _detailsExpanded = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await _settingsRepository.getSettings();
      if (mounted) setState(() => _taxRatePercent = settings.taxRatePercent);
    } catch (_) {
      // Si no hay configuración todavía, seguimos con 0% de impuesto.
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
          ? CurrencyText(item.unitPrice, style: const TextStyle(fontSize: 14))
          : Text('${item.modifiersLabel} · ${formatCurrencyCl(item.unitPrice)}', style: const TextStyle(fontSize: 14)),
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: () => _decrementOrConfirmRemove(item),
          ),
          Text(
            item.product.isSoldByWeight ? item.quantity.toStringAsFixed(3) : item.quantity.toStringAsFixed(0),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => context.read<CartProvider>().incrementItem(item),
          ),
        ],
      ),
      trailing: CurrencyText(item.subtotal, bold: true, style: const TextStyle(fontSize: 18)),
    );
  }

  void _openCheckout() {
    showCheckoutSheet(context, taxRatePercent: _taxRatePercent, onSaleCompleted: widget.onSaleCompleted);
  }

  Widget _buildActionButtons(CartProvider cart) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: (_holding || cart.items.isEmpty) ? null : _holdTicket,
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
            onPressed: (_holding || cart.items.isEmpty) ? null : _openCheckout,
            child: const Text('Cobrar'),
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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Carrito', style: Theme.of(context).textTheme.titleLarge),
                if (cart.items.isNotEmpty)
                  TextButton.icon(
                    onPressed: _holding ? null : _voidCart,
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
                    itemBuilder: (context, index) => _buildItemTile(cart.items[index]),
                  ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: _buildActionButtons(cart),
          ),
        ],
      ),
    );
  }

  /// Panel compacto (celular, tablet vertical): el carrito se docka abajo
  /// del mosaico de productos con solo una franja fija siempre visible
  /// (los botones Guardar/Cobrar); la lista de artículos queda plegada
  /// detrás de la flechita, para que el mosaico de productos aproveche
  /// casi toda la pantalla mientras se vende. "mainAxisSize: min" es la
  /// clave: sin eso, esta columna ocuparía todo el alto que le da el
  /// ConstrainedBox de pos_screen.dart aunque esté plegada, dejando un
  /// hueco vacío en vez de devolverle el espacio al mosaico.
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
                            onPressed: _holding ? null : _voidCart,
                          ),
                          IconButton(
                            icon: Icon(_detailsExpanded ? Icons.expand_less : Icons.expand_more),
                            tooltip: _detailsExpanded ? 'Ocultar artículos' : 'Ver artículos',
                            visualDensity: VisualDensity.compact,
                            onPressed: () => setState(() => _detailsExpanded = !_detailsExpanded),
                          ),
                        ],
                      ),
                  ],
                ),
                if (!hasItems) ...[
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
              child: ListView(
                shrinkWrap: true,
                children: cart.items.map(_buildItemTile).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
