/// Versión sin hacer nada de [CustomerDisplayServer], para cuando la app
/// corre en el navegador (panel web) — ahí no existe "dart:io" (sockets,
/// servidor local), así que "Pantalla para el cliente" no está disponible
/// (la pantalla de Configuración la esconde con `if (!kIsWeb)`). Esta clase
/// existe solo para que el resto del código compile igual en las dos
/// plataformas — ver customer_display_server.dart, que elige esta versión
/// o la real (customer_display_server_io.dart) según corresponda.
class CustomerDisplayServer {
  bool get isRunning => false;

  Future<void> start() async {}

  Future<void> stop() async {}

  void broadcast(Map<String, dynamic> data) {}

  static Future<List<String>> localAddresses() async => const [];
}
