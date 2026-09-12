import 'dart:convert';
import 'dart:io';

import '../config/customer_display_config.dart';

/// Servidor local (no usa internet ni Supabase) que transmite el carrito de
/// Ventas a "Info ScreenClone" — la pantalla que mira el cliente — por la
/// misma red WiFi de la tienda. El celular de la caja abre este servidor
/// (ver CustomerDisplayProvider), y el otro celular/tablet se conecta a su
/// IP local.
class CustomerDisplayServer {
  HttpServer? _server;
  final List<WebSocket> _clients = [];
  String? _lastMessage;

  bool get isRunning => _server != null;

  Future<void> start() async {
    if (_server != null) return;
    _server = await HttpServer.bind(InternetAddress.anyIPv4, customerDisplayPort);
    _server!.listen((request) async {
      if (!WebSocketTransformer.isUpgradeRequest(request)) {
        request.response
          ..statusCode = HttpStatus.forbidden
          ..close();
        return;
      }
      final socket = await WebSocketTransformer.upgrade(request);
      _clients.add(socket);
      // Apenas se conecta, le manda el último estado conocido del carrito
      // — así la pantalla no queda en blanco hasta el próximo cambio.
      final last = _lastMessage;
      if (last != null) socket.add(last);
      socket.listen(
        (_) {},
        onDone: () => _clients.remove(socket),
        onError: (_) => _clients.remove(socket),
        cancelOnError: true,
      );
    });
  }

  Future<void> stop() async {
    for (final client in [..._clients]) {
      await client.close();
    }
    _clients.clear();
    await _server?.close(force: true);
    _server = null;
  }

  void broadcast(Map<String, dynamic> data) {
    final message = jsonEncode(data);
    _lastMessage = message;
    for (final client in [..._clients]) {
      try {
        client.add(message);
      } catch (_) {
        _clients.remove(client);
      }
    }
  }

  /// Direcciones IP del celular en su(s) red(es) WiFi — para mostrárselas
  /// al usuario y que las escriba en el otro dispositivo.
  static Future<List<String>> localAddresses() async {
    final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4, includeLoopback: false);
    return interfaces.expand((i) => i.addresses).map((a) => a.address).toList();
  }
}
