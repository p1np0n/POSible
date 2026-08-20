import 'dart:async';

/// Límite de tiempo para consultas a Supabase que, sin esto, se podían
/// quedar "cargando" para siempre si la base de datos tardaba demasiado
/// (ej. Reportes con una tabla de ventas grande y sin índice) — mejor un
/// error claro que una pantalla colgada.
extension QueryTimeout<T> on Future<T> {
  Future<T> withTimeout([Duration duration = const Duration(seconds: 15)]) {
    return timeout(
      duration,
      onTimeout: () =>
          throw TimeoutException('La consulta tardó demasiado. Revisa tu conexión e intenta de nuevo.'),
    );
  }
}
