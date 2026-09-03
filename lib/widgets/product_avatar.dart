import 'package:flutter/material.dart';

/// Paleta fija de tintes pastel (fondo claro + texto saturado del mismo
/// tono) para el avatar cuando el producto no tiene foto — como una
/// vitrina con etiquetas de color, en vez de un círculo sólido con
/// iniciales blancas. Deliberadamente sin naranja/rojo, para no
/// confundirse con el color de marca ni con los `StatusBadge` de
/// "Agotado"/"Inventario bajo".
const _palette = [
  (bg: Color(0xFFE6ECFB), fg: Color(0xFF3F51B5)),
  (bg: Color(0xFFDDF3EE), fg: Color(0xFF00695C)),
  (bg: Color(0xFFF1E3F7), fg: Color(0xFF7B1FA2)),
  (bg: Color(0xFFEFE3DC), fg: Color(0xFF5D4037)),
  (bg: Color(0xFFDCF0F3), fg: Color(0xFF00838F)),
  (bg: Color(0xFFEAF3DD), fg: Color(0xFF558B2F)),
  (bg: Color(0xFFF3E6DC), fg: Color(0xFF6D4C41)),
  (bg: Color(0xFFE3E8EC), fg: Color(0xFF455A64)),
];

({Color bg, Color fg}) _colorFor(String seed) => _palette[seed.hashCode.abs() % _palette.length];

String _initialsFor(String name) {
  final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return '?';
  if (words.length == 1) return words.first.substring(0, 1).toUpperCase();
  return (words.first.substring(0, 1) + words[1].substring(0, 1)).toUpperCase();
}

/// Avatar de producto: foto si tiene (`imageUrl`), o si no, un círculo de
/// color con las iniciales del nombre — reemplaza el círculo gris vacío
/// que se veía como un placeholder sin terminar cuando no hay foto.
class ProductAvatar extends StatelessWidget {
  final String name;
  final String? categoryId;
  final String? imageUrl;
  final double radius;

  const ProductAvatar({
    super.key,
    required this.name,
    this.categoryId,
    this.imageUrl,
    this.radius = 28,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;
    if (hasImage) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(imageUrl!),
        onBackgroundImageError: (_, __) {},
        child: null,
      );
    }
    final seed = (categoryId != null && categoryId!.isNotEmpty) ? categoryId! : name;
    final colors = _colorFor(seed);
    return CircleAvatar(
      radius: radius,
      backgroundColor: colors.bg,
      child: Text(
        _initialsFor(name),
        style: TextStyle(color: colors.fg, fontWeight: FontWeight.bold, fontSize: radius * 0.6),
      ),
    );
  }
}
