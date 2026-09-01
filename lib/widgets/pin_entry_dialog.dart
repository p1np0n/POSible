import 'package:flutter/material.dart';

import 'pin_pad.dart';

/// Popup para escribir un PIN de [pinLength] dígitos con el teclado propio
/// de la app, igual al de "Login rápido" — nunca abre el teclado del
/// dispositivo (que empujaba el popup y lo sacaba del centro de la
/// pantalla). Se cierra solo apenas se completan los dígitos.
Future<String?> showPinEntryDialog(
  BuildContext context, {
  required String title,
  String? subtitle,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _PinEntryDialog(title: title, subtitle: subtitle),
  );
}

class _PinEntryDialog extends StatefulWidget {
  final String title;
  final String? subtitle;

  const _PinEntryDialog({required this.title, this.subtitle});

  @override
  State<_PinEntryDialog> createState() => _PinEntryDialogState();
}

class _PinEntryDialogState extends State<_PinEntryDialog> {
  String _pin = '';

  void _appendDigit(String digit) {
    if (_pin.length >= pinLength) return;
    setState(() => _pin += digit);
    if (_pin.length == pinLength) {
      Navigator.of(context).pop(_pin);
    }
  }

  void _backspace() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.subtitle != null && widget.subtitle!.isNotEmpty) ...[
            Text(widget.subtitle!, style: const TextStyle(color: Colors.grey.shade700)),
            const SizedBox(height: 12),
          ],
          PinPad(
            length: pinLength,
            filledCount: _pin.length,
            onDigit: _appendDigit,
            onBackspace: _backspace,
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
      ],
    );
  }
}
