import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/app_config.dart';
import '../../providers/store_provider.dart';
import '../customers/customer_list_screen.dart';
import '../employees/employees_screen.dart';
import '../employees/time_clock_screen.dart';
import '../inventory/categories_screen.dart';
import '../inventory/discounts_screen.dart';
import '../inventory/inventory_screen.dart';
import '../inventory/modifiers_screen.dart';
import '../inventory/product_list_screen.dart';
import '../pos/pos_screen.dart';
import '../pos/turno_screen.dart';
import '../receipts/receipts_screen.dart';
import '../reports/reports_screen.dart';
import '../settings/settings_screen.dart';
import '../stores/stores_screen.dart';

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
  bool _storeLoadRequested = false;

  void _selectIndex(int index, {required bool closeDrawer}) {
    if (closeDrawer) Navigator.of(context).maybePop();
    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<StoreProvider>();
    if (!store.loaded) {
      if (!_storeLoadRequested) {
        _storeLoadRequested = true;
        WidgetsBinding.instance.addPostFrameCallback((_) => context.read<StoreProvider>().load());
      }
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // El APK (celular) se queda con lo esencial para atender en el mostrador.
    // El panel web además tiene la administración completa (back office).
    // Reportes, Clientes y Empleados solo se muestran si la tienda los tiene
    // activados (las tiendas nuevas empiezan sin esos tres).
    //
    // Solo se muestra _screens[index] (no IndexedStack), así cada pantalla
    // vuelve a cargar sus datos al seleccionarla.
    final screens = <Widget>[
      const PosScreen(),
      const ReceiptsScreen(),
      const TurnoScreen(),
      const TimeClockScreen(),
      if (store.showReports) const ReportsScreen(),
      if (store.showCustomers) const CustomerListScreen(),
      const SettingsScreen(),
      if (kIsWeb) ...[
        const ProductListScreen(),
        const CategoriesScreen(),
        const ModifiersScreen(),
        const DiscountsScreen(),
        if (store.showEmployees) const EmployeesScreen(),
        const InventoryScreen(),
        if (store.isSuperAdmin) const StoresScreen(),
      ],
    ];

    final titles = <String>[
      'Ventas',
      'Recibos',
      'Turno',
      'Reloj',
      if (store.showReports) 'Reportes',
      if (store.showCustomers) 'Clientes',
      'Configuración',
      if (kIsWeb) ...[
        'Lista de artículos',
        'Categorías',
        'Modificadores',
        'Descuentos',
        if (store.showEmployees) 'Empleados',
        'Inventario',
        if (store.isSuperAdmin) 'Tiendas',
      ],
    ];

    final index = _index >= screens.length ? 0 : _index;

    // Mismo orden en que se armaron screens/titles arriba, para calcular en
    // qué posición quedó cada pantalla según lo que esta tienda tiene
    // activado.
    var next = 4;
    final reportsIndex = store.showReports ? next++ : -1;
    final customersIndex = store.showCustomers ? next++ : -1;
    final settingsIndex = next++;
    final productsIndex = kIsWeb ? next++ : -1;
    final categoriesIndex = kIsWeb ? next++ : -1;
    final modifiersIndex = kIsWeb ? next++ : -1;
    final discountsIndex = kIsWeb ? next++ : -1;
    final employeesIndex = (kIsWeb && store.showEmployees) ? next++ : -1;
    final inventoryIndex = kIsWeb ? next++ : -1;
    final storesIndex = (kIsWeb && store.isSuperAdmin) ? next++ : -1;

    final email = Supabase.instance.client.auth.currentUser?.email ?? '';

    Widget buildNav(BuildContext context, {required bool closeDrawer}) {
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
                Text(store.myStore?.name ?? email, style: const TextStyle(color: Colors.white70, fontSize: 13)),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.point_of_sale),
            title: const Text('Ventas'),
            selected: index == 0,
            onTap: () => _selectIndex(0, closeDrawer: closeDrawer),
          ),
          ListTile(
            leading: const Icon(Icons.receipt_long),
            title: const Text('Recibos'),
            selected: index == 1,
            onTap: () => _selectIndex(1, closeDrawer: closeDrawer),
          ),
          ListTile(
            leading: const Icon(Icons.schedule),
            title: const Text('Turno'),
            selected: index == 2,
            onTap: () => _selectIndex(2, closeDrawer: closeDrawer),
          ),
          ListTile(
            leading: const Icon(Icons.access_time),
            title: const Text('Reloj'),
            subtitle: const Text('Marcar entrada y salida', style: TextStyle(fontSize: 11)),
            selected: index == 3,
            onTap: () => _selectIndex(3, closeDrawer: closeDrawer),
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
                  selected: index == productsIndex,
                  onTap: () => _selectIndex(productsIndex, closeDrawer: closeDrawer),
                ),
                ListTile(
                  contentPadding: const EdgeInsets.only(left: 32, right: 16),
                  title: const Text('Categorías'),
                  selected: index == categoriesIndex,
                  onTap: () => _selectIndex(categoriesIndex, closeDrawer: closeDrawer),
                ),
                ListTile(
                  contentPadding: const EdgeInsets.only(left: 32, right: 16),
                  title: const Text('Modificadores'),
                  selected: index == modifiersIndex,
                  onTap: () => _selectIndex(modifiersIndex, closeDrawer: closeDrawer),
                ),
                ListTile(
                  contentPadding: const EdgeInsets.only(left: 32, right: 16),
                  title: const Text('Descuentos'),
                  selected: index == discountsIndex,
                  onTap: () => _selectIndex(discountsIndex, closeDrawer: closeDrawer),
                ),
              ],
            ),
          if (kIsWeb)
            ListTile(
              leading: const Icon(Icons.public),
              title: const Text('Inventario'),
              subtitle: const Text('Catálogo de todas las tiendas', style: TextStyle(fontSize: 11)),
              selected: index == inventoryIndex,
              onTap: () => _selectIndex(inventoryIndex, closeDrawer: closeDrawer),
            ),
          if (store.showReports)
            ListTile(
              leading: const Icon(Icons.bar_chart),
              title: const Text('Reportes'),
              selected: index == reportsIndex,
              onTap: () => _selectIndex(reportsIndex, closeDrawer: closeDrawer),
            ),
          if (store.showCustomers)
            ListTile(
              leading: const Icon(Icons.people),
              title: const Text('Clientes'),
              selected: index == customersIndex,
              onTap: () => _selectIndex(customersIndex, closeDrawer: closeDrawer),
            ),
          if (kIsWeb && store.showEmployees) ...[
            const Divider(),
            ListTile(
              leading: const Icon(Icons.badge_outlined),
              title: const Text('Empleados'),
              selected: index == employeesIndex,
              onTap: () => _selectIndex(employeesIndex, closeDrawer: closeDrawer),
            ),
          ],
          if (kIsWeb && store.isSuperAdmin) ...[
            const Divider(),
            ListTile(
              leading: const Icon(Icons.storefront_outlined),
              title: const Text('Tiendas'),
              subtitle: const Text('Administrar todas las tiendas', style: TextStyle(fontSize: 11)),
              selected: index == storesIndex,
              onTap: () => _selectIndex(storesIndex, closeDrawer: closeDrawer),
            ),
          ],
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Configuración'),
            selected: index == settingsIndex,
            onTap: () => _selectIndex(settingsIndex, closeDrawer: closeDrawer),
          ),
        ],
      );
    }

    final isWide = MediaQuery.of(context).size.width >= _wideLayoutBreakpoint;

    if (isWide) {
      return Scaffold(
        body: Row(
          children: [
            SizedBox(
              width: 280,
              child: Material(elevation: 1, child: buildNav(context, closeDrawer: false)),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: Column(
                children: [
                  AppBar(
                    title: Text(titles[index]),
                    automaticallyImplyLeading: false,
                  ),
                  Expanded(child: screens[index]),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(titles[index])),
      drawer: Drawer(child: buildNav(context, closeDrawer: true)),
      body: screens[index],
    );
  }
}
