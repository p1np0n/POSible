import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../providers/app_preferences_provider.dart';
import '../../providers/store_provider.dart';
import '../../widgets/pin_pad.dart';

/// Pantalla de bloqueo que aparece cuando la app estuvo en segundo plano
/// más tiempo del configurado en Configuración. Pide el PIN del mismo
/// usuario que ya tenía la sesión abierta (no cierra sesión).
class LockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;

  const LockScreen({super.key, required this.onUnlocked});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  String _pin = '';
  bool _loading = false;
  String? _errorMessage;

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
    final email = Supabase.instance.client.auth.currentUser?.email;
    if (email == null) return;
    setState(() => _loading = true);
    try {
      await Supabase.instance.client.auth.signInWithPassword(email: email, password: _pin);
      if (mounted) {
        await context.read<AppPreferencesProvider>().markActiveNow();
        widget.onUnlocked();
      }
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
    final email = Supabase.instance.client.auth.currentUser?.email ?? '';

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 56, color: Colors.indigo),
                const SizedBox(height: 8),
                const Text('App bloqueada', style: TextStyle(fontSize: 20)),
                const SizedBox(height: 4),
                Text(email, style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 4),
                const Text('Introduce tu PIN para continuar', style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 16),
                if (_loading)
                  const Padding(padding: EdgeInsets.only(bottom: 12), child: CircularProgressIndicator()),
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
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _loading
                      ? null
                      : () async {
                          context.read<StoreProvider>().reset();
                          await Supabase.instance.client.auth.signOut();
                        },
                  icon: const Icon(Icons.logout),
                  label: const Text('No soy yo / Cerrar sesión'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
