import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/app_config.dart';
import '../customers/customer_list_screen.dart';
import '../employees/employees_screen.dart';
import '../inventory/product_list_screen.dart';
import '../pos/pos_screen.dart';
import '../pos/turno_screen.dart';
import '../receipts/receipts_screen.dart';
import '../reports/reports_screen.dart';
import '../settings/settings_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  final _screens = const [
    PosScreen(),
    ReceiptsScreen(),
    TurnoScreen(),
    ProductListScreen(),
    ReportsScreen(),
    CustomerListScreen(),
    EmployeesScreen(),
    SettingsScreen(),
  ];

  final _titles = const [
    'Ventas',
    'Recibos',
    'Turno',
    'Artículos',
    'Reportes',
    'Clientes',
    'Empleados',
    'Configuración',
  ];

  void _selectIndex(int index) {
    Navigator.of(context).pop();
    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    final email = Supabase.instance.client.auth.currentUser?.email ?? '';

    return Scaffold(
      appBar: AppBar(title: Text(_titles[_index])),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Icon(Icons.point_of_sale, color: Colors.white, size: 32),
                  const SizedBox(height: 8),
                  Text(AppConfig.appName, style: const TextStyle(color: Colors.white, fontSize: 20)),
                  Text(email, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.point_of_sale),
              title: const Text('Ventas'),
              selected: _index == 0,
              onTap: () => _selectIndex(0),
            ),
            ListTile(
              leading: const Icon(Icons.receipt_long),
              title: const Text('Recibos'),
              selected: _index == 1,
              onTap: () => _selectIndex(1),
            ),
            ListTile(
              leading: const Icon(Icons.schedule),
              title: const Text('Turno'),
              selected: _index == 2,
              onTap: () => _selectIndex(2),
            ),
            ListTile(
              leading: const Icon(Icons.inventory_2),
              title: const Text('Artículos'),
              selected: _index == 3,
              onTap: () => _selectIndex(3),
            ),
            ListTile(
              leading: const Icon(Icons.bar_chart),
              title: const Text('Reportes'),
              selected: _index == 4,
              onTap: () => _selectIndex(4),
            ),
            ListTile(
              leading: const Icon(Icons.people),
              title: const Text('Clientes'),
              selected: _index == 5,
              onTap: () => _selectIndex(5),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.badge_outlined),
              title: const Text('Empleados'),
              selected: _index == 6,
              onTap: () => _selectIndex(6),
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Configuración'),
              selected: _index == 7,
              onTap: () => _selectIndex(7),
            ),
          ],
        ),
      ),
      body: IndexedStack(index: _index, children: _screens),
    );
  }
}
