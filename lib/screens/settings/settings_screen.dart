import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../providers/app_preferences_provider.dart';
import '../../providers/customer_display_provider.dart';
import '../../providers/store_provider.dart';
import '../../services/profile_repository.dart';
import '../../services/settings_repository.dart';
import '../../utils/password_strength.dart';
import '../../widgets/pin_entry_dialog.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SettingsRepository _repository = SettingsRepository();
  final ProfileRepository _profileRepository = ProfileRepository();
  final _taxRateController = TextEditingController();
  final _marginController = TextEditingController();
  final _notifyEmailController = TextEditingController();
  final _ocrApiKeyController = TextEditingController();
  final _googleSearchApiKeyController = TextEditingController();
  final _googleSearchEngineIdController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  bool _savingMargin = false;
  bool _savingNotifyEmail = false;
  bool _sendingTest = false;
  bool _savingOcrApiKey = false;
  bool _savingGoogleSearchConfig = false;
  bool _changingPassword = false;
  bool _changingPin = false;
  bool _fillingPhotos = false;
  bool _generatingThumbnails = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final settings = await _repository.getSettings();
      _taxRateController.text = settings.taxRatePercent.toStringAsFixed(2);
      _marginController.text = settings.defaultMarginPercent.toStringAsFixed(2);
      _notifyEmailController.text = settings.lowStockNotifyEmail ?? '';
      _ocrApiKeyController.text = settings.ocrApiKey ?? '';
      _googleSearchApiKeyController.text = settings.googleSearchApiKey ?? '';
      _googleSearchEngineIdController.text = settings.googleSearchEngineId ?? '';
    } catch (_) {
      _taxRateController.text = '0';
      _marginController.text = '30';
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

  Future<void> _saveGoogleSearchConfig() async {
    setState(() => _savingGoogleSearchConfig = true);
    try {
      final apiKey = _googleSearchApiKeyController.text.trim();
      final engineId = _googleSearchEngineIdController.text.trim();
      await _repository.updateGoogleSearchConfig(
        apiKey: apiKey.isEmpty ? null : apiKey,
        engineId: engineId.isEmpty ? null : engineId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Configuración de Google actualizada')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _savingGoogleSearchConfig = false);
    }
  }

  Future<void> _changePassword() async {
    final newPassword = _newPasswordController.text;
    final strengthError = validateStrongPassword(newPassword);
    if (strengthError != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(strengthError)));
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

  /// Cambia el PIN de acceso rápido del administrador (separado de su
  /// contraseña real) — solo el propio administrador puede hacerlo, no
  /// hay nadie "por encima" dentro de la tienda que se lo restablezca si
  /// lo olvida (en ese caso, entra con su correo y contraseña completos y
  /// lo cambia acá).
  Future<void> _changeMyPin() async {
    final myProfile = context.read<StoreProvider>().myProfile;
    if (myProfile == null) return;
    final pin = await showPinEntryDialog(context, title: 'Mi PIN nuevo (4 dígitos)');
    if (pin == null || !mounted) return;
    setState(() => _changingPin = true);
    final error = await _profileRepository.setPin(userId: myProfile.id, pin: pin);
    if (!mounted) return;
    setState(() => _changingPin = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error ?? 'PIN actualizado')),
    );
  }

  Future<void> _sendTestEmail() async {
    setState(() => _sendingTest = true);
    final message = await _repository.sendLowStockTestEmail();
    if (mounted) {
      setState(() => _sendingTest = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _fillMissingPhotosNow() async {
    setState(() => _fillingPhotos = true);
    final message = await _repository.fillMissingPhotosNow();
    if (mounted) {
      setState(() => _fillingPhotos = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _generateThumbnailsNow() async {
    setState(() => _generatingThumbnails = true);
    final message = await _repository.generateThumbnailsNow();
    if (mounted) {
      setState(() => _generatingThumbnails = false);
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

  Future<void> _saveMargin() async {
    final value = double.tryParse(_marginController.text);
    if (value == null) return;
    setState(() => _savingMargin = true);
    try {
      await _repository.updateDefaultMargin(value);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Margen actualizado')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _savingMargin = false);
    }
  }

  @override
  void dispose() {
    _taxRateController.dispose();
    _marginController.dispose();
    _notifyEmailController.dispose();
    _ocrApiKeyController.dispose();
    _googleSearchApiKeyController.dispose();
    _googleSearchEngineIdController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final email = Supabase.instance.client.auth.currentUser?.email ?? '';
    final prefs = context.watch<AppPreferencesProvider>();
    // Solo el administrador de la tienda ve las secciones sensibles
    // (impuestos, margen, claves de API, empleados/PIN, etc.) — "General"
    // (modo oscuro, vista de lista, cámara y lector USB) y "Cuenta" son
    // para cualquiera con sesión iniciada, cajero incluido: son
    // preferencias del propio celular, no algo que administre la cuenta.
    final isAdmin = context.watch<StoreProvider>().isStoreAdmin;

    if (_loading) return const Center(child: CircularProgressIndicator());

    // Arma la lista de secciones a mostrar, con un separador entre cada
    // una que SÍ queda visible (nunca antes de la primera ni después de
    // la última) — así ocultar secciones para un cajero no deja
    // separadores de más ni huecos raros.
    final children = <Widget>[];
    void addSection(List<Widget> section) {
      if (children.isNotEmpty) {
        children.addAll([const SizedBox(height: 32), const Divider(), const SizedBox(height: 16)]);
      }
      children.addAll(section);
    }

    if (isAdmin) {
      addSection([
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
      ]);

      addSection([
        Text('Margen', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        TextField(
          controller: _marginController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Margen general (%)',
            helperText: 'Se usa para sugerir el precio de venta a partir del costo, en los '
                'artículos que no tengan su propio margen configurado',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _savingMargin ? null : _saveMargin,
          child: _savingMargin
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Guardar'),
        ),
      ]);

      if (kIsWeb) {
        addSection([
          Text('Alertas de inventario bajo', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _notifyEmailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Correo para avisos de inventario bajo (opcional)',
              helperText: 'Requiere activar la función "notify-low-stock" en Supabase — ver LEEME.md',
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
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Guardar'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: _sendingTest ? null : _sendTestEmail,
                  child: _sendingTest
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Enviar prueba ahora'),
                ),
              ),
            ],
          ),
        ]);
      }

      addSection([
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
      ]);

      addSection([
        Text('Fotos de productos', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        const Text(
          'Todas las noches se revisan solos los artículos con código de barras que '
          'todavía no tienen foto, y se les busca una en internet (requiere activar la '
          'función "fill-missing-photos" en Supabase — ver LEEME.md). Con este botón '
          'puedes correrlo ahora mismo, sin esperar a la noche.',
          style: TextStyle(color: const Color(0xFF616161), fontSize: 12),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: _fillingPhotos ? null : _fillMissingPhotosNow,
          child: _fillingPhotos
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Buscar fotos faltantes ahora'),
        ),
        const SizedBox(height: 16),
        const Text(
          'La búsqueda de fotos por código de barras revisa, en orden, el catálogo '
          'global, Open Food Facts, Open Beauty Facts, Open Products Facts y '
          'UPCitemdb — todo gratis, sin configurar nada. Si ninguna encuentra una '
          'foto, y pones tu propia clave de Google Custom Search acá abajo, se '
          'intenta también ahí como último recurso.',
          style: TextStyle(color: const Color(0xFF616161), fontSize: 12),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _googleSearchApiKeyController,
          decoration: const InputDecoration(
            labelText: 'Clave de Google Custom Search (opcional)',
            helperText: 'Gratis hasta 100 búsquedas/día. Créala en console.cloud.google.com '
                '(API "Custom Search API").',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _googleSearchEngineIdController,
          decoration: const InputDecoration(
            labelText: 'ID del motor de búsqueda (opcional)',
            helperText: 'Créalo en programmablesearchengine.google.com, activando '
                '"Búsqueda de imágenes" y "Buscar en toda la red".',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _savingGoogleSearchConfig ? null : _saveGoogleSearchConfig,
          child: _savingGoogleSearchConfig
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Guardar'),
        ),
      ]);

      addSection([
        Text('Ahorrar ancho de banda de las fotos', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        const Text(
          'Las fotos nuevas que subas generan sola una versión chica (miniatura) que '
          'usan el mosaico de Ventas y las listas en vez de la foto completa — pesa '
          'mucho menos ancho de banda. Para que los productos que ya tenían foto de '
          'antes también la tengan, corre esto una vez (requiere activar la función '
          '"generate-thumbnails" en Supabase — ver LEEME.md). Si dice que quedan más '
          'pendientes, tócalo de nuevo.',
          style: TextStyle(color: const Color(0xFF616161), fontSize: 12),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: _generatingThumbnails ? null : _generateThumbnailsNow,
          child: _generatingThumbnails
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Generar miniaturas de fotos existentes'),
        ),
      ]);
    }

    // "General": visible para cualquiera con sesión iniciada (cajero
    // incluido) — son preferencias de este celular, no algo que
    // administre la cuenta de la tienda.
    addSection([
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
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Uso un lector de código de barras USB en Ventas'),
        subtitle: const Text(
          'El buscador de Ventas se mantiene siempre listo para que el lector '
          'escriba ahí y agregue el producto de inmediato, sin tener que tocar '
          'la pantalla entre un escaneo y otro. Déjalo apagado si vendes solo '
          'tocando la pantalla, para no abrir el teclado de más.',
        ),
        value: prefs.usbScannerModeEnabled,
        onChanged: prefs.setUsbScannerModeEnabled,
      ),
    ]);

    if (isAdmin && !kIsWeb) {
      addSection([
        Text('Pantalla para el cliente', style: Theme.of(context).textTheme.titleMedium),
        const _CustomerDisplaySettings(),
      ]);

      addSection([
        Text('Seguridad', style: Theme.of(context).textTheme.titleMedium),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Mi PIN de acceso rápido'),
          subtitle: const Text(
            'Para elegirte en "¿Quién eres?" sin escribir tu correo y contraseña '
            'completos. Es un código aparte, no tu contraseña.',
          ),
          trailing: _changingPin
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : OutlinedButton(onPressed: _changeMyPin, child: const Text('Cambiar')),
        ),
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
      ]);
    }

    if (isAdmin && kIsWeb) {
      addSection([
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
          decoration: const InputDecoration(labelText: 'Repite la contraseña', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _changingPassword ? null : _changePassword,
          child: _changingPassword
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Actualizar contraseña'),
        ),
      ]);
    }

    // "Cuenta": visible para cualquiera, cajero incluido — necesita poder
    // cerrar sesión / cambiar de cajero igual que el administrador.
    addSection([
      Text('Cuenta', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      Text(email, style: const TextStyle(color: const Color(0xFF616161))),
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
            style: TextStyle(color: const Color(0xFF616161), fontSize: 12),
          ),
        ),
    ]);

    return ListView(padding: const EdgeInsets.all(16), children: children);
  }
}

/// Enciende/apaga el servidor local de "Pantalla para el cliente" (ver
/// CustomerDisplayProvider) y muestra la IP + puerto a los que hay que
/// conectar el otro celular/tablet (con el APK "Info ScreenClone")
/// mientras esté prendido. No usa internet ni Supabase — ambos
/// dispositivos tienen que estar en la misma red WiFi.
class _CustomerDisplaySettings extends StatelessWidget {
  const _CustomerDisplaySettings();

  @override
  Widget build(BuildContext context) {
    final display = context.watch<CustomerDisplayProvider>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Activar pantalla para el cliente'),
          subtitle: const Text(
            'Muestra en otro celular/tablet (con el APK "Info ScreenClone") lo que el '
            'cliente está comprando y el total, en vivo — sin internet, conectado por '
            'la misma red WiFi de la tienda.',
          ),
          value: display.running,
          onChanged: (value) => value ? display.start() : display.stop(),
        ),
        if (display.running)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'En "Info ScreenClone", toca la pantalla y escribe esta dirección:',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  if (display.localAddresses.isEmpty)
                    const Text('Buscando la dirección IP de este celular…')
                  else
                    for (final address in display.localAddresses)
                      SelectableText(
                        '$address:${display.port}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                  const SizedBox(height: 6),
                  const Text(
                    'Si aparece más de una dirección, prueba con la primera — las demás son '
                    'de otras redes que este celular pueda tener conectadas a la vez.',
                    style: TextStyle(fontSize: 12, color: const Color(0xFF616161)),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
