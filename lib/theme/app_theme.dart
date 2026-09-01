import 'package:flutter/material.dart';

import 'app_semantic_colors.dart';

/// Color principal de la marca: naranja, con blanco y negro como base
/// neutra (en vez del morado/índigo que traía Flutter por defecto) — así
/// se ve más parecido a lo que se pidió, y se aplica en toda la app
/// (botones, barra de arriba, etc.) desde un solo lugar. Es una versión
/// más apagada/sobria del naranja original (0xFFFF7A1A), menos brillante.
const brandOrange = Color(0xFFE0722E);

/// Fondo de pantalla en modo claro: un plomo bien clarito en vez de blanco
/// puro, que cansa menos la vista. Las tarjetas (Card) se quedan blancas
/// encima de este fondo, para que se noten como una capa por separado.
const _lightBackground = Color(0xFFF1F1F3);

const _successColor = Color(0xFF2E7D32);
const _warningColor = Color(0xFFB26A00);

ThemeData buildAppTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final colorScheme = ColorScheme.fromSeed(seedColor: brandOrange, brightness: brightness).copyWith(
    primary: brandOrange,
    onPrimary: Colors.white,
    surface: isDark ? const Color(0xFF121212) : _lightBackground,
    onSurface: isDark ? Colors.white : Colors.black,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: colorScheme.surface,
    cardColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
    appBarTheme: const AppBarTheme(
      backgroundColor: brandOrange,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      elevation: 1,
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
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
