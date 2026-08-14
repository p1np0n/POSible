import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/app_config.dart';
import '../customers/customer_list_screen.dart';
import '../employees/employees_screen.dart';
import '../inventory/categories_screen.dart';
import '../inventory/discounts_screen.dart';
import '../inventory/modifiers_screen.dart';
import '../inventory/product_list_screen.dart';
import '../pos/pos_screen.dart';
import '../pos/turno_screen.dart';
import '../receipts/receipts_screen.dart';
import '../reports/reports_screen.dart';
import '../settings/settings_screen.dart';

/// Punto de corte para mostrar el menú lateral fijo (pantalla ancha, como un
/// computador) en vez del menú deslizable (celular).
const double _wideLayoutBreakpoint = 900;

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  bool _articulosExpanded = true;

  // El APK (celular) se queda con lo esencial para atender en el mostrador.
  // El panel web además tiene la administración completa (back office).
  //
  // Solo se muestra _screens[_index] (no IndexedStack), así cada pantalla
  // vuelve a cargar sus datos al seleccionarla — si agregas un producto en
  // Artículos y vuelves a Ventas, ya lo ves sin tener que refrescar a mano.
  late final List<Widget> _screens = [
    const PosScreen(),
    const ReceiptsScreen(),
    const TurnoScreen(),
    const ReportsScreen(),
    const CustomerListScreen(),
    const SettingsScreen(),
    if (kIsWeb) ...[
      const ProductListScreen(),
      const CategoriesScreen(),
      const ModifiersScreen(),
      const DiscountsScreen(),
      const EmployeesScreen(),
    ],
  ];

  late final List<String> _titles = [
    'Ventas',
    'Recibos',
    'Turno',
    'Reportes',
    'Clientes',
    'Configuración',
    if (kIsWeb) ...[
      'Lista de artículos',
      'Categorías',
      'Modificadores',
      'Descuentos',
      'Empleados',
    ],
  ];

  static const _posIndex = 0;
  static const _receiptsIndex = 1;
  static const _turnoIndex = 2;
  static const _reportsIndex = 3;
  static const _customersIndex = 4;
  static const _settingsIndex = 5;
  static const _productsIndex = 6;
  static const _categoriesIndex = 7;
  static const _modifiersIndex = 8;
  static const _discountsIndex = 9;
  static const _employeesIndex = 10;

  void _selectIndex(int index, {required bool closeDrawer}) {
    if (closeDrawer) Navigator.of(context).maybePop();
    setState(() => _index = index);
  }

  Widget _buildNav(BuildContext context, {required bool closeDrawer}) {
    final email = Supabase.instance.client.auth.currentUser?.email ?? '';

    return ListView(
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
          selected: _index == _posIndex,
          onTap: () => _selectIndex(_posIndex, closeDrawer: closeDrawer),
        ),
        ListTile(
          leading: const Icon(Icons.receipt_long),
          title: const Text('Recibos'),
          selected: _index == _receiptsIndex,
          onTap: () => _selectIndex(_receiptsIndex, closeDrawer: closeDrawer),
        ),
        ListTile(
          leading: const Icon(Icons.schedule),
          title: const Text('Turno'),
          selected: _index == _turnoIndex,
          onTap: () => _selectIndex(_turnoIndex, closeDrawer: closeDrawer),
        ),
        if (kIsWeb)
          ExpansionTile(
            leading: const Icon(Icons.inventory_2),
            title: const Text('Artículos'),
            initiallyExpanded: _articulosExpanded,
            onExpansionChanged: (value) => setState(() => _articulosExpanded = value),
            children: [
              ListTile(
                contentPadding: const EdgeInsets.only(left: 32, right: 16),
                title: const Text('Lista de artículos'),
                selected: _index == _productsIndex,
                onTap: () => _selectIndex(_productsIndex, closeDrawer: closeDrawer),
              ),
              ListTile(
                contentPadding: const EdgeInsets.only(left: 32, right: 16),
                title: const Text('Categorías'),
                selected: _index == _categoriesIndex,
                onTap: () => _selectIndex(_categoriesIndex, closeDrawer: closeDrawer),
              ),
              ListTile(
                contentPadding: const EdgeInsets.only(left: 32, right: 16),
                title: const Text('Modificadores'),
                selected: _index == _modifiersIndex,
                onTap: () => _selectIndex(_modifiersIndex, closeDrawer: closeDrawer),
              ),
              ListTile(
                contentPadding: const EdgeInsets.only(left: 32, right: 16),
                title: const Text('Descuentos'),
                selected: _index == _discountsIndex,
                onTap: () => _selectIndex(_discountsIndex, closeDrawer: closeDrawer),
              ),
            ],
          ),
        ListTile(
          leading: const Icon(Icons.bar_chart),
          title: const Text('Reportes'),
          selected: _index == _reportsIndex,
          onTap: () => _selectIndex(_reportsIndex, closeDrawer: closeDrawer),
        ),
        ListTile(
          leading: const Icon(Icons.people),
          title: const Text('Clientes'),
          selected: _index == _customersIndex,
          onTap: () => _selectIndex(_customersIndex, closeDrawer: closeDrawer),
        ),
        if (kIsWeb) ...[
          const Divider(),
          ListTile(
            leading: const Icon(Icons.badge_outlined),
            title: const Text('Empleados'),
            selected: _index == _employeesIndex,
            onTap: () => _selectIndex(_employeesIndex, closeDrawer: closeDrawer),
          ),
        ],
        ListTile(
          leading: const Icon(Icons.settings),
          title: const Text('Configuración'),
          selected: _index == _settingsIndex,
          onTap: () => _selectIndex(_settingsIndex, closeDrawer: closeDrawer),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= _wideLayoutBreakpoint;

    if (isWide) {
      return Scaffold(
        body: Row(
          children: [
            SizedBox(
              width: 280,
              child: Material(elevation: 1, child: _buildNav(context, closeDrawer: false)),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: Column(
                children: [
                  AppBar(
                    title: Text(_titles[_index]),
                    automaticallyImplyLeading: false,
                  ),
                  Expanded(child: _screens[_index]),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(_titles[_index])),
      drawer: Drawer(child: _buildNav(context, closeDrawer: true)),
      body: _screens[_index],
    );
  }
}
