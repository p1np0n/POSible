import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/employee_profile.dart';
import '../../providers/app_preferences_provider.dart';
import '../../services/profile_repository.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_state.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/pin_entry_dialog.dart';
import '../../widgets/pin_pad.dart' show pinLength;

/// Permisos que un administrador le puede activar a un cajero — deben
/// coincidir exactamente con GRANTABLE_PERMISSIONS en la Edge Function
/// "manage-employee". Configuración y Empleados nunca aparecen acá: esas
/// pantallas quedan siempre exclusivas del rol 'admin'.
const _grantablePermissions = <String, String>{
  'manage_products': 'Editar artículos (Lista, Categorías, Modificadores, Descuentos)',
  'view_reports': 'Ver Reportes',
  'manage_customers': 'Gestionar Clientes',
};

class EmployeesScreen extends StatefulWidget {
  const EmployeesScreen({super.key});

  @override
  State<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends State<EmployeesScreen> {
  final ProfileRepository _repository = ProfileRepository();
  List<EmployeeProfile> _profiles = [];
  EmployeeProfile? _myProfile;
  bool _loading = true;
  String _search = '';
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
      final results = await Future.wait([_repository.getAll(), _repository.getMyProfile()]);
      if (!mounted) return;
      setState(() {
        _profiles = results[0] as List<EmployeeProfile>;
        _myProfile = results[1] as EmployeeProfile?;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudieron cargar los empleados';
        _loading = false;
      });
    }
  }

  List<EmployeeProfile> get _filtered =>
      _profiles.where((p) => _search.isEmpty || p.label.toLowerCase().contains(_search.toLowerCase())).toList();

  Future<void> _toggleApproved(EmployeeProfile profile) async {
    await _repository.setApproved(profile.id, !profile.approved);
    _load();
  }

  Future<void> _remove(EmployeeProfile profile) async {
    final myId = Supabase.instance.client.auth.currentUser?.id;
    if (profile.id == myId) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('No puedes quitarte a ti mismo')));
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Quitar acceso'),
        content: Text('¿Seguro que quieres quitarle el acceso a ${profile.label}?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Quitar')),
        ],
      ),
    );
    if (confirmed != true) return;
    await _repository.remove(profile.id);
    _load();
  }

  Future<void> _createEmployee() async {
    final result = await showDialog<_NewEmployee>(
      context: context,
      builder: (_) => const _EmployeeFormDialog(),
    );
    if (result == null) return;
    final error = await _repository.createEmployee(displayName: result.displayName, pin: result.pin);
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $error')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cajero creado')));
      _load();
    }
  }

  Future<void> _resetPin(EmployeeProfile profile) async {
    final pin = await showPinEntryDialog(context, title: 'Nuevo PIN', subtitle: profile.label);
    if (pin == null || !mounted) return;
    final error = await _repository.setPin(userId: profile.id, pin: pin);
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $error')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PIN actualizado')));
    }
  }

  Future<void> _editPermissions(EmployeeProfile profile) async {
    final result = await showDialog<List<String>>(
      context: context,
      builder: (_) => _PermissionsDialog(profile: profile),
    );
    if (result == null) return;
    final error = await _repository.setPermissions(userId: profile.id, permissions: result);
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $error')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Permisos actualizados')));
      _load();
    }
  }

  /// Agrega a este cajero (o al administrador) al selector "¿Quién eres?"
  /// de este mismo celular/tablet, para que pueda entrar con su PIN sin
  /// tener que escribir un correo que ni siquiera conoce (el de un cajero
  /// es uno interno, generado solo).
  Future<void> _addToThisDevice(EmployeeProfile profile) async {
    await context.read<AppPreferencesProvider>().rememberEmail(profile.email, displayName: profile.label);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${profile.label} ya puede elegirse en "¿Quién eres?" en este dispositivo')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final myId = Supabase.instance.client.auth.currentUser?.id;

    if (!_loading && _error == null && _myProfile != null && !_myProfile!.isAdmin) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Solo el administrador de la tienda puede gestionar empleados.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'Buscar empleado',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (value) => setState(() => _search = value),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _createEmployee,
                icon: const Icon(Icons.person_add_alt),
                label: const Text('Nuevo cajero'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Un cajero nuevo solo necesita un nombre y un PIN de 4 dígitos — no un correo. '
            'Con "Permisos" le puedes activar acceso extra (Artículos, Reportes, Clientes); '
            'Configuración y Empleados siguen siempre exclusivos del administrador.',
            style: TextStyle(color: const Color(0xFF616161)),
          ),
          const SizedBox(height: 16),
          if (_loading)
            const LoadingIndicator()
          else if (_error != null)
            ErrorState(message: _error!, onRetry: _load)
          else if (_filtered.isEmpty)
            const EmptyState(message: 'No hay empleados todavía', icon: Icons.badge_outlined)
          else
            ..._filtered.map((profile) => Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListTile(
                          title: Text(profile.label),
                          subtitle: Text([
                            profile.isAdmin ? 'Administrador' : 'Cajero',
                            if (!profile.approved) 'Pendiente de aprobación',
                          ].join(' · ')),
                          leading: Icon(
                            profile.approved ? Icons.check_circle : Icons.hourglass_top,
                            color: profile.approved ? Colors.green : Colors.orange,
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!kIsWeb)
                                IconButton(
                                  icon: const Icon(Icons.add_to_home_screen),
                                  tooltip: 'Agregar a este dispositivo',
                                  onPressed: () => _addToThisDevice(profile),
                                ),
                              IconButton(
                                icon: const Icon(Icons.password_outlined),
                                tooltip: 'Cambiar PIN',
                                onPressed: () => _resetPin(profile),
                              ),
                              Switch(value: profile.approved, onChanged: (_) => _toggleApproved(profile)),
                              if (profile.id != myId)
                                IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  tooltip: 'Quitar',
                                  onPressed: () => _remove(profile),
                                ),
                            ],
                          ),
                        ),
                        if (!profile.isAdmin)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: OutlinedButton.icon(
                                onPressed: () => _editPermissions(profile),
                                icon: const Icon(Icons.tune, size: 18),
                                label: Text(profile.permissions.isEmpty
                                    ? 'Sin permisos extra'
                                    : '${profile.permissions.length} permiso(s) extra'),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                )),
        ],
      ),
    );
  }
}

