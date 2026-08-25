import 'package:flutter/material.dart';

/// Popup con un teclado numérico propio de la app, en vez del teclado del
/// dispositivo, para ingresar precios, cantidades y montos — el teclado del
/// celular puede tapar el resto de la pantalla (o partes de un popup) al
/// abrirse; este teclado es parte del layout, así que nunca tapa nada.
///
/// [allowDecimal]: los precios en CLP no llevan decimales, pero el stock de
/// un producto por peso sí (ej. 0.482 kg) — se activa según corresponda.
/// [minValue]: si se da, "Aceptar" queda deshabilitado hasta que el número
/// escrito sea mayor o igual (ej. un precio no puede ser 0).
Future<double?> showNumberPadDialog(
  BuildContext context, {
  required String title,
  double? initialValue,
  bool allowDecimal = false,
  String prefixText = '',
  double? minValue,
}) {
  return showDialog<double>(
    context: context,
    builder: (_) => _NumberPadDialog(
      title: title,
      initialValue: initialValue,
      allowDecimal: allowDecimal,
      prefixText: prefixText,
      minValue: minValue,
    ),
  );
}

class _NumberPadDialog extends StatefulWidget {
  final String title;
  final double? initialValue;
  final bool allowDecimal;
  final String prefixText;
  final double? minValue;

  const _NumberPadDialog({
    required this.title,
    this.initialValue,
    required this.allowDecimal,
    required this.prefixText,
    this.minValue,
  });

  @override
  State<_NumberPadDialog> createState() => _NumberPadDialogState();
}

class _NumberPadDialogState extends State<_NumberPadDialog> {
  late String _text;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialValue;
    if (initial == null || initial == 0) {
      _text = '';
    } else if (widget.allowDecimal) {
      var s = initial.toStringAsFixed(3);
      s = s.replaceFirst(RegExp(r'0+$'), '');
      s = s.replaceFirst(RegExp(r'\.$'), '');
      _text = s;
    } else {
      _text = initial.round().toString();
    }
  }

  void _tapDigit(String digit) {
    if (_text.length >= 12) return;
    setState(() => _text += digit);
  }

  void _tapDecimal() {
    if (!widget.allowDecimal || _text.contains('.')) return;
    setState(() => _text = _text.isEmpty ? '0.' : '$_text.');
  }

  void _backspace() {
    if (_text.isEmpty) return;
    setState(() => _text = _text.substring(0, _text.length - 1));
  }

  void _clear() => setState(() => _text = '');

  double? get _value => double.tryParse(_text);

  bool get _isValid {
    final value = _value;
    if (value == null) return false;
    if (widget.minValue != null && value < widget.minValue!) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Expanded(child: Text(widget.title, overflow: TextOverflow.ellipsis)),
          IconButton(
            icon: const Icon(Icons.backspace_outlined),
            tooltip: 'Borrar',
            onPressed: _backspace,
          ),
        ],
      ),
      content: SizedBox(
        width: 280,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.centerRight,
              child: Text(
                '${widget.prefixText}${_text.isEmpty ? '0' : _text}',
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            const SizedBox(height: 16),
            _keypadRow(['1', '2', '3']),
            const SizedBox(height: 8),
            _keypadRow(['4', '5', '6']),
            const SizedBox(height: 8),
            _keypadRow(['7', '8', '9']),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: widget.allowDecimal
                      ? _keyButton('.', onTap: _tapDecimal)
                      : const SizedBox(height: 52),
                ),
                const SizedBox(width: 8),
                Expanded(child: _keyButton('0', onTap: () => _tapDigit('0'))),
                const SizedBox(width: 8),
                const Expanded(child: SizedBox(height: 52)),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _text.isEmpty ? null : _clear, child: const Text('Borrar todo')),
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton(
          onPressed: _isValid ? () => Navigator.of(context).pop(_value) : null,
          child: const Text('Aceptar'),
        ),
      ],
    );
  }

  Widget _keypadRow(List<String> digits) {
    return Row(
      children: [
        for (var i = 0; i < digits.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: _keyButton(digits[i], onTap: () => _tapDigit(digits[i]))),
        ],
      ],
    );
  }

  Widget _keyButton(String label, {required VoidCallback onTap}) {
    return SizedBox(
      height: 52,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
        child: Text(label, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
