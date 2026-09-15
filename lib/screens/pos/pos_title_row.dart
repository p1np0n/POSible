import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/cash_session_provider.dart';
import '../../providers/store_provider.dart';
import '../../theme/app_semantic_colors.dart';
import '../../utils/date_format_es.dart';

/// Fila de encabezado de Ventas con el nombre de la pantalla y la fecha de
/// hoy a la izquierda, y un chip verde "Caja abierta" a la derecha mientras
/// haya un turno en curso.
class PosTitleRow extends StatelessWidget {
  final CashSessionProvider cashSession;

  const PosTitleRow({super.key, required this.cashSession});

  @override
  Widget build(BuildContext context) {
    final storeName = context.watch<StoreProvider>().myStore?.name ?? 'Tienda';
    final today = formatDayHeaderEs(DateTime.now())
        .replaceFirst(', ', ' ')
        .replaceFirst(RegExp(r' de \d{4}$'), '');
    final semantic = AppSemanticColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Ventas', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 2),
                Text(
                  '$storeName · $today',
                  style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          if (cashSession.isOpen)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(color: semantic.successContainer, borderRadius: BorderRadius.circular(999)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(color: semantic.onSuccessContainer, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Caja abierta',
                    style: TextStyle(color: semantic.onSuccessContainer, fontSize: 12.5, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
