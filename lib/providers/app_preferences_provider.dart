import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppPreferencesProvider extends ChangeNotifier {
  static const _darkModeKey = 'dark_mode';
  static const _listLayoutKey = 'pos_list_layout';
  static const _cameraScanKey = 'camera_scan_enabled';
  static const _knownEmailsKey = 'pin_known_emails';

  bool darkMode = false;
  bool useListLayout = false;
  bool cameraScanEnabled = true;
  bool loaded = false;

  // Correos que ya iniciaron sesión en ESTE dispositivo, para poder mostrar
  // el acceso rápido con PIN (elegir quién eres + escribir tu PIN) en vez de
  // tener que escribir correo y contraseña cada vez que cambia el cajero.
  // Solo se guarda el correo, nunca la contraseña.
  List<String> knownEmails = [];

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    darkMode = prefs.getBool(_darkModeKey) ?? false;
    useListLayout = prefs.getBool(_listLayoutKey) ?? false;
    cameraScanEnabled = prefs.getBool(_cameraScanKey) ?? true;
    knownEmails = prefs.getStringList(_knownEmailsKey) ?? [];
    loaded = true;
    notifyListeners();
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
