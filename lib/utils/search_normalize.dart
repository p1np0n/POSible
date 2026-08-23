const Map<String, String> _accentedToPlain = {
  'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a',
  'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e',
  'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i',
  'ó': 'o', 'ò': 'o', 'ö': 'o', 'ô': 'o',
  'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u',
  'ñ': 'n',
};

/// Pasa a minúsculas y saca tildes/diéresis, para que buscar "cafe" o
/// "café" encuentre lo mismo. Se usa siempre de los dos lados de una
/// comparación de búsqueda (tanto en lo que escribe el usuario como en el
/// nombre/código del producto).
String normalizeForSearch(String value) {
  final lower = value.toLowerCase();
  final buffer = StringBuffer();
  for (final unit in lower.split('')) {
    buffer.write(_accentedToPlain[unit] ?? unit);
  }
  return buffer.toString();
}
