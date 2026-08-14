import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../providers/app_preferences_provider.dart';
import '../../services/settings_repository.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SettingsRepository _repository = SettingsRepository();
  final _taxRateController = TextEditingController();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final settings = await _repository.getSettings();
      _taxRateController.text = settings.taxRatePercent.toStringAsFixed(2);
    } catch (_) {
      _taxRateController.text = '0';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    final value = double.tryParse(_taxRateController.text);
    if (value == null) return;
    setState(() => _saving = true);
    try {
      await _repository.updateTaxRate(value);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Impuesto actualizado')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _taxRateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final email = Supabase.instance.client.auth.currentUser?.email ?? '';
    final prefs = context.watch<AppPreferencesProvider>();

    return _loading
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Impuestos', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              TextField(
                controller: _taxRateController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Tasa de impuesto (%)',
                  helperText: 'Se aplica automáticamente al total de cada venta',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Guardar'),
              ),
              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 16),
              Text('General', style: Theme.of(context).textTheme.titleMedium),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Modo oscuro'),
                value: prefs.darkMode,
                onChanged: prefs.setDarkMode,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Vista en lista de artículos'),
                subtitle: const Text('En vez de la cuadrícula, en la pantalla de Ventas'),
                value: prefs.useListLayout,
                onChanged: prefs.setUseListLayout,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Utilice la cámara para escanear códigos de barras'),
                value: prefs.cameraScanEnabled,
                onChanged: prefs.setCameraScanEnabled,
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              Text('Cuenta', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(email, style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => Supabase.instance.client.auth.signOut(),
                icon: const Icon(Icons.logout),
                label: const Text('Cerrar sesión'),
              ),
            ],
          );
  }
}
