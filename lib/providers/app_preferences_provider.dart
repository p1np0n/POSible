import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppPreferencesProvider extends ChangeNotifier {
  static const _darkModeKey = 'dark_mode';
  static const _listLayoutKey = 'pos_list_layout';
  static const _cameraScanKey = 'camera_scan_enabled';
  static const _knownEmailsKey = 'pin_known_emails';
  static const _autoLockMinutesKey = 'auto_lock_minutes';
  static const _lastActiveAtKey = 'last_active_at';

  bool darkMode = false;
  bool useListLayout = false;
  bool cameraScanEnabled = true;
  bool loaded = false;

  // Correos que ya iniciaron sesión en ESTE dispositivo, para poder mostrar
  // el acceso rápido con PIN (elegir quién eres + escribir tu PIN) en vez de
  // tener que escribir correo y contraseña cada vez que cambia el cajero.
  // Solo se guarda el correo, nunca la contraseña.
  List<String> knownEmails = [];

  // Minutos que puede estar la app en segundo plano antes de pedir el PIN
  // de nuevo al volver. 0 = nunca pedirlo.
  int autoLockMinutes = 15;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    darkMode = prefs.getBool(_darkModeKey) ?? false;
    useListLayout = prefs.getBool(_listLayoutKey) ?? false;
    cameraScanEnabled = prefs.getBool(_cameraScanKey) ?? true;
    knownEmails = prefs.getStringList(_knownEmailsKey) ?? [];
    autoLockMinutes = prefs.getInt(_autoLockMinutesKey) ?? 15;
    loaded = true;
    notifyListeners();
  }

  Future<void> setAutoLockMinutes(int value) async {
    autoLockMinutes = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_autoLockMinutesKey, value);
  }

  /// Marca "ahora" como el último momento en que la app estuvo activa.
  /// Se llama cada vez que la app pasa a segundo plano y cada vez que se
  /// desbloquea, para medir cuánto tiempo estuvo sin usarse.
  Future<void> markActiveNow() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastActiveAtKey, DateTime.now().millisecondsSinceEpoch);
  }

  /// true si pasó más tiempo del permitido desde la última vez que la app
  /// estuvo activa, y por lo tanto hay que pedir el PIN de nuevo.
  Future<bool> shouldLock() async {
    if (autoLockMinutes <= 0) return false;
    final prefs = await SharedPreferences.getInstance();
    final lastActive = prefs.getInt(_lastActiveAtKey);
    if (lastActive == null) return false;
    final elapsedMs = DateTime.now().millisecondsSinceEpoch - lastActive;
    return elapsedMs > autoLockMinutes * 60 * 1000;
  }

  Future<void> rememberEmail(String email) async {
    if (knownEmails.contains(email)) return;
    knownEmails = [...knownEmails, email];
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_knownEmailsKey, knownEmails);
  }

  Future<void> forgetEmail(String email) async {
    knownEmails = knownEmails.where((e) => e != email).toList();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_knownEmailsKey, knownEmails);
  }

  Future<void> setDarkMode(bool value) async {
    darkMode = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_darkModeKey, value);
  }

  Future<void> setUseListLayout(bool value) async {
    useListLayout = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_listLayoutKey, value);
  }

  Future<void> setCameraScanEnabled(bool value) async {
    cameraScanEnabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_cameraScanKey, value);
  }
}
