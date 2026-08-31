/// Formatea un monto como peso chileno: sin decimales y con punto como
/// separador de miles (ej. 1234567 -> "$1.234.567").
String formatCurrencyCl(num amount) {
  final rounded = amount.round();
  final isNegative = rounded < 0;
  final digits = rounded.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
    buffer.write(digits[i]);
  }
  return '${isNegative ? '-' : ''}\$$buffer';
}

/// Igual que [formatCurrencyCl] pero sin el símbolo "$" — para cantidades,
/// stock, puntos, unidades vendidas, etc. (ej. 1234 -> "1.234"). Con
/// [decimals] > 0 conserva esos decimales usando coma, al estilo chileno
/// (ej. formatNumberCl(1234.5, decimals: 1) -> "1.234,5").
String formatNumberCl(num value, {int decimals = 0}) {
  final isNegative = value < 0;
  final abs = value.abs();
  final text = decimals == 0 ? abs.round().toString() : abs.toStringAsFixed(decimals);
  final parts = text.split('.');
  final digits = parts[0];
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
    buffer.write(digits[i]);
  }
  if (parts.length > 1) buffer.write(',${parts[1]}');
  return '${isNegative ? '-' : ''}$buffer';
}

/// Redondea un precio sugerido a la decena más cercana, usando 6 como
/// punto de corte en vez del 5 habitual: si el último dígito es 6 o más
/// sube a la decena de arriba, si es 5 o menos baja a la de abajo (ej.
/// 1235 -> 1230, 1236 -> 1240). Se usa en la calculadora de precios
/// (costo + margen) de Lista de artículos.
int roundPriceCl(double price) {
  final rounded = price.round();
  final remainder = rounded % 10;
  final base = rounded - remainder;
  return remainder >= 6 ? base + 10 : base;
}
