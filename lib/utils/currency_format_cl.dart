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
