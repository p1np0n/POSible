import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../providers/app_preferences_provider.dart';
import '../../widgets/pin_pad.dart';
import 'login_screen.dart';

/// Acceso rápido para cambiar de cajero: elegir quién eres (de los correos
/// que ya iniciaron sesión en este dispositivo) y escribir tu PIN, en vez
/// de escribir correo y contraseña completos cada vez.
///
/// Por dentro sigue siendo un inicio de sesión normal de Supabase — el
/// "PIN" es la contraseña de la cuenta. Para que funcione, la contraseña
/// del empleado debe ser numérica, del mismo largo que [pinLength].
class PinLoginScreen extends StatefulWidget {
  const PinLoginScreen({super.key});

  @override
  State<PinLoginScreen> createState() => _PinLoginScreenState();
}

class _PinLoginScreenState extends State<PinLoginScreen> {
  String? _selectedEmail;
  String _pin = '';
  bool _loading = false;
  String? _errorMessage;

  Future<void> _forget(String email) async {
    await context.read<AppPreferencesProvider>().forgetEmail(email);
  }

  void _selectUser(String email) {
    setState(() {
      _selectedEmail = email;
      _pin = '';
      _errorMessage = null;
    });
  }

  void _backToUserList() {
    setState(() {
      _selectedEmail = null;
      _pin = '';
      _errorMessage = null;
    });
  }

  Future<void> _appendDigit(String digit) async {
    if (_loading || _pin.length >= pinLength) return;
    setState(() {
      _pin += digit;
      _errorMessage = null;
    });
    if (_pin.length == pinLength) {
      await _submit();
    }
  }

  void _backspace() {
    if (_loading || _pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      await Supabase.instance.client.auth.signInWithPassword(email: _selectedEmail, password: _pin);
      if (mounted) await context.read<AppPreferencesProvider>().markActiveNow();
    } on AuthException catch (e) {
      setState(() {
        _errorMessage = e.message;
        _pin = '';
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error de conexión.';
        _pin = '';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final knownEmails = context.watch<AppPreferencesProvider>().knownEmails;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: _selectedEmail == null
                ? _buildUserPicker(knownEmails)
                : _buildPinPad(),
          ),
        ),
      ),
    );
  }

  Widget _buildUserPicker(List<String> knownEmails) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.point_of_sale, size: 64, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 8),
        Text('POSible', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        const Text('¿Quién eres?', style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 16),
        ...knownEmails.map((email) => Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text(email),
                onTap: () => _selectUser(email),
                trailing: IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Olvidar en este dispositivo',
                  onPressed: () => _forget(email),
                ),
              ),
            )),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          ),
          icon: const Icon(Icons.person_add_alt),
          label: const Text('Usar otra cuenta'),
        ),
      ],
    );
  }

  Widget _buildPinPad() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _loading ? null : _backToUserList,
          ),
        ),
        const CircleAvatar(radius: 28, child: Icon(Icons.person, size: 28)),
        const SizedBox(height: 8),
        Text(_selectedEmail!, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        const Text('Introduce tu PIN', style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 16),
        if (_loading) const Padding(padding: EdgeInsets.only(bottom: 12), child: CircularProgressIndicator()),
        if (_errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(_errorMessage!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
          ),
        PinPad(
          length: pinLength,
          filledCount: _pin.length,
          loading: _loading,
          onDigit: _appendDigit,
          onBackspace: _backspace,
        ),
      ],
    );
  }
}
