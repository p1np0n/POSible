import 'package:flutter/material.dart';

import '../../models/employee_profile.dart';
import '../../models/store.dart';
import '../../services/profile_repository.dart';
import '../../services/store_repository.dart';

/// Solo la ve el administrador principal (ver StoreProvider.isSuperAdmin):
/// lista todas las tiendas, permite activarles Reportes, Clientes y
/// Empleados (las tiendas nuevas empiezan sin esas tres), y restablecer la
/// contraseña del dueño de cada tienda o el PIN de cualquiera de sus
/// empleados si la olvidaron.
class StoresScreen extends StatefulWidget {
  const StoresScreen({super.key});

  @override
  State<StoresScreen> createState() => _StoresScreenState();
}

class _StoresScreenState extends State<StoresScreen> {
  final StoreRepository _repository = StoreRepository();
  final ProfileRepository _profileRepository = ProfileRepository();
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

  Future<void> _resetOwnerPassword(Store store) async {
    if (store.ownerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Esta tienda todavía no tiene administrador asignado')),
      );
      return;
    }
    final newPassword = await showDialog<String>(
      context: context,
      builder: (_) => _ResetPinDialog(
        title: 'Restablecer contraseña — ${store.name}',
        subtitle: store.ownerEmail != null ? 'Cuenta: ${store.ownerEmail}' : 'Administrador de esta tienda',
      ),
    );
    if (newPassword == null || !mounted) return;
    final error = await _profileRepository.resetPin(userId: store.ownerId!, newPin: newPassword);
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $error')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Contraseña de ${store.ownerEmail ?? store.name} actualizada')),
      );
    }
  }

  void _showEmployees(Store store) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _StoreEmployeesSheet(store: store, profileRepository: _profileRepository),
    );
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
                  const SizedBox(height: 2),
                  Text(
                    store.ownerEmail != null ? 'Administrador: ${store.ownerEmail}' : 'Sin administrador asignado',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
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
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: store.ownerId == null ? null : () => _resetOwnerPassword(store),
                        icon: const Icon(Icons.password_outlined),
                        label: const Text('Restablecer contraseña del administrador'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _showEmployees(store),
                        icon: const Icon(Icons.badge_outlined),
                        label: const Text('Ver empleados'),
                      ),
                    ],
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

/// Pide una contraseña/PIN nueva (dos veces, para confirmar) y la devuelve
/// al cerrar. Genérico: sirve tanto para el administrador de una tienda
/// como para cualquiera de sus empleados.
class _ResetPinDialog extends StatefulWidget {
  final String title;
  final String subtitle;

  const _ResetPinDialog({required this.title, required this.subtitle});

  @override
  State<_ResetPinDialog> createState() => _ResetPinDialogState();
}

class _ResetPinDialogState extends State<_ResetPinDialog> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _confirm() {
    if (!_formKey.currentState!.validate()) return;
    if (_passwordController.text != _confirmController.text) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Las contraseñas no coinciden')));
      return;
    }
    Navigator.of(context).pop(_passwordController.text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.subtitle, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),
            TextFormField(
              controller: _passwordController,
              autofocus: true,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Contraseña nueva', border: OutlineInputBorder()),
              validator: (value) => (value == null || value.length < 4) ? 'Mínimo 4 caracteres' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirmController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Repite la contraseña', border: OutlineInputBorder()),
              validator: (value) => (value == null || value.length < 4) ? 'Mínimo 4 caracteres' : null,
              onFieldSubmitted: (_) => _confirm(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton(onPressed: _confirm, child: const Text('Guardar')),
      ],
    );
  }
}

/// Bottom sheet con los empleados de una tienda (administrador principal
/// solamente) y un botón para restablecer el PIN de cualquiera de ellos —
/// no permite aprobar ni quitar empleados de otra tienda, eso sigue siendo
/// solo del dueño de esa tienda.
class _StoreEmployeesSheet extends StatefulWidget {
  final Store store;
  final ProfileRepository profileRepository;

  const _StoreEmployeesSheet({required this.store, required this.profileRepository});

  @override
  State<_StoreEmployeesSheet> createState() => _StoreEmployeesSheetState();
}

class _StoreEmployeesSheetState extends State<_StoreEmployeesSheet> {
  List<EmployeeProfile>? _employees;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final employees = await widget.profileRepository.getForStore(widget.store.id);
      if (mounted) setState(() => _employees = employees);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _resetPin(EmployeeProfile profile) async {
    final newPin = await showDialog<String>(
      context: context,
      builder: (_) => _ResetPinDialog(
        title: 'Restablecer PIN',
        subtitle: profile.email.isEmpty ? '(sin correo)' : profile.email,
      ),
    );
    if (newPin == null || !mounted) return;
    final error = await widget.profileRepository.resetPin(userId: profile.id, newPin: newPin);
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $error')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PIN de ${profile.email.isEmpty ? "este empleado" : profile.email} actualizado')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Empleados de ${widget.store.name}', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              Expanded(
                child: _error != null
                    ? Center(child: Text('Error: $_error'))
                    : _employees == null
                        ? const Center(child: CircularProgressIndicator())
                        : _employees!.isEmpty
                            ? const Center(child: Text('Esta tienda todavía no tiene empleados'))
                            : ListView.builder(
                                controller: scrollController,
                                itemCount: _employees!.length,
                                itemBuilder: (context, index) {
                                  final profile = _employees![index];
                                  return ListTile(
                                    leading: Icon(
                                      profile.approved ? Icons.check_circle : Icons.hourglass_top,
                                      color: profile.approved ? Colors.green : Colors.orange,
                                    ),
                                    title: Text(profile.email.isEmpty ? '(sin correo)' : profile.email),
                                    subtitle: Text(profile.approved ? 'Aprobado' : 'Pendiente de aprobación'),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.password_outlined),
                                      tooltip: 'Restablecer PIN',
                                      onPressed: () => _resetPin(profile),
                                    ),
                                  );
                                },
                              ),
              ),
            ],
          ),
        );
      },
    );
  }
}
