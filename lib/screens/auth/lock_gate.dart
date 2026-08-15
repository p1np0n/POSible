import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/app_preferences_provider.dart';
import 'lock_screen.dart';

/// Envuelve la app ya autenticada (HomeShell) y muestra LockScreen encima
/// si pasó más tiempo del configurado (Configuración → Bloqueo automático)
/// desde que la app estuvo en primer plano por última vez.
class LockGate extends StatefulWidget {
  final Widget child;

  const LockGate({super.key, required this.child});

  @override
  State<LockGate> createState() => _LockGateState();
}

class _LockGateState extends State<LockGate> with WidgetsBindingObserver {
  bool _locked = false;
  bool _checkedOnStart = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_checkedOnStart) {
      _checkedOnStart = true;
      _maybeLock();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final prefs = context.read<AppPreferencesProvider>();
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      prefs.markActiveNow();
    } else if (state == AppLifecycleState.resumed) {
      _maybeLock();
    }
  }

  Future<void> _maybeLock() async {
    final prefs = context.read<AppPreferencesProvider>();
    final should = await prefs.shouldLock();
    if (should && mounted) setState(() => _locked = true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_locked) LockScreen(onUnlocked: () => setState(() => _locked = false)),
      ],
    );
  }
}
