import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/employee_profile.dart';
import '../../services/profile_repository.dart';

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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final profiles = await _repository.getAll();
    setState(() {
      _profiles = profiles;
      _loading = false;
    });
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
    final result = await showDialog<_EmployeeCredentials>(
      context: context,
      builder: (_) => _EmployeeFormDialog(fixedEmail: profile.email),
    );
    if (result == null) return;
    final error = await _repository.resetPin(userId: profile.id, newPin: result.pin);
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
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
          else if (_filtered.isEmpty)
            const Text('No hay empleados todavía')
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
  final String? fixedEmail;

  const _EmployeeFormDialog({this.fixedEmail});

  @override
  State<_EmployeeFormDialog> createState() => _EmployeeFormDialogState();
}

class _EmployeeFormDialogState extends State<_EmployeeFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  final _pinController = TextEditingController();

  bool get _isReset => widget.fixedEmail != null;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.fixedEmail ?? '');
  }

  @override
  void dispose() {
    _emailController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  void _confirm() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      _EmployeeCredentials(email: _emailController.text.trim(), pin: _pinController.text),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isReset ? 'Restablecer PIN' : 'Nuevo empleado'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _emailController,
              enabled: !_isReset,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Correo', border: OutlineInputBorder()),
              validator: (value) => (value == null || value.trim().isEmpty) ? 'Ingresa un correo' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _pinController,
              autofocus: _isReset,
              obscureText: true,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: _isReset ? 'PIN nuevo' : 'PIN',
                helperText: 'Recomendado: 4 dígitos numéricos',
                border: const OutlineInputBorder(),
              ),
              validator: (value) => (value == null || value.length < 4) ? 'Mínimo 4 caracteres' : null,
              onFieldSubmitted: (_) => _confirm(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton(onPressed: _confirm, child: Text(_isReset ? 'Guardar' : 'Crear')),
      ],
    );
  }
}
