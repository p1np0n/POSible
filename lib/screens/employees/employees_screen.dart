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

  @override
  Widget build(BuildContext context) {
    final myId = Supabase.instance.client.auth.currentUser?.id;

    return RefreshIndicator(
      onRefresh: _load,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Cuando alguien crea una cuenta nueva desde la pantalla de inicio de sesión, '
                  'aparece aquí sin aprobar y no puede ver ningún dato hasta que lo apruebes.',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                if (_profiles.isEmpty) const Text('No hay empleados todavía'),
                ..._profiles.map((profile) => Card(
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
