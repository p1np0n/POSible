import 'package:flutter/material.dart';

/// Paleta fija para el color de fondo del avatar cuando el producto no
/// tiene foto — deliberadamente sin naranja/rojo, para no confundirse con
/// el color de marca ni con los `StatusBadge` de "Agotado"/"Inventario
/// bajo".
const _palette = [
  Color(0xFF3F51B5),
  Color(0xFF00897B),
  Color(0xFF7B1FA2),
  Color(0xFF5D4037),
  Color(0xFF00838F),
  Color(0xFF558B2F),
  Color(0xFF6D4C41),
  Color(0xFF455A64),
];

Color _colorFor(String seed) => _palette[seed.hashCode.abs() % _palette.length];

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
    return CircleAvatar(
      radius: radius,
      backgroundColor: _colorFor(seed),
      child: Text(
        _initialsFor(name),
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: radius * 0.6),
      ),
    );
  }
}
