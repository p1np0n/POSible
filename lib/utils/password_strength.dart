/// Valida que una contraseña sea razonablemente fuerte — letras combinadas
/// con números o símbolos, largo mínimo — para la cuenta del
/// administrador (su login completo, correo + contraseña). A diferencia
/// del PIN de 4 dígitos (corto, aparte, para el acceso rápido), esta es
/// la contraseña real de la cuenta.
///
/// Devuelve el mensaje de error a mostrar, o null si la contraseña sirve.
String? validateStrongPassword(String? value, {int minLength = 8}) {
  if (value == null || value.isEmpty) return 'Ingresa una contraseña';
  if (value.length < minLength) return 'Mínimo $minLength caracteres';
  final hasLetter = RegExp(r'[a-zA-Z]').hasMatch(value);
  final hasDigitOrSymbol = RegExp(r'[0-9\W_]').hasMatch(value);
  if (!hasLetter || !hasDigitOrSymbol) {
    return 'Combina letras con números o símbolos';
  }
  return null;
}
