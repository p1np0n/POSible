import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppPreferencesProvider extends ChangeNotifier {
  static const _darkModeKey = 'dark_mode';
  static const _listLayoutKey = 'pos_list_layout';
  static const _cameraScanKey = 'camera_scan_enabled';
  static const _usbScannerModeKey = 'usb_scanner_mode_enabled';
  static const _knownEmailsKey = 'pin_known_emails';
  static const _knownDisplayNamesKey = 'pin_known_display_names';
  static const _autoLockMinutesKey = 'auto_lock_minutes';
  static const _lastActiveAtKey = 'last_active_at';
  static const _screenDimmingKey = 'screen_dimming_enabled';

  bool darkMode = false;
  bool useListLayout = false;
  bool cameraScanEnabled = true;
  bool loaded = false;

  /// Si está activo, la pantalla se oscurece sola (sin llegar a apagarse)
  /// después de un minuto sin tocarla, para ahorrar batería en el
  /// mostrador — apenas se vuelve a tocar, recupera el brillo normal. Solo
  /// aplica al APK (Android/iOS), no al panel web.
  bool screenDimmingEnabled = true;

  /// Si está activo, en Ventas el buscador (donde también se puede
  /// escanear) recupera el foco solo después de cada acción — así un
  /// lector de código de barras USB/OTG, que funciona como un teclado,
  /// siempre puede escribir ahí sin que el cajero tenga que tocarlo entre
  /// un escaneo y otro. Apagado por defecto porque en una pantalla táctil
  /// sin ese tipo de lector esto abriría el teclado en pantalla de más.
  bool usbScannerModeEnabled = false;

  // Correos que ya iniciaron sesión en ESTE dispositivo, para poder mostrar
  // el acceso rápido con PIN (elegir quién eres + escribir tu PIN) en vez de
  // tener que escribir correo y contraseña cada vez que cambia el cajero.
  // Solo se guarda el correo, nunca la contraseña ni el PIN.
  List<String> knownEmails = [];

  // Nombre para mostrar de cada correo conocido (ej. "Juan", el nombre que
  // le puso el administrador al crear al cajero) — el correo de un cajero
  // es uno interno generado solo, no algo que tenga sentido mostrarle. El
  // administrador lo agrega desde "Empleados" (botón "Agregar a este
  // dispositivo"); si un correo no tiene nombre guardado, se muestra el
  // correo tal cual.
  Map<String, String> knownDisplayNames = {};

  // Minutos que puede estar la app en segundo plano antes de pedir el PIN
  // de nuevo al volver. 0 = nunca pedirlo.
  int autoLockMinutes = 15;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    darkMode = prefs.getBool(_darkModeKey) ?? false;
    useListLayout = prefs.getBool(_listLayoutKey) ?? false;
    cameraScanEnabled = prefs.getBool(_cameraScanKey) ?? true;
    usbScannerModeEnabled = prefs.getBool(_usbScannerModeKey) ?? false;
    knownEmails = prefs.getStringList(_knownEmailsKey) ?? [];
    final rawDisplayNames = prefs.getString(_knownDisplayNamesKey);
    if (rawDisplayNames != null) {
      try {
        knownDisplayNames = Map<String, String>.from(jsonDecode(rawDisplayNames) as Map);
      } catch (_) {
        knownDisplayNames = {};
      }
    }
    autoLockMinutes = prefs.getInt(_autoLockMinutesKey) ?? 15;
    screenDimmingEnabled = prefs.getBool(_screenDimmingKey) ?? true;
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

  Future<void> rememberEmail(String email, {String? displayName}) async {
    final prefs = await SharedPreferences.getInstance();
    if (!knownEmails.contains(email)) {
      knownEmails = [...knownEmails, email];
      await prefs.setStringList(_knownEmailsKey, knownEmails);
    }
    if (displayName != null && displayName.trim().isNotEmpty) {
      knownDisplayNames = {...knownDisplayNames, email: displayName.trim()};
      await prefs.setString(_knownDisplayNamesKey, jsonEncode(knownDisplayNames));
    }
    notifyListeners();
  }

  Future<void> forgetEmail(String email) async {
    knownEmails = knownEmails.where((e) => e != email).toList();
    knownDisplayNames = {...knownDisplayNames}..remove(email);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_knownEmailsKey, knownEmails);
    await prefs.setString(_knownDisplayNamesKey, jsonEncode(knownDisplayNames));
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

  Future<void> setUsbScannerModeEnabled(bool value) async {
    usbScannerModeEnabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_usbScannerModeKey, value);
  }

  Future<void> setScreenDimmingEnabled(bool value) async {
    screenDimmingEnabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_screenDimmingKey, value);
  }
}
