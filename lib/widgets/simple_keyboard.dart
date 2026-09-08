import 'package:flutter/material.dart';

/// Teclado propio de la app, en pantalla, para escribir texto (buscar
/// productos, clientes, etc.) sin depender del teclado del celular — ese es
/// el que suele dar problemas (se abre y cierra solo, tapa la pantalla, o
/// deja el foco en un estado raro cuando hay un lector de código de barras
/// USB conectado). Solo minúsculas y números, sin tildes ni "ñ": la
/// búsqueda de la app ya ignora tildes y mayúsculas, así que no hacen
/// falta.
///
/// IMPORTANTE: este teclado no reemplaza al lector USB. El campo de texto
/// al que va conectado sigue siendo un TextField editable de verdad — el
/// lector (que funciona como un teclado físico) le sigue escribiendo
/// directo, sin pasar por este widget. Este teclado solo se encarga de lo
/// que pasa cuando la persona toca la pantalla a mano; para eso el campo de
/// texto debe llevar `keyboardType: TextInputType.none` (evita que Android
/// abra su propio teclado encima del nuestro), no `readOnly` (eso sí
/// bloquearía también al lector USB).
class SimpleKeyboard extends StatelessWidget {
  final TextEditingController controller;

  /// Se llama después de cada tecla (letra, número, espacio o borrar), con
  /// el texto ya actualizado — para que la búsqueda se filtre en vivo igual
  /// que si se estuviera escribiendo con un teclado normal.
  final ValueChanged<String>? onChanged;

  /// Se llama al tocar "Listo", con el texto final — antes de que el
  /// teclado se cierre. Pensado para lo mismo que pasaría al apretar Enter
  /// en un teclado normal (ej. revisar si lo escrito es un código de
  /// barras).
  final ValueChanged<String>? onDone;

  const SimpleKeyboard({super.key, required this.controller, this.onChanged, this.onDone});

  static const _numberRow = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'];
  static const _rowOne = ['q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p'];
  static const _rowTwo = ['a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l'];
  static const _rowThree = ['z', 'x', 'c', 'v', 'b', 'n', 'm'];

  void _type(String s) {
    final newText = controller.text + s;
    controller.value = TextEditingValue(text: newText, selection: TextSelection.collapsed(offset: newText.length));
    onChanged?.call(newText);
  }

  void _backspace() {
    final text = controller.text;
    if (text.isEmpty) return;
    final newText = text.substring(0, text.length - 1);
    controller.value = TextEditingValue(text: newText, selection: TextSelection.collapsed(offset: newText.length));
    onChanged?.call(newText);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 12,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 6, 4, 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _keyRow(_numberRow),
              const SizedBox(height: 6),
              _keyRow(_rowOne),
              const SizedBox(height: 6),
              _keyRow(_rowTwo),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(flex: 2, child: _key(icon: Icons.backspace_outlined, onTap: _backspace)),
                  for (final letter in _rowThree) ...[
                    const SizedBox(width: 4),
                    Expanded(child: _key(label: letter, onTap: () => _type(letter))),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(flex: 5, child: _key(label: 'espacio', onTap: () => _type(' '))),
                  const SizedBox(width: 4),
                  Expanded(
                    flex: 3,
                    child: SizedBox(
                      height: 44,
                      child: FilledButton(
                        onPressed: () => onDone?.call(controller.text),
                        style: FilledButton.styleFrom(padding: EdgeInsets.zero),
                        child: const Text('Listo'),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _keyRow(List<String> keys) {
    return Row(
      children: [
        for (var i = 0; i < keys.length; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Expanded(child: _key(label: keys[i], onTap: () => _type(keys[i]))),
        ],
      ],
    );
  }

  Widget _key({String? label, IconData? icon, required VoidCallback onTap}) {
    return SizedBox(
      height: 44,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(padding: EdgeInsets.zero, backgroundColor: Colors.white),
        child: icon != null
            ? Icon(icon, size: 18)
            : Text(label!, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
