import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/store_settings.dart';

class SettingsRepository {
  final SupabaseClient _client = Supabase.instance.client;

  Future<StoreSettings> getSettings() async {
    final data = await _client.from('store_settings').select().eq('id', 1).single();
    return StoreSettings.fromMap(data);
  }

  Future<void> updateTaxRate(double taxRatePercent) async {
    await _client.from('store_settings').update({
      'tax_rate_percent': taxRatePercent,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', 1);
  }
}