class _NewEmployee {
  final String displayName;
  final String pin;

  _NewEmployee({required this.displayName, required this.pin});
}

class _EmployeeFormDialog extends StatefulWidget {
  const _EmployeeFormDialog();

  @override
  State<_EmployeeFormDialog> createState() => _EmployeeFormDialogState();
}

class _EmployeeFormDialogState extends State<_EmployeeFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String _pin = '';

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickPin() async {
    final pin = await showPinEntryDialog(context, title: 'PIN del cajero (4 dígitos)');
    if (pin != null && mounted) setState(() => _pin = pin);
  }

  void _confirm() {
    if (!_formKey.currentState!.validate()) return;
    if (_pin.length != pinLength) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Elige un PIN de $pinLength dígitos')));
      return;
    }
    Navigator.of(context).pop(_NewEmployee(displayName: _nameController.text.trim(), pin: _pin));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nuevo cajero'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Nombre', border: OutlineInputBorder()),
              validator: (value) => (value == null || value.trim().isEmpty) ? 'Ingresa un nombre' : null,
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickPin,
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'PIN', border: OutlineInputBorder()),
                child: Text(_pin.isEmpty ? 'Toca para elegir un PIN de $pinLength dígitos' : '•' * _pin.length),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton(onPressed: _confirm, child: const Text('Crear')),
      ],
    );
  }
}

class _PermissionsDialog extends StatefulWidget {
  final EmployeeProfile profile;

  const _PermissionsDialog({required this.profile});

  @override
  State<_PermissionsDialog> createState() => _PermissionsDialogState();
}

class _PermissionsDialogState extends State<_PermissionsDialog> {
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.profile.permissions.toSet();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Permisos de ${widget.profile.label}'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: _grantablePermissions.entries
              .map((entry) => CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(entry.value),
                    value: _selected.contains(entry.key),
                    onChanged: (value) => setState(() {
                      if (value == true) {
                        _selected.add(entry.key);
                      } else {
                        _selected.remove(entry.key);
                      }
                    }),
                  ))
              .toList(),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_selected.toList()),
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
