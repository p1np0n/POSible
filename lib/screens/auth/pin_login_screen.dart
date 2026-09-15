import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/app_preferences_provider.dart';
import '../../services/pin_auth_repository.dart';
import '../../widgets/pin_pad.dart';
import 'login_screen.dart';

/// Acceso rápido para cambiar de cajero: elegir quién eres (de las cuentas
/// que ya se usaron en este dispositivo) y escribir tu PIN de 4 dígitos,
/// en vez de escribir correo y contraseña completos cada vez. Sirve tanto
/// para el administrador (que además tiene su contraseña completa aparte)
/// como para los cajeros (que solo tienen PIN, nunca contraseña).
///
/// El PIN se verifica en el servidor (ver PinAuthRepository) — nunca es la
/// contraseña real de la cuenta.
class PinLoginScreen extends StatefulWidget {
  const PinLoginScreen({super.key});

  @override
  State<PinLoginScreen> createState() => _PinLoginScreenState();
}

class _PinLoginScreenState extends State<PinLoginScreen> {
  final PinAuthRepository _repository = PinAuthRepository();
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
    final error = await _repository.loginWithPin(email: _selectedEmail!, pin: _pin);
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _errorMessage = error;
        _pin = '';
        _loading = false;
      });
      return;
    }
    await context.read<AppPreferencesProvider>().markActiveNow();
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final prefs = context.watch<AppPreferencesProvider>();

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: _selectedEmail == null
                ? _buildUserPicker(prefs)
                : _buildPinPad(prefs),
          ),
        ),
      ),
    );
  }

  Widget _buildUserPicker(AppPreferencesProvider prefs) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.point_of_sale, size: 64, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 8),
        Text('POSible', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        const Text('¿Quién eres?', style: TextStyle(color: const Color(0xFF616161))),
        const SizedBox(height: 16),
        ...prefs.knownEmails.map((email) => Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text(prefs.knownDisplayNames[email] ?? email),
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

  Widget _buildPinPad(AppPreferencesProvider prefs) {
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
        Text(prefs.knownDisplayNames[_selectedEmail] ?? _selectedEmail!,
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        const Text('Introduce tu PIN', style: TextStyle(color: const Color(0xFF616161))),
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
