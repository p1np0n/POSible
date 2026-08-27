import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../inventory/product_list_screen.dart';
import '../inventory/stock_movements_screen.dart';
import '../reports/reports_screen.dart';
import 'info_admin_reports_screen.dart';

/// Pantalla principal de "Info Admin": una versión chica de POSible (sin
/// Ventas ni Turno/Reloj), con 3 secciones elegidas con un menú abajo —
/// Inventario y Lista de artículos son las mismas pantallas completas del
/// panel (crear, editar, escanear, todo igual); Reportes muestra por
/// defecto una versión propia enfocada en el día de hoy, con un ícono para
/// abrir el reporte completo (mismo de la web: rangos de fecha, gráfico,
/// desgloses). Usa el mismo login que la app completa (ver
/// lib/main_info_admin.dart), así que cualquier empleado con cuenta en
/// POSible puede entrar acá también.
class InfoAdminShell extends StatefulWidget {
  const InfoAdminShell({super.key});

  @override
  State<InfoAdminShell> createState() => _InfoAdminShellState();
}

class _InfoAdminShellState extends State<InfoAdminShell> {
  int _index = 0;

  static const _titles = ['Inventario', 'Reportes', 'Lista de artículos'];
  static const _screens = [
    StockMovementsScreen(),
    InfoAdminReportsScreen(),
    ProductListScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_index]),
        actions: [
          if (_index == 1)
            IconButton(
              icon: const Icon(Icons.query_stats),
              tooltip: 'Ver reporte completo',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const _FullReportsScreen()),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: () => Supabase.instance.client.auth.signOut(),
          ),
        ],
      ),
      body: _screens[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.inventory_2_outlined), label: 'Inventario'),
          NavigationDestination(icon: Icon(Icons.bar_chart_outlined), label: 'Reportes'),
          NavigationDestination(icon: Icon(Icons.list_alt_outlined), label: 'Artículos'),
        ],
      ),
    );
  }
}

/// Mismo reporte completo del panel web (rangos de fecha, gráfico, desglose
/// por categoría/empleado/modificador), como pantalla aparte a la que se
/// llega desde el ícono en Reportes — la vista rápida de Info Admin se deja
/// como está por defecto, para no perder ese vistazo del día a día.
class _FullReportsScreen extends StatelessWidget {
  const _FullReportsScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reporte completo')),
      body: const ReportsScreen(),
    );
  }
}
