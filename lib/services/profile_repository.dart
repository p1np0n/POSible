import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/employee_profile.dart';
import '../utils/query_timeout.dart';

class ProfileRepository {
  final SupabaseClient _client = Supabase.instance.client;

  /// Devuelve el perfil del usuario actual, o null si todavía no existe
  /// (puede pasar justo después de crear la cuenta, por una fracción de
  /// segundo, mientras corre el trigger que lo crea).
  Future<EmployeeProfile?> getMyProfile() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    final data = await _client.from('profiles').select().eq('id', userId).maybeSingle().withTimeout();
    if (data == null) return null;
    return EmployeeProfile.fromMap(data);
  }

  Future<List<EmployeeProfile>> getAll() async {
    final data = await _client.from('profiles').select().order('created_at').withTimeout();
    return (data as List).map((e) => EmployeeProfile.fromMap(e as Map<String, dynamic>)).toList();
  }

  /// Empleados de una tienda en particular — para el administrador
  /// principal, desde "Tiendas", para poder restablecerles el PIN sin
  /// necesidad de iniciar sesión en esa tienda.
  Future<List<EmployeeProfile>> getForStore(String storeId) async {
    final data =
        await _client.from('profiles').select().eq('store_id', storeId).order('created_at').withTimeout();
    return (data as List).map((e) => EmployeeProfile.fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<void> setApproved(String id, bool approved) async {
    await _client.from('profiles').update({'approved': approved}).eq('id', id).withTimeout();
  }

  /// Cambia el nombre a mostrar de un empleado (o el propio) — solo afecta
  /// cómo aparece en la app, no su correo real ni su forma de iniciar
  /// sesión.
  Future<void> setDisplayName(String id, String displayName) async {
    await _client.from('profiles').update({'display_name': displayName}).eq('id', id).withTimeout();
  }

  Future<void> remove(String id) async {
    await _client.from('profiles').delete().eq('id', id).withTimeout();
  }

  /// Crea un cajero nuevo (nombre + PIN de 4 dígitos, sin correo visible —
  /// se genera uno interno solo). Llama a la Edge Function
  /// "manage-employee" (ver LEEME.md para activarla). Solo un
  /// administrador de la tienda puede hacerlo. Devuelve un mensaje de
  /// error, o null si funcionó.
  Future<String?> createEmployee({required String displayName, required String pin}) async {
    try {
      final res = await _client.functions.invoke('manage-employee', body: {
        'action': 'create',
        'display_name': displayName,
        'pin': pin,
      });
      return _errorFromResponse(res);
    } catch (e) {
      return 'No se pudo conectar con la función "manage-employee". ¿Ya la creaste en Supabase? ($e)';
    }
  }

  /// Cambia el PIN de un usuario ya existente — el propio administrador
  /// (su PIN de acceso rápido) o el de un cajero de su tienda.
  Future<String?> setPin({required String userId, required String pin}) async {
    try {
      final res = await _client.functions.invoke('manage-employee', body: {
        'action': 'set_pin',
        'user_id': userId,
        'pin': pin,
      });
      return _errorFromResponse(res);
    } catch (e) {
      return 'No se pudo conectar con la función "manage-employee". ¿Ya la creaste en Supabase? ($e)';
    }
  }

  /// Restablece la contraseña REAL de una cuenta (no el PIN) — exclusivo
  /// del administrador principal, para ayudar al dueño de otra tienda que
  /// perdió su contraseña. Ver "Tiendas".
  Future<String?> setPassword({required String userId, required String password}) async {
    try {
      final res = await _client.functions.invoke('manage-employee', body: {
        'action': 'set_password',
        'user_id': userId,
        'password': password,
      });
      return _errorFromResponse(res);
    } catch (e) {
      return 'No se pudo conectar con la función "manage-employee". ¿Ya la creaste en Supabase? ($e)';
    }
  }

  /// Prende/apaga los permisos extra de un cajero (ver GRANTABLE_PERMISSIONS
  /// en la Edge Function) — Configuración y Empleados nunca están acá, esos
  /// quedan siempre exclusivos del rol 'admin'.
  Future<String?> setPermissions({required String userId, required List<String> permissions}) async {
    try {
      final res = await _client.functions.invoke('manage-employee', body: {
        'action': 'set_permissions',
        'user_id': userId,
        'permissions': permissions,
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
