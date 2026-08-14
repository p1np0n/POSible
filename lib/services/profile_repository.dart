import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/employee_profile.dart';

class ProfileRepository {
  final SupabaseClient _client = Supabase.instance.client;

  /// Devuelve el perfil del usuario actual, o null si todavía no existe
  /// (puede pasar justo después de crear la cuenta, por una fracción de
  /// segundo, mientras corre el trigger que lo crea).
  Future<EmployeeProfile?> getMyProfile() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    final data = await _client.from('profiles').select().eq('id', userId).maybeSingle();
    if (data == null) return null;
    return EmployeeProfile.fromMap(data);
  }

  Future<List<EmployeeProfile>> getAll() async {
    final data = await _client.from('profiles').select().order('created_at');
    return (data as List).map((e) => EmployeeProfile.fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<void> setApproved(String id, bool approved) async {
    await _client.from('profiles').update({'approved': approved}).eq('id', id);
  }

  Future<void> remove(String id) async {
    await _client.from('profiles').delete().eq('id', id);
  }
}
