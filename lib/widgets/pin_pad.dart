import 'package:flutter/material.dart';

/// Cantidad de dígitos del PIN en toda la app (login rápido y bloqueo
/// automático). El PIN es, por dentro, la contraseña de Supabase, que por
/// defecto exige mínimo 6 caracteres — 8 queda cómodamente por encima sin
/// tener que tocar la configuración de Supabase.
const int pinLength = 8;

/// Teclado numérico + indicador de dígitos escritos, reutilizado en la
/// pantalla de login con PIN y en la de bloqueo automático.
class PinPad extends StatelessWidget {
  final int length;
  final int filledCount;
  final bool loading;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  const PinPad({
    super.key,
    required this.length,
    required this.filledCount,
    required this.onDigit,
    required this.onBackspace,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget key(String label, {VoidCallback? onTap, Widget? child}) {
      return Expanded(
        child: AspectRatio(
          aspectRatio: 1.4,
          child: TextButton(
            onPressed: loading ? null : onTap,
            child: child ?? Text(label, style: const TextStyle(fontSize: 22)),
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(length, (i) {
            final filled = i < filledCount;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 6),
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: filled ? Theme.of(context).colorScheme.primary : Colors.transparent,
                border: Border.all(color: Theme.of(context).colorScheme.primary),
              ),
            );
          }),
        ),
        const SizedBox(height: 16),
        Row(children: [
          key('1', onTap: () => onDigit('1')),
          key('2', onTap: () => onDigit('2')),
          key('3', onTap: () => onDigit('3')),
        ]),
        Row(children: [
          key('4', onTap: () => onDigit('4')),
          key('5', onTap: () => onDigit('5')),
          key('6', onTap: () => onDigit('6')),
        ]),
        Row(children: [
          key('7', onTap: () => onDigit('7')),
          key('8', onTap: () => onDigit('8')),
          key('9', onTap: () => onDigit('9')),
        ]),
        Row(children: [
          key('', onTap: null),
          key('0', onTap: () => onDigit('0')),
          key('Despejar', onTap: onBackspace, child: const Icon(Icons.backspace_outlined)),
        ]),
      ],
    );
  }
}
