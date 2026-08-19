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

  /// Empleados de una tienda en particular — para el administrador
  /// principal, desde "Tiendas", para poder restablecerles el PIN sin
  /// necesidad de iniciar sesión en esa tienda.
  Future<List<EmployeeProfile>> getForStore(String storeId) async {
    final data = await _client.from('profiles').select().eq('store_id', storeId).order('created_at');
    return (data as List).map((e) => EmployeeProfile.fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<void> setApproved(String id, bool approved) async {
    await _client.from('profiles').update({'approved': approved}).eq('id', id);
  }

  Future<void> remove(String id) async {
    await _client.from('profiles').delete().eq('id', id);
  }

  /// Crea un empleado con correo y PIN desde el panel web, ya aprobado.
  /// Llama a la Edge Function "manage-employee" (ver LEEME.md para
  /// activarla). Devuelve un mensaje de error, o null si funcionó.
  Future<String?> createEmployee({required String email, required String password}) async {
    try {
      final res = await _client.functions.invoke('manage-employee', body: {
        'action': 'create',
        'email': email,
        'password': password,
      });
      return _errorFromResponse(res);
    } catch (e) {
      return 'No se pudo conectar con la función "manage-employee". ¿Ya la creaste en Supabase? ($e)';
    }
  }

  /// Restablece el PIN (contraseña) de un empleado ya existente.
  Future<String?> resetPin({required String userId, required String newPin}) async {
    try {
      final res = await _client.functions.invoke('manage-employee', body: {
        'action': 'reset_password',
        'user_id': userId,
        'password': newPin,
      });
      return _errorFromResponse(res);
    } catch (e) {
      return 'No se pudo conectar con la función "manage-employee". ¿Ya la creaste en Supabase? ($e)';
    }
  }

  String? _errorFromResponse(FunctionResponse res) {
    if (res.status == 200) return null;
    final data = res.data;
    if (data is Map && data['error'] != null) return data['error'] as String;
    return 'Error inesperado (código ${res.status})';
  }
}
