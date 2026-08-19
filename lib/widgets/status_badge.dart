import 'package:flutter/material.dart';

import '../theme/app_semantic_colors.dart';

enum StatusBadgeTone { danger, warning, info }

/// Etiqueta de estado (ej. "Agotado", "Inventario bajo") con un color y
/// forma consistentes — reemplaza las variantes sueltas que había antes
/// (texto rojo chico en un lado, scrim negro con texto blanco en otro).
class StatusBadge extends StatelessWidget {
  final String label;
  final StatusBadgeTone tone;
  final bool dense;

  const StatusBadge({super.key, required this.label, required this.tone, this.dense = false});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final semantic = AppSemanticColors.of(context);
    final (Color background, Color foreground) = switch (tone) {
      StatusBadgeTone.danger => (colorScheme.error, colorScheme.onError),
      StatusBadgeTone.warning => (semantic.warning, semantic.onWarning),
      StatusBadgeTone.info => (colorScheme.primary, colorScheme.onPrimary),
    };
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 6 : 10, vertical: dense ? 2 : 4),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(999)),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontWeight: FontWeight.bold,
          fontSize: dense ? 11 : 12,
        ),
      ),
    );
  }
}
