import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/current_store.dart';
import '../models/store_settings.dart';

class SettingsRepository {
  final SupabaseClient _client = Supabase.instance.client;

  Future<StoreSettings> getSettings() async {
    final storeId = CurrentStore.id;
    if (storeId == null) return StoreSettings(taxRatePercent: 0);
    final data = await _client.from('store_settings').select().eq('store_id', storeId).maybeSingle();
    if (data == null) return StoreSettings(taxRatePercent: 0);
    return StoreSettings.fromMap(data);
  }

  Future<void> updateTaxRate(double taxRatePercent) async {
    await _client.from('store_settings').upsert({
      'store_id': CurrentStore.id,
      'tax_rate_percent': taxRatePercent,
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'store_id');
  }

  Future<void> updateDefaultMargin(double defaultMarginPercent) async {
    await _client.from('store_settings').upsert({
      'store_id': CurrentStore.id,
      'default_margin_percent': defaultMarginPercent,
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'store_id');
  }

  Future<void> updateLowStockNotifyEmail(String? email) async {
    await _client.from('store_settings').upsert({
      'store_id': CurrentStore.id,
      'low_stock_notify_email': email,
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'store_id');
  }

  Future<void> updateOcrApiKey(String? apiKey) async {
    await _client.from('store_settings').upsert({
      'store_id': CurrentStore.id,
      'ocr_api_key': apiKey,
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'store_id');
  }

  Future<void> updateGoogleSearchConfig({required String? apiKey, required String? engineId}) async {
    await _client.from('store_settings').upsert({
      'store_id': CurrentStore.id,
      'google_search_api_key': apiKey,
      'google_search_engine_id': engineId,
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'store_id');
  }

  /// Llama a la Edge Function "notify-low-stock" (ver LEEME.md para
  /// activarla) para revisar el inventario y enviar la alerta por correo
  /// ahora mismo. Devuelve un mensaje para mostrarle al usuario.
  Future<String> sendLowStockTestEmail() async {
    try {
      final res = await _client.functions.invoke('notify-low-stock');
      final data = res.data;
      if (res.status == 200) {
        if (data is Map && data['count'] == 0) return 'No hay productos con inventario bajo ahora mismo.';
        if (data is Map && data['sent'] == true) return 'Alerta enviada por correo.';
        return 'Hay productos con inventario bajo, pero no se pudo enviar el correo. '
            'Revisa el correo configurado y la clave de Resend.';
      }
      if (data is Map && data['error'] != null) return 'Error: ${data['error']}';
      return 'Error inesperado (código ${res.status})';
    } catch (e) {
      return 'No se pudo conectar con la función "notify-low-stock". ¿Ya la creaste en Supabase? ($e)';
    }
  }

  /// Llama a la Edge Function "fill-missing-photos" (ver LEEME.md para
  /// activarla) para buscar en internet, ahora mismo, una foto de los
  /// productos de esta tienda que tengan código de barras pero no tengan
  /// foto todavía. Devuelve un mensaje para mostrarle al usuario.
  Future<String> fillMissingPhotosNow() async {
    try {
      final res = await _client.functions.invoke('fill-missing-photos', body: {'limit': 15});
      final data = res.data;
      if (res.status == 200 && data is Map) {
        final updated = data['updated'] ?? 0;
        final scanned = data['scanned'] ?? 0;
        if (scanned == 0) return 'No hay productos sin foto pendientes (con código de barras).';
        return 'Listo: se agregó foto a $updated de $scanned producto(s) revisados.';
      }
      if (data is Map && data['error'] != null) return 'Error: ${data['error']}';
      return 'Error inesperado (código ${res.status})';
    } catch (e) {
      return 'No se pudo conectar con la función "fill-missing-photos". ¿Ya la creaste en Supabase? ($e)';
    }
  }

  /// Llama a la Edge Function "generate-thumbnails" (ver LEEME.md para
  /// activarla) para generarle una miniatura chica a los productos que
  /// tienen foto pero todavía no tienen una — una tanda por corrida.
  /// Devuelve un mensaje para mostrarle al usuario.
  Future<String> generateThumbnailsNow() async {
    try {
      final res = await _client.functions.invoke('generate-thumbnails', body: {'limit': 200});
      final data = res.data;
      if (res.status == 200 && data is Map) {
        final updated = data['updated'] ?? 0;
        final processed = data['processed'] ?? 0;
        if (processed == 0) return 'No hay fotos pendientes de miniatura.';
        final hasMore = data['hasMore'] == true;
        return 'Listo: se generó miniatura a $updated de $processed foto(s) revisadas.'
            '${hasMore ? ' Quedan más pendientes — toca el botón de nuevo para seguir.' : ''}';
      }
      if (data is Map && data['error'] != null) return 'Error: ${data['error']}';
      return 'Error inesperado (código ${res.status})';
    } catch (e) {
      return 'No se pudo conectar con la función "generate-thumbnails". ¿Ya la creaste en Supabase? ($e)';
    }
  }

  /// Le pide a la misma función que le genere (o regenere) la miniatura a
  /// UN producto puntual — se llama sola justo después de subirle una foto
  /// nueva, sin bloquear el guardado si falla (la miniatura es una mejora
  /// de ancho de banda, no algo de lo que dependa poder vender el producto).
  Future<void> generateThumbnailForProduct(String productId) async {
    try {
      await _client.functions.invoke('generate-thumbnails', body: {'productId': productId});
    } catch (_) {
      // Silencioso a propósito: si la función no está desplegada todavía,
      // el producto simplemente se queda mostrando la foto completa hasta
      // que se despliegue y se corra el backfill manual.
    }
  }
}
