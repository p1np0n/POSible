import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'info_admin_inventory_screen.dart';
import 'info_admin_products_screen.dart';
import 'info_admin_reports_screen.dart';

/// Pantalla principal de "Info Admin": una versión chica de POSible, solo
/// para consultar (nada de vender ni editar), con 3 secciones elegidas con
/// un menú abajo — Inventario (movimientos de stock), Reportes (ventas de
/// hoy) y Lista de artículos. Usa el mismo login que la app completa (ver
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
    InfoAdminInventoryScreen(),
    InfoAdminReportsScreen(),
    InfoAdminProductsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_index]),
        actions: [
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
