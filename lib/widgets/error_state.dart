import 'package:flutter/material.dart';

/// Estado de error consistente (ícono + mensaje + botón "Reintentar") para
/// cuando falla la carga inicial de una pantalla — así se distingue
/// claramente de "todavía cargando" o de "no hay datos" ([EmptyState]),
/// en vez de dejar la pantalla en blanco o el círculo de carga para
/// siempre.
class ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final IconData icon;

  const ErrorState({
    super.key,
    required this.message,
    required this.onRetry,
    this.icon = Icons.error_outline,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.error;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: color),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
