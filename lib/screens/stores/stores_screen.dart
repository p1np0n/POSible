import 'package:flutter/material.dart';

import '../../models/store.dart';
import '../../services/store_repository.dart';

/// Solo la ve el administrador principal (ver StoreProvider.isSuperAdmin):
/// lista todas las tiendas y permite activarles Reportes, Clientes y
/// Empleados (las tiendas nuevas empiezan sin esas tres).
class StoresScreen extends StatefulWidget {
  const StoresScreen({super.key});

  @override
  State<StoresScreen> createState() => _StoresScreenState();
}

class _StoresScreenState extends State<StoresScreen> {
  final StoreRepository _repository = StoreRepository();
  List<Store> _stores = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final stores = await _repository.getAllStores();
    setState(() {
      _stores = stores;
      _loading = false;
    });
  }

  Future<void> _toggleFeature(Store store, {bool? reports, bool? customers, bool? employees}) async {
    await _repository.updateFeatures(
      store.id,
      featureReports: reports,
      featureCustomers: customers,
      featureEmployees: employees,
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_stores.isEmpty) return const Center(child: Text('No hay tiendas todavía'));

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _stores.length,
        itemBuilder: (context, index) {
          final store = _stores[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(store.name, style: Theme.of(context).textTheme.titleMedium),
                      ),
                      Text('Código: ${store.storeCode}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                  const Divider(),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('Reportes'),
                    value: store.featureReports,
                    onChanged: (value) => _toggleFeature(store, reports: value),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('Clientes'),
                    value: store.featureCustomers,
                    onChanged: (value) => _toggleFeature(store, customers: value),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('Empleados'),
                    value: store.featureEmployees,
                    onChanged: (value) => _toggleFeature(store, employees: value),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
