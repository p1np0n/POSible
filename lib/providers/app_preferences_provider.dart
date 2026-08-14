import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppPreferencesProvider extends ChangeNotifier {
  static const _darkModeKey = 'dark_mode';
  static const _listLayoutKey = 'pos_list_layout';
  static const _cameraScanKey = 'camera_scan_enabled';

  bool darkMode = false;
  bool useListLayout = false;
  bool cameraScanEnabled = true;
  bool loaded = false;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    darkMode = prefs.getBool(_darkModeKey) ?? false;
    useListLayout = prefs.getBool(_listLayoutKey) ?? false;
    cameraScanEnabled = prefs.getBool(_cameraScanKey) ?? true;
    loaded = true;
    notifyListeners();
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
