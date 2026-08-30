import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/supabase_config.dart';
import 'main.dart';
import 'screens/info_admin/info_admin_shell.dart';

/// Punto de entrada de "Info Admin": un APK aparte, chico, del mismo
/// proyecto POSible — mismo login y misma base de datos, pero mostrando
/// solo Inventario, Reportes y Lista de artículos con un menú abajo (ver
/// InfoAdminShell), sin el resto de la app. Se compila con
/// `flutter build apk -t lib/main_info_admin.dart` (ver
/// .github/workflows/build_info_admin.yml), en vez de este archivo
/// convertir el proyecto en dos apps separadas.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  enableVerboseErrorDisplay();
  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
  );
  runApp(const PosibleApp(title: 'Info Admin', home: InfoAdminShell()));
}
