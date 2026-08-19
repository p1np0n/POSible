import 'package:flutter/material.dart';

/// Colores que Material's `ColorScheme` no trae por defecto (éxito y
/// advertencia) — "peligro" reutiliza `colorScheme.error`, no hace falta
/// duplicarlo acá. Se registra como `ThemeExtension` para que interpole
/// bien entre modo claro/oscuro, igual que el resto del `ColorScheme`.
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  final Color success;
  final Color onSuccess;
  final Color warning;
  final Color onWarning;

  const AppSemanticColors({
    required this.success,
    required this.onSuccess,
    required this.warning,
    required this.onWarning,
  });

  static AppSemanticColors of(BuildContext context) =>
      Theme.of(context).extension<AppSemanticColors>()!;

  @override
  AppSemanticColors copyWith({Color? success, Color? onSuccess, Color? warning, Color? onWarning}) {
    return AppSemanticColors(
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
      warning: warning ?? this.warning,
      onWarning: onWarning ?? this.onWarning,
    );
  }

  @override
  AppSemanticColors lerp(ThemeExtension<AppSemanticColors>? other, double t) {
    if (other is! AppSemanticColors) return this;
    return AppSemanticColors(
      success: Color.lerp(success, other.success, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
    );
  }
}
