import 'package:supabase_flutter/supabase_flutter.dart';

/// Acceso rápido con PIN de 4 dígitos, para administradores y cajeros por
/// igual. El PIN nunca es la contraseña real de la cuenta (eso permite que
/// el administrador tenga una contraseña fuerte de verdad, separada de su
/// PIN corto) — se verifica en el servidor (Edge Function "verify-pin",
/// ver LEEME.md para activarla) y, si es correcto, la función devuelve un
/// enlace de acceso que se canjea acá por una sesión real.
class PinAuthRepository {
  final SupabaseClient _client = Supabase.instance.client;

  /// Devuelve un mensaje de error para mostrarle al usuario, o null si el
  /// PIN era correcto y ya quedó la sesión iniciada.
  Future<String?> loginWithPin({required String email, required String pin}) async {
    try {
      final res = await _client.functions.invoke('verify-pin', body: {'email': email, 'pin': pin});
      final data = res.data;
      if (res.status != 200 || data is! Map || data['ok'] != true) {
        final error = (data is Map) ? data['error'] : null;
        if (error == 'no_pin_set') {
          return 'Esta cuenta todavía no tiene un PIN configurado. Inicia sesión con tu correo y '
              'contraseña, y configúralo en Configuración.';
        }
        if (error != null) return error as String;
        return 'Error inesperado (código ${res.status})';
      }
      final tokenHash = data['tokenHash'] as String;
      await _client.auth.verifyOTP(type: OtpType.magiclink, tokenHash: tokenHash, email: email);
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'No se pudo conectar con la función "verify-pin". ¿Ya la creaste en Supabase? ($e)';
    }
  }
}
