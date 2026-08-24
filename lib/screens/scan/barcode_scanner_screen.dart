import 'dart:async';

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
  final MobileScannerController _controller = MobileScannerController(autoStart: false);
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
    Navigator.of(context).pop(value);
  }

  @override
  void dispose() {
    _controller.dispose();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('Escanear código de barras')),
      body: _starting
          ? const Center(child: CircularProgressIndicator())
          : _startErrorMessage != null
              ? _buildMessage(_startErrorMessage!)
              : MobileScanner(
                  controller: _controller,
                  onDetect: _onDetect,
                  errorBuilder: (context, error, child) => _buildMessage(_cameraErrorMessage(error)),
                ),
    );
  }
}
