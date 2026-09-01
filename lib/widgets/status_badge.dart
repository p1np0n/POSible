import 'package:flutter/material.dart';

import '../theme/app_semantic_colors.dart';

enum StatusBadgeTone { ok, danger, warning, info }

/// Etiqueta de estado (ej. "Stock: 10", "Agotado", "Inventario bajo") con un
/// color y forma consistentes en toda la app: fondo suave + texto saturado
/// del mismo tono (igual criterio que `errorContainer`/`onErrorContainer` de
/// Material), en vez de las variantes sueltas que había antes (texto rojo
/// chico en un lado, scrim negro con texto blanco en otro).
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
      StatusBadgeTone.ok => (semantic.successContainer, semantic.onSuccessContainer),
      StatusBadgeTone.danger => (colorScheme.errorContainer, colorScheme.onErrorContainer),
      StatusBadgeTone.warning => (semantic.warningContainer, semantic.onWarningContainer),
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
