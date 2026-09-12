import 'package:flutter/foundation.dart';

import '../config/customer_display_config.dart';
import '../providers/cart_provider.dart';
import '../services/customer_display_server.dart';

/// Controla el servidor local de "Pantalla para el cliente" (ver
/// CustomerDisplayServer) desde Configuración, y le manda el carrito cada
/// vez que cambia — ver el ChangeNotifierProxyProvider en main.dart, que
/// llama a [updateCart] automáticamente cuando CartProvider avisa un
/// cambio. Apagado por defecto: no vale la pena tener un servidor
/// escuchando si nadie usa la pantalla del cliente.
class CustomerDisplayProvider extends ChangeNotifier {
  final CustomerDisplayServer _server = CustomerDisplayServer();

  bool running = false;
  List<String> localAddresses = [];

  int get port => customerDisplayPort;

  Future<void> start() async {
    if (running) return;
    await _server.start();
    localAddresses = await CustomerDisplayServer.localAddresses();
    running = true;
    notifyListeners();
  }

  Future<void> stop() async {
    if (!running) return;
    await _server.stop();
    running = false;
    notifyListeners();
  }

  void updateCart(CartProvider cart) {
    if (!running) return;
    final subtotal = cart.total;
    final discountAmount = cart.selectedDiscount?.amountFor(subtotal) ?? 0;
    _server.broadcast({
      'type': 'cart',
      'items': cart.items
          .map((item) => {
                'name': item.product.name,
                'quantity': item.quantity,
                'unitPrice': item.unitPrice,
                'subtotal': item.subtotal,
              })
          .toList(),
      'subtotal': subtotal,
      'discount': discountAmount,
      'total': subtotal - discountAmount,
    });
  }

  @override
  void dispose() {
    _server.stop();
    super.dispose();
  }
}
