import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/employee_profile.dart';
import '../../models/store.dart';
import '../../services/profile_repository.dart';
import '../../services/store_repository.dart';
import '../../utils/search_normalize.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_state.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/pin_entry_dialog.dart';
import '../../widgets/status_badge.dart';

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
  String _search = '';
  bool _loading = true;
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
      final stores = await _repository.getAllStores();
      if (!mounted) return;
      setState(() {
        _stores = stores;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudieron cargar las tiendas';
        _loading = false;
      });
    }
  }

  List<Store> get _filtered {
    if (_search.trim().isEmpty) return _stores;
    final term = normalizeForSearch(_search);
    return _stores
        .where((s) => normalizeForSearch(s.name).contains(term) || normalizeForSearch(s.storeCode).contains(term))
        .toList();
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

  Future<void> _copyStoreCode(Store store) async {
    await Clipboard.setData(ClipboardData(text: store.storeCode));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Código de ${store.name} copiado: ${store.storeCode}')));
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
    showDialog(
      context: context,
      builder: (_) => _StoreEmployeesDialog(store: store, profileRepository: _profileRepository),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingIndicator();
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);
    if (_stores.isEmpty) {
      return const EmptyState(message: 'No hay tiendas todavía', icon: Icons.storefront_outlined);
    }

    final filtered = _filtered;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Buscar tienda por nombre o código',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (value) => setState(() => _search = value),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${_stores.length} ${_stores.length == 1 ? "tienda" : "tiendas"}',
                  style: const TextStyle(color: Colors.grey.shade700, fontSize: 12),
                ),
              ],
            ),
          ),
          if (filtered.isEmpty)
            EmptyState(message: 'Ninguna tienda coincide con "$_search"', icon: Icons.search_off)
          else
            ...filtered.map((store) => _StoreCard(
                  store: store,
                  onToggleFeature: ({reports, customers, employees}) =>
                      _toggleFeature(store, reports: reports, customers: customers, employees: employees),
                  onCopyCode: () => _copyStoreCode(store),
                  onResetPassword: () => _resetOwnerPassword(store),
                  onShowEmployees: () => _showEmployees(store),
                )),
        ],
      ),
    );
  }
}

class _StoreCard extends StatelessWidget {
  final Store store;
  final void Function({bool? reports, bool? customers, bool? employees}) onToggleFeature;
  final VoidCallback onCopyCode;
  final VoidCallback onResetPassword;
  final VoidCallback onShowEmployees;

  const _StoreCard({
    required this.store,
    required this.onToggleFeature,
    required this.onCopyCode,
    required this.onResetPassword,
    required this.onShowEmployees,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  child: Icon(Icons.storefront_outlined, color: Theme.of(context).colorScheme.onPrimaryContainer),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(store.name, style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 2),
                      if (store.ownerEmail != null)
                        Row(
                          children: [
                            const Icon(Icons.person_outline, size: 14, color: Colors.grey.shade700),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                store.ownerEmail!,
                                style: const TextStyle(color: Colors.grey.shade700, fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        )
                      else
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: StatusBadge(label: 'Sin administrador', tone: StatusBadgeTone.warning, dense: true),
                        ),
                    ],
                  ),
                ),
                InkWell(
                  onTap: onCopyCode,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Column(
                      children: [
                        Text(store.storeCode, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const Icon(Icons.copy_outlined, size: 14, color: Colors.grey.shade700),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('Reportes'),
              value: store.featureReports,
              onChanged: (value) => onToggleFeature(reports: value),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('Clientes'),
              value: store.featureCustomers,
              onChanged: (value) => onToggleFeature(customers: value),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('Empleados'),
              value: store.featureEmployees,
              onChanged: (value) => onToggleFeature(employees: value),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: store.ownerId == null ? null : onResetPassword,
                  icon: const Icon(Icons.password_outlined),
                  label: const Text('Restablecer contraseña'),
                ),
                OutlinedButton.icon(
                  onPressed: onShowEmployees,
                  icon: const Icon(Icons.badge_outlined),
                  label: const Text('Ver empleados'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Pide una contraseña nueva (dos veces, para confirmar) y la devuelve al
/// cerrar — solo para el administrador de una tienda, que puede tener
/// contraseña alfanumérica. Para el PIN de un empleado se usa
/// showPinEntryDialog (teclado propio, siempre pinLength dígitos).
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
            Text(widget.subtitle, style: const TextStyle(color: Colors.grey.shade700)),
            const SizedBox(height: 12),
            TextFormField(
              controller: _passwordController,
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

/// Popup centrado (no un bottom sheet de ancho completo, que se veía
/// enorme y pegado abajo en pantallas anchas) con los empleados de una
/// tienda (administrador principal solamente) y un botón para restablecer
/// el PIN de cualquiera de ellos — no permite aprobar ni quitar empleados
/// de otra tienda, eso sigue siendo solo del dueño de esa tienda.
class _StoreEmployeesDialog extends StatefulWidget {
  final Store store;
  final ProfileRepository profileRepository;

  const _StoreEmployeesDialog({required this.store, required this.profileRepository});

  @override
  State<_StoreEmployeesDialog> createState() => _StoreEmployeesDialogState();
}

class _StoreEmployeesDialogState extends State<_StoreEmployeesDialog> {
  List<EmployeeProfile>? _employees;
  String? _error;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final employees = await widget.profileRepository.getForStore(widget.store.id);
      if (mounted) setState(() => _employees = employees);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  List<EmployeeProfile> get _filtered {
    final employees = _employees ?? const [];
    if (_search.trim().isEmpty) return employees;
    final term = normalizeForSearch(_search);
    return employees.where((p) => normalizeForSearch(p.email).contains(term)).toList();
  }

  Future<void> _resetPin(EmployeeProfile profile) async {
    final newPin = await showPinEntryDialog(
      context,
      title: 'Restablecer PIN',
      subtitle: profile.email.isEmpty ? '(sin correo)' : profile.email,
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
    final maxHeight = (MediaQuery.of(context).size.height * 0.7).clamp(320.0, 560.0);
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SizedBox(
          height: maxHeight,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Empleados de ${widget.store.name}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'Cerrar',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                if (_employees != null && _employees!.length > 5) ...[
                  const SizedBox(height: 8),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Buscar empleado',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (value) => setState(() => _search = value),
                  ),
                ],
                const SizedBox(height: 8),
                Expanded(
                  child: _error != null
                      ? ErrorState(message: 'No se pudieron cargar los empleados', onRetry: _load)
                      : _employees == null
                          ? const LoadingIndicator()
                          : _employees!.isEmpty
                              ? const EmptyState(
                                  message: 'Esta tienda todavía no tiene empleados',
                                  icon: Icons.badge_outlined,
                                )
                              : _filtered.isEmpty
                                  ? EmptyState(
                                      message: 'Ningún empleado coincide con "$_search"',
                                      icon: Icons.search_off,
                                    )
                                  : ListView.builder(
                                      itemCount: _filtered.length,
                                      itemBuilder: (context, index) {
                                        final profile = _filtered[index];
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
          ),
        ),
      ),
    );
  }
}
