import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../providers/app_preferences_provider.dart';
import '../../providers/store_provider.dart';
import '../../services/settings_repository.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SettingsRepository _repository = SettingsRepository();
  final _taxRateController = TextEditingController();
  final _notifyEmailController = TextEditingController();
  final _ocrApiKeyController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  bool _savingNotifyEmail = false;
  bool _sendingTest = false;
  bool _savingOcrApiKey = false;
  bool _changingPassword = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final settings = await _repository.getSettings();
      _taxRateController.text = settings.taxRatePercent.toStringAsFixed(2);
      _notifyEmailController.text = settings.lowStockNotifyEmail ?? '';
      _ocrApiKeyController.text = settings.ocrApiKey ?? '';
    } catch (_) {
      _taxRateController.text = '0';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _saveNotifyEmail() async {
    setState(() => _savingNotifyEmail = true);
    try {
      final email = _notifyEmailController.text.trim();
      await _repository.updateLowStockNotifyEmail(email.isEmpty ? null : email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Correo de alertas actualizado')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _savingNotifyEmail = false);
    }
  }

  Future<void> _saveOcrApiKey() async {
    setState(() => _savingOcrApiKey = true);
    try {
      final key = _ocrApiKeyController.text.trim();
      await _repository.updateOcrApiKey(key.isEmpty ? null : key);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Clave de OCR actualizada')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _savingOcrApiKey = false);
    }
  }

  Future<void> _changePassword() async {
    final newPassword = _newPasswordController.text;
    if (newPassword.length < 4) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('La contraseña debe tener al menos 4 caracteres')));
      return;
    }
    if (newPassword != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Las contraseñas no coinciden')));
      return;
    }
    setState(() => _changingPassword = true);
    try {
      await Supabase.instance.client.auth.updateUser(UserAttributes(password: newPassword));
      if (mounted) {
        _newPasswordController.clear();
        _confirmPasswordController.clear();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Contraseña actualizada')));
      }
    } on AuthException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.message}')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _changingPassword = false);
    }
  }

  Future<void> _sendTestEmail() async {
    setState(() => _sendingTest = true);
    final message = await _repository.sendLowStockTestEmail();
    if (mounted) {
      setState(() => _sendingTest = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
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
    _notifyEmailController.dispose();
    _ocrApiKeyController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
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
                  labelText: 'Tasa de IVA / impuesto (%)',
                  helperText:
                      'El precio de tus artículos ya lo incluye — esto solo sirve para mostrar '
                      'el desglose en la venta y el ticket, no se suma aparte',
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
              if (kIsWeb) ...[
                const SizedBox(height: 32),
                const Divider(),
                const SizedBox(height: 16),
                Text('Alertas de inventario bajo', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                TextField(
                  controller: _notifyEmailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Correo para avisos de inventario bajo (opcional)',
                    helperText:
                        'Requiere activar la función "notify-low-stock" en Supabase — ver LEEME.md',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: _savingNotifyEmail ? null : _saveNotifyEmail,
                        child: _savingNotifyEmail
                            ? const SizedBox(
                                height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Guardar'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _sendingTest ? null : _sendTestEmail,
                        child: _sendingTest
                            ? const SizedBox(
                                height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Enviar prueba ahora'),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 16),
              Text('Escanear facturas (Inventario)', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              TextField(
                controller: _ocrApiKeyController,
                decoration: const InputDecoration(
                  labelText: 'Clave de OCR.space (opcional)',
                  helperText: 'Sin esto, usa una clave de prueba compartida y limitada. '
                      'Consigue la tuya gratis en ocr.space/ocrapi',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _savingOcrApiKey ? null : _saveOcrApiKey,
                child: _savingOcrApiKey
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
              if (!kIsWeb) ...[
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),
                Text('Seguridad', style: Theme.of(context).textTheme.titleMedium),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Bloqueo automático'),
                  subtitle: const Text('Pedir el PIN de nuevo si la app estuvo en segundo plano este tiempo'),
                  trailing: DropdownButton<int>(
                    value: prefs.autoLockMinutes,
                    items: const [
                      DropdownMenuItem(value: 0, child: Text('Nunca')),
                      DropdownMenuItem(value: 5, child: Text('5 min')),
                      DropdownMenuItem(value: 15, child: Text('15 min')),
                      DropdownMenuItem(value: 30, child: Text('30 min')),
                      DropdownMenuItem(value: 60, child: Text('1 hora')),
                    ],
                    onChanged: (value) {
                      if (value != null) prefs.setAutoLockMinutes(value);
                    },
                  ),
                ),
              ],
              if (kIsWeb) ...[
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),
                Text('Cambiar contraseña', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                TextField(
                  controller: _newPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Contraseña nueva', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _confirmPasswordController,
                  obscureText: true,
                  decoration:
                      const InputDecoration(labelText: 'Repite la contraseña', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _changingPassword ? null : _changePassword,
                  child: _changingPassword
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Actualizar contraseña'),
                ),
              ],
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              Text('Cuenta', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(email, style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  context.read<StoreProvider>().reset();
                  Supabase.instance.client.auth.signOut();
                },
                icon: const Icon(Icons.logout),
                label: Text(kIsWeb ? 'Cerrar sesión' : 'Cerrar sesión / Cambiar de cajero'),
              ),
              if (!kIsWeb)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Si tu correo ya inició sesión antes en este dispositivo, al cerrar sesión '
                    'aparece el acceso rápido con PIN para el próximo cajero.',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ),
            ],
          );
  }
}
