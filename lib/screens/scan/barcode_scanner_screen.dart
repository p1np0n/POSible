import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  // autoStart en false porque el arranque lo controla _start() acá abajo,
  // con su propio timeout — si se deja que MobileScanner lo arranque solo
  // y la cámara nunca contesta (permiso nunca resuelto, librería externa
  // que no carga, etc.), la pantalla se queda en negro para siempre sin
  // ningún aviso.
  //
  // "formats" se limita a los tipos de código que de verdad se usan acá
  // (de barras + QR) en vez de dejarlo en todos los que existen — cada
  // tipo de más que el lector prueba por cuadro es tiempo que no usa para
  // reintentar, así que menos tipos = más intentos por segundo = más
  // chances de pescar un cuadro bien enfocado. "noDuplicates" además saca
  // la pausa de 250ms entre intentos que trae el modo por defecto.
  final MobileScannerController _controller = MobileScannerController(
    autoStart: false,
    formats: const [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
      BarcodeFormat.code128,
      BarcodeFormat.code39,
      BarcodeFormat.itf,
      BarcodeFormat.qrCode,
    ],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  final AudioPlayer _beepPlayer = AudioPlayer();
  bool _handled = false;
  bool _starting = true;
  String? _startErrorMessage;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    setState(() {
      _starting = true;
      _startErrorMessage = null;
    });
    try {
      await _controller.start().timeout(const Duration(seconds: 12));
    } on TimeoutException {
      if (mounted) {
        setState(() => _startErrorMessage =
            'La cámara está tardando demasiado en responder.\nRevisa que le hayas dado permiso al navegador o a la app, y vuelve a intentar.');
      }
    } catch (e) {
      if (mounted) setState(() => _startErrorMessage = 'No se pudo abrir la cámara.\n$e');
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    final value = barcodes.first.rawValue;
    if (value == null || value.isEmpty) return;
    _handled = true;
    unawaited(_beepPlayer.play(AssetSource('sounds/beep.wav')));
    Navigator.of(context).pop(value);
  }

  @override
  void dispose() {
    _controller.dispose();
    _beepPlayer.dispose();
    super.dispose();
  }

  Widget _buildMessage(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.videocam_off_outlined, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 16),
            FilledButton(onPressed: _start, child: const Text('Reintentar')),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar', style: TextStyle(color: Colors.white70)),
            ),
          ],
        ),
      ),
    );
  }

  String _cameraErrorMessage(MobileScannerException error) {
    switch (error.errorCode) {
      case MobileScannerErrorCode.permissionDenied:
        return 'No se pudo acceder a la cámara: falta el permiso.\n'
            'Actívalo en los ajustes del navegador o de la app y vuelve a intentar.';
      case MobileScannerErrorCode.unsupported:
        return 'Este dispositivo o navegador no admite escanear con cámara.';
      default:
        return 'No se pudo abrir la cámara.'
            '${error.errorDetails?.message != null ? '\n${error.errorDetails!.message}' : ''}';
    }
  }

  /// Recuadro de guía centrado, con la proporción típica de un código de
  /// barras (más ancho que alto) — acerca el código hasta llenarlo ayuda a
  /// que la cámara le encuentre foco y lo lea, en vez de intentar leerlo
  /// desde toda la imagen.
  Rect _scanWindow(Size size) {
    final width = size.width * 0.82;
    final height = width * 0.45;
    return Rect.fromCenter(center: size.center(Offset.zero), width: width, height: height);
  }

  /// Solo se dibuja mientras la cámara realmente está mostrando imagen —
  /// si algo falla después de arrancar (ej. se revoca el permiso a mitad
  /// de sesión), no queda el recuadro guía flotando sobre el mensaje de
  /// error de MobileScanner.
  Widget _buildScanGuide(Size size) {
    return IgnorePointer(
      child: ValueListenableBuilder<MobileScannerState>(
        valueListenable: _controller,
        builder: (context, value, child) {
          if (!value.isInitialized || !value.isRunning || value.error != null) {
            return const SizedBox.shrink();
          }
          return child!;
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(size: size, painter: _ScanWindowPainter(_scanWindow(size))),
            const Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.only(bottom: 32, left: 24, right: 24),
                child: Text(
                  'Acerca el código de barras hasta que quede dentro del recuadro',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// El flash solo funciona en la app instalada (Android/iOS) — en la web
  /// no hay forma de controlarlo desde el navegador, así que este ícono
  /// directamente no aparece ahí (torchState queda "unavailable").
  Widget _buildTorchButton() {
    return ValueListenableBuilder<MobileScannerState>(
      valueListenable: _controller,
      builder: (context, value, child) {
        if (value.torchState == TorchState.unavailable) return const SizedBox.shrink();
        return IconButton(
          icon: Icon(value.torchState == TorchState.on ? Icons.flash_on : Icons.flash_off),
          tooltip: 'Linterna',
          onPressed: () => _controller.toggleTorch(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Escanear código de barras'),
        actions: [_buildTorchButton()],
      ),
      body: _starting
          ? const Center(child: CircularProgressIndicator())
          : _startErrorMessage != null
              ? _buildMessage(_startErrorMessage!)
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final size = constraints.biggest;
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        MobileScanner(
                          controller: _controller,
                          onDetect: _onDetect,
                          scanWindow: _scanWindow(size),
                          errorBuilder: (context, error, child) =>
                              _buildMessage(_cameraErrorMessage(error)),
                        ),
                        _buildScanGuide(size),
                      ],
                    );
                  },
                ),
    );
  }
}

/// Oscurece todo menos el recuadro de guía, y le dibuja un borde rojo —
/// como en la mayoría de apps de escaneo, para que sea obvio dónde poner
/// el código.
class _ScanWindowPainter extends CustomPainter {
  _ScanWindowPainter(this.scanWindow);

  final Rect scanWindow;

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPath = Path()..addRect(Rect.largest);
    final cutoutPath = Path()..addRRect(RRect.fromRectAndRadius(scanWindow, const Radius.circular(12)));
    final backgroundWithCutout = Path.combine(PathOperation.difference, backgroundPath, cutoutPath);
    canvas.drawPath(backgroundWithCutout, Paint()..color = Colors.black.withOpacity(0.55));

    canvas.drawRRect(
      RRect.fromRectAndRadius(scanWindow, const Radius.circular(12)),
      Paint()
        ..color = Colors.red
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(covariant _ScanWindowPainter oldDelegate) => oldDelegate.scanWindow != scanWindow;
}
