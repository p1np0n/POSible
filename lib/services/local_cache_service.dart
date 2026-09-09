import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Guarda listas de datos (por ahora, el catálogo de productos) en el
/// propio celular, para que la app pueda mostrar algo de inmediato al
/// abrir Ventas — incluso sin internet todavía — mientras se actualiza
/// sola de fondo apenas haya conexión. Usa `shared_preferences` (ya es una
/// dependencia de la app) en vez de agregar una base de datos local nueva,
/// que sería mucho más para lo que hace falta acá: guardar y leer una
/// lista completa de una sola vez, no consultarla fila por fila.
class LocalCacheService {
  static Future<void> saveList(String key, List<Map<String, dynamic>> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(items));
  }

  /// null si nunca se guardó nada con esa clave, o si lo guardado quedó
  /// dañado/con un formato viejo que ya no se puede leer (ej. se cambió el
  /// modelo de datos) — en ambos casos, quien llama debe tratarlo igual
  /// que "no hay caché todavía" y pedirlo del servidor.
  static Future<List<Map<String, dynamic>>?> loadList(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw) as List;
      return decoded.cast<Map<String, dynamic>>();
    } catch (_) {
      return null;
    }
  }
}
