import 'dart:async';

import 'package:flutter/material.dart';
import 'package:screen_brightness/screen_brightness.dart';

/// Baja el brillo de la pantalla (sin tocar el brillo del sistema, así no
/// hace falta ningún permiso especial en Android) después de un minuto sin
/// tocarla, para ahorrar batería en el mostrador. Apenas se vuelve a tocar
/// la pantalla, recupera el brillo normal de inmediato. Se puede apagar
/// desde Configuración → General.
class ScreenDimmer extends StatefulWidget {
  final Widget child;
  final bool enabled;

  const ScreenDimmer({super.key, required this.child, required this.enabled});

  @override
  State<ScreenDimmer> createState() => _ScreenDimmerState();
}

class _ScreenDimmerState extends State<ScreenDimmer> with WidgetsBindingObserver {
  static const _dimAfter = Duration(minutes: 1);
  static const _dimmedBrightness = 0.02;

  Timer? _timer;
  bool _dimmed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.enabled) _restartTimer();
  }

  @override
  void didUpdateWidget(covariant ScreenDimmer old) {
    super.didUpdateWidget(old);
    if (widget.enabled == old.enabled) return;
    if (widget.enabled) {
      _restartTimer();
    } else {
      _timer?.cancel();
      _undim();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _timer?.cancel();
      _undim();
    } else if (state == AppLifecycleState.resumed && widget.enabled) {
      _restartTimer();
    }
  }

  void _restartTimer() {
    _timer?.cancel();
    _timer = Timer(_dimAfter, _dim);
  }

  Future<void> _dim() async {
    if (_dimmed) return;
    _dimmed = true;
    try {
      await ScreenBrightness().setApplicationScreenBrightness(_dimmedBrightness);
    } catch (_) {
      // Algunos dispositivos no dejan cambiar el brillo por esta vía — no
      // es grave, la app sigue funcionando normal, solo no se oscurece.
    }
  }

  Future<void> _undim() async {
    if (!_dimmed) return;
    _dimmed = false;
    try {
      await ScreenBrightness().resetApplicationScreenBrightness();
    } catch (_) {}
  }

  void _onUserInteraction(PointerDownEvent _) {
    if (!widget.enabled) return;
    if (_dimmed) _undim();
    _restartTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    if (_dimmed) _undim();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onUserInteraction,
      child: widget.child,
    );
  }
}
