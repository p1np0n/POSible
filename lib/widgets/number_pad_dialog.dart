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
            const SizedBox(height: 12),
            _keypadRow(['1', '2', '3']),
            _keypadRow(['4', '5', '6']),
            _keypadRow(['7', '8', '9']),
            Row(
              children: [
                Expanded(
                  child: widget.allowDecimal
                      ? _keyButton('.', onTap: _tapDecimal)
                      : const SizedBox(height: 64),
                ),
                Expanded(child: _keyButton('0', onTap: () => _tapDigit('0'))),
                const Expanded(child: SizedBox(height: 64)),
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
        for (final digit in digits) Expanded(child: _keyButton(digit, onTap: () => _tapDigit(digit))),
      ],
    );
  }

  /// El botón ocupa todo el ancho y alto de su celda (sin espacios entre
  /// botones que no reaccionen al toque) — el "InkWell" es lo de más
  /// afuera, y el recuadro con borde es solo un relleno visual por dentro,
  /// así tocar cerca del borde de un botón sigue registrando el toque en
  /// vez de perderse en el espacio entre teclas. Más grande que antes
  /// (64px de alto en vez de 52px) para que sea más fácil de acertar.
  Widget _keyButton(String label, {required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Container(
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).colorScheme.outline),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(label, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
          ),
        ),
      ),
    );
  }
}
