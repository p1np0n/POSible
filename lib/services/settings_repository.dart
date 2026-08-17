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

  Future<void> updateLowStockNotifyEmail(String? email) async {
    await _client.from('store_settings').upsert({
      'store_id': CurrentStore.id,
      'low_stock_notify_email': email,
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
}
