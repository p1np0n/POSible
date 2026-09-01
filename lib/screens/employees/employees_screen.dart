import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/employee_profile.dart';
import '../../services/profile_repository.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_state.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/pin_entry_dialog.dart';
import '../../widgets/pin_pad.dart' show pinLength;

class EmployeesScreen extends StatefulWidget {
  const EmployeesScreen({super.key});

  @override
  State<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends State<EmployeesScreen> {
  final ProfileRepository _repository = ProfileRepository();
  List<EmployeeProfile> _profiles = [];
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
      final profiles = await _repository.getAll();
      if (!mounted) return;
      setState(() {
        _profiles = profiles;
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

  List<EmployeeProfile> get _filtered => _profiles
      .where((p) => _search.isEmpty || p.email.toLowerCase().contains(_search.toLowerCase()))
      .toList();

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
        content: Text('¿Seguro que quieres quitarle el acceso a ${profile.email}?'),
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
    final result = await showDialog<_EmployeeCredentials>(
      context: context,
      builder: (_) => const _EmployeeFormDialog(),
    );
    if (result == null) return;
    final error = await _repository.createEmployee(email: result.email, password: result.pin);
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $error')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Empleado creado')));
      _load();
    }
  }

  Future<void> _resetPin(EmployeeProfile profile) async {
    final pin = await showPinEntryDialog(context, title: 'Restablecer PIN', subtitle: profile.email);
    if (pin == null || !mounted) return;
    final error = await _repository.resetPin(userId: profile.id, newPin: pin);
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $error')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PIN actualizado')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final myId = Supabase.instance.client.auth.currentUser?.id;

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
                label: const Text('Nuevo empleado'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Los empleados que se registran solos desde la pantalla de inicio de sesión '
            'aparecen aquí sin aprobar hasta que los apruebes. También puedes crearlos tú '
            'directamente con "Nuevo empleado" — quedan aprobados de inmediato.',
            style: TextStyle(color: Colors.grey.shade700),
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
                  child: ListTile(
                    title: Text(profile.email.isEmpty ? '(sin correo)' : profile.email),
                    subtitle: Text(profile.approved ? 'Aprobado' : 'Pendiente de aprobación'),
                    leading: Icon(
                      profile.approved ? Icons.check_circle : Icons.hourglass_top,
                      color: profile.approved ? Colors.green : Colors.orange,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.password_outlined),
                          tooltip: 'Restablecer PIN',
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
                )),
        ],
      ),
    );
  }
}

class _EmployeeCredentials {
  final String email;
  final String pin;

  _EmployeeCredentials({required this.email, required this.pin});
}

class _EmployeeFormDialog extends StatefulWidget {
  const _EmployeeFormDialog();

  @override
  State<_EmployeeFormDialog> createState() => _EmployeeFormDialogState();
}

class _EmployeeFormDialogState extends State<_EmployeeFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  String _pin = '';

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _pickPin() async {
    final pin = await showPinEntryDialog(context, title: 'PIN del empleado');
    if (pin != null && mounted) setState(() => _pin = pin);
  }

  void _confirm() {
    if (!_formKey.currentState!.validate()) return;
    if (_pin.length != pinLength) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Elige un PIN de $pinLength dígitos')));
      return;
    }
    Navigator.of(context).pop(_EmployeeCredentials(email: _emailController.text.trim(), pin: _pin));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nuevo empleado'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Correo', border: OutlineInputBorder()),
              validator: (value) => (value == null || value.trim().isEmpty) ? 'Ingresa un correo' : null,
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
