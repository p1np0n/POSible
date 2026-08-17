import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/store.dart';

class MyStoreInfo {
  final bool isSuperAdmin;
  final Store? store;

  MyStoreInfo({required this.isSuperAdmin, required this.store});
}

class StoreRepository {
  final SupabaseClient _client = Supabase.instance.client;

  Future<MyStoreInfo> getMyStoreInfo() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return MyStoreInfo(isSuperAdmin: false, store: null);

    final profile = await _client
        .from('profiles')
        .select('is_super_admin, store_id')
        .eq('id', userId)
        .maybeSingle();
    if (profile == null) return MyStoreInfo(isSuperAdmin: false, store: null);

    final isSuperAdmin = profile['is_super_admin'] as bool? ?? false;
    final storeId = profile['store_id'] as String?;
    if (storeId == null) return MyStoreInfo(isSuperAdmin: isSuperAdmin, store: null);

    final storeData = await _client.from('stores').select().eq('id', storeId).maybeSingle();
    return MyStoreInfo(
      isSuperAdmin: isSuperAdmin,
      store: storeData == null ? null : Store.fromMap(storeData),
    );
  }

  /// Solo el administrador principal puede llamar esto: las políticas de la
  /// base de datos devuelven todas las tiendas si eres administrador, o
  /// únicamente la tuya si no lo eres.
  Future<List<Store>> getAllStores() async {
    final data = await _client.from('stores').select().order('created_at');
    return (data as List).map((e) => Store.fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<void> updateFeatures(
    String storeId, {
    bool? featureReports,
    bool? featureCustomers,
    bool? featureEmployees,
  }) async {
    final updates = <String, dynamic>{};
    if (featureReports != null) updates['feature_reports'] = featureReports;
    if (featureCustomers != null) updates['feature_customers'] = featureCustomers;
    if (featureEmployees != null) updates['feature_employees'] = featureEmployees;
    if (updates.isEmpty) return;
    await _client.from('stores').update(updates).eq('id', storeId);
  }
}
