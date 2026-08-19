import 'package:flutter/material.dart';

import 'app_semantic_colors.dart';

/// Color principal de la marca: naranja, con blanco y negro como base
/// neutra (en vez del morado/índigo que traía Flutter por defecto) — así
/// se ve más parecido a lo que se pidió, y se aplica en toda la app
/// (botones, barra de arriba, etc.) desde un solo lugar.
const brandOrange = Color(0xFFFF7A1A);

const _successColor = Color(0xFF2E7D32);
const _warningColor = Color(0xFFB26A00);

ThemeData buildAppTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final colorScheme = ColorScheme.fromSeed(seedColor: brandOrange, brightness: brightness).copyWith(
    primary: brandOrange,
    onPrimary: Colors.white,
    surface: isDark ? const Color(0xFF121212) : Colors.white,
    onSurface: isDark ? Colors.white : Colors.black,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: colorScheme.surface,
    appBarTheme: const AppBarTheme(
      backgroundColor: brandOrange,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: const CardThemeData(
      elevation: 1,
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
      isDense: true,
    ),
    chipTheme: ChipThemeData(
      shape: const StadiumBorder(),
      selectedColor: colorScheme.primary.withOpacity(0.18),
      labelStyle: TextStyle(color: colorScheme.onSurface),
    ),
    listTileTheme: ListTileThemeData(
      selectedTileColor: colorScheme.primary.withOpacity(0.08),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        disabledBackgroundColor: colorScheme.primary.withOpacity(0.35),
        disabledForegroundColor: Colors.white.withOpacity(0.85),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        disabledForegroundColor: colorScheme.onSurface.withOpacity(0.45),
      ),
    ),
    extensions: [
      AppSemanticColors(
        success: _successColor,
        onSuccess: Colors.white,
        warning: _warningColor,
        onWarning: Colors.white,
      ),
    ],
  );
}
