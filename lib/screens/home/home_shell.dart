import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../customers/customer_list_screen.dart';
import '../inventory/product_list_screen.dart';
import '../pos/pos_screen.dart';
import '../reports/reports_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  final _screens = const [
    PosScreen(),
    ProductListScreen(),
    ReportsScreen(),
    CustomerListScreen(),
  ];

  final _titles = const ['Ventas', 'Inventario', 'Reportes', 'Clientes'];

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
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.point_of_sale), label: 'Ventas'),
          NavigationDestination(icon: Icon(Icons.inventory_2), label: 'Inventario'),
          NavigationDestination(icon: Icon(Icons.bar_chart), label: 'Reportes'),
          NavigationDestination(icon: Icon(Icons.people), label: 'Clientes'),
        ],
      ),
    );
  }
}
