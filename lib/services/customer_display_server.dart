/// "Pantalla para el cliente" necesita un servidor local (sockets, "dart:io"
/// — ver customer_display_server_io.dart), algo que no existe en el
/// navegador (panel web). Este archivo elige automáticamente esa versión
/// real cuando la app corre en el celular/tablet, o una versión que no hace
/// nada (customer_display_server_stub.dart) cuando corre como panel web —
/// para que el resto del código (CustomerDisplayProvider, main.dart) no
/// tenga que saber la diferencia ni duplicar nada.
export 'customer_display_server_stub.dart' if (dart.library.io) 'customer_display_server_io.dart';
