import 'package:flutter/material.dart';

import '../../models/stock_movement.dart';
import '../../services/stock_movement_repository.dart';
import '../../utils/date_format_es.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_state.dart';
import '../../widgets/loading_indicator.dart';

/// Vista de solo lectura de "Inventario" (movimientos de entrada/salida de
/// stock) para Info Admin — muestra el mismo historial que la pantalla
/// completa de Inventario del panel, pero sin escanear ni registrar
/// movimientos nuevos, para consultar rápido sin poder tocar nada.
class InfoAdminInventoryScreen extends StatefulWidget {
  const InfoAdminInventoryScreen({super.key});

  @override
  State<InfoAdminInventoryScreen> createState() => _InfoAdminInventoryScreenState();
}

class _InfoAdminInventoryScreenState extends State<InfoAdminInventoryScreen> {
  final StockMovementRepository _repository = StockMovementRepository();
  List<StockMovement> _movements = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final movements = await _repository.getRecent();
      if (!mounted) return;
      setState(() {
        _movements = movements;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudieron cargar los movimientos';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingIndicator();
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);
    if (_movements.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: const [
            SizedBox(height: 120),
            EmptyState(message: 'Todavía no hay movimientos de inventario', icon: Icons.inventory_2_outlined),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _movements.length,
        itemBuilder: (context, index) {
          final m = _movements[index];
          return ListTile(
            leading: Icon(
              m.isIn ? Icons.add_circle_outline : Icons.remove_circle_outline,
              color: m.isIn ? Colors.green : Colors.red,
            ),
            title: Text(m.productName),
            subtitle: Text(
              '${formatDayHeaderEs(m.createdAt.toLocal())} · ${formatTimeEs(m.createdAt.toLocal())}'
              '${m.note != null ? ' · ${m.note}' : ''}'
              '${m.userEmail != null ? ' · ${m.userEmail}' : ''}',
            ),
            trailing: Text(
              '${m.isIn ? '+' : '-'}${m.quantity.toStringAsFixed(0)}',
              style: TextStyle(color: m.isIn ? Colors.green : Colors.red, fontWeight: FontWeight.bold),
            ),
          );
        },
      ),
    );
  }
}
