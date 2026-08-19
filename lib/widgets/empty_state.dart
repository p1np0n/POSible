import 'package:flutter/material.dart';

/// Estado vacío consistente (ícono + mensaje) para reemplazar los textos
/// sueltos que hoy se ven igual que la pantalla "cargando" (nada, sobre
/// fondo liso).
class EmptyState extends StatelessWidget {
  final String message;
  final IconData icon;

  const EmptyState({super.key, required this.message, this.icon = Icons.inbox_outlined});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurface.withOpacity(0.45);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: color),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}
