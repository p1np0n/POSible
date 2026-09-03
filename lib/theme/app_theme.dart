import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_semantic_colors.dart';

/// Color de acento de marca: terracota, reemplazando el naranja genérico
/// anterior — se aplica en toda la app desde este único lugar (botones,
/// barra de arriba, ítem de menú activo, etc.).
const brandOrange = Color(0xFFC1652F);

/// Fondo de pantalla en modo claro: un beige/plomo cálido en vez de blanco
/// puro o el plomo frío que traía antes — cansa menos la vista y separa
/// mejor las tarjetas blancas que quedan encima.
const _lightBackground = Color(0xFFF6F4F0);

/// Borde de tarjetas/inputs en modo claro — 1px, sutil, sobre fondo blanco.
const _lightOutline = Color(0xFFE7E2D8);

const _lightOnSurface = Color(0xFF221F1A);
const _lightOnSurfaceVariant = Color(0xFF847E70);

const _successColor = Color(0xFF2C7A46);
const _successContainerLight = Color(0xFFEAF6EE);
const _warningColor = Color(0xFF96590A);
const _warningContainerLight = Color(0xFFFBF0DC);
const _dangerColor = Color(0xFFB33A2E);
const _dangerContainerLight = Color(0xFFFBE6E2);

/// Radio de esquina compartido por tarjetas, inputs y botones — 12-16px
/// según el tamaño del elemento, igual que en el prototipo de diseño.
const double cardRadius = 16;
const double controlRadius = 12;

ThemeData buildAppTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final colorScheme = ColorScheme.fromSeed(seedColor: brandOrange, brightness: brightness).copyWith(
    primary: brandOrange,
    onPrimary: Colors.white,
    surface: isDark ? const Color(0xFF121212) : _lightBackground,
    onSurface: isDark ? Colors.white : _lightOnSurface,
    onSurfaceVariant: isDark ? const Color(0xFFC7C1B8) : _lightOnSurfaceVariant,
    outlineVariant: isDark ? const Color(0xFF3A3833) : _lightOutline,
    error: _dangerColor,
    onError: Colors.white,
    errorContainer: isDark ? const Color(0xFF4A2420) : _dangerContainerLight,
    onErrorContainer: isDark ? const Color(0xFFFFB4A9) : _dangerColor,
  );

  final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

  // Manrope para el cuerpo del texto (400-800), Space Grotesk (600-700)
  // para títulos y números grandes (precios, KPIs) — se pisan encima acá
  // los estilos que corresponden a títulos, el resto queda en Manrope.
  final baseTextTheme = GoogleFonts.manropeTextTheme(ThemeData(brightness: brightness).textTheme);
  final textTheme = baseTextTheme.copyWith(
    displayLarge: GoogleFonts.spaceGrotesk(textStyle: baseTextTheme.displayLarge, fontWeight: FontWeight.w700),
    displayMedium: GoogleFonts.spaceGrotesk(textStyle: baseTextTheme.displayMedium, fontWeight: FontWeight.w700),
    displaySmall: GoogleFonts.spaceGrotesk(textStyle: baseTextTheme.displaySmall, fontWeight: FontWeight.w700),
    headlineLarge: GoogleFonts.spaceGrotesk(textStyle: baseTextTheme.headlineLarge, fontWeight: FontWeight.w700),
    headlineMedium: GoogleFonts.spaceGrotesk(textStyle: baseTextTheme.headlineMedium, fontWeight: FontWeight.w700),
    headlineSmall: GoogleFonts.spaceGrotesk(
      textStyle: baseTextTheme.headlineSmall,
      fontWeight: FontWeight.w700,
      fontSize: 26,
    ),
    titleLarge: GoogleFonts.spaceGrotesk(textStyle: baseTextTheme.titleLarge, fontWeight: FontWeight.w700),
    titleMedium: GoogleFonts.spaceGrotesk(textStyle: baseTextTheme.titleMedium, fontWeight: FontWeight.w600),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: colorScheme.surface,
    cardColor: cardColor,
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: brandOrange,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.spaceGrotesk(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(cardRadius),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: cardColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(controlRadius),
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(controlRadius),
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(controlRadius),
        borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
      ),
      isDense: true,
    ),
    chipTheme: ChipThemeData(
      shape: const StadiumBorder(),
      backgroundColor: cardColor,
      side: BorderSide(color: colorScheme.outlineVariant),
      selectedColor: colorScheme.primary,
      labelStyle: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w600),
      secondaryLabelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
    ),
    listTileTheme: ListTileThemeData(
      selectedTileColor: colorScheme.primary.withOpacity(0.08),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(controlRadius)),
        disabledBackgroundColor: colorScheme.primary.withOpacity(0.35),
        disabledForegroundColor: Colors.white.withOpacity(0.85),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(controlRadius)),
        side: BorderSide(color: colorScheme.outlineVariant),
        disabledForegroundColor: colorScheme.onSurface.withOpacity(0.45),
      ),
    ),
    extensions: [
      AppSemanticColors(
        success: _successColor,
        onSuccess: Colors.white,
        successContainer: isDark ? const Color(0xFF1E3A28) : _successContainerLight,
        onSuccessContainer: isDark ? const Color(0xFF8FDBA6) : _successColor,
        warning: _warningColor,
        onWarning: Colors.white,
        warningContainer: isDark ? const Color(0xFF4A3410) : _warningContainerLight,
        onWarningContainer: isDark ? const Color(0xFFF0C87A) : _warningColor,
      ),
    ],
  );
}
