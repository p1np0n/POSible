import '../models/product.dart';
import '../utils/search_normalize.dart';

/// Índice local del catálogo de Ventas: normaliza el texto buscable de cada
/// producto (nombre + código de barras + SKU) UNA sola vez al armar el
/// índice, en vez de cada vez que se escribe una letra — con miles de
/// productos, recalcular tildes/mayúsculas de todo el catálogo en cada tecla
/// se notaba lento. También arma mapas directos por código de barras y por
/// PLU (balanza), para que un escaneo encuentre el producto al instante en
/// vez de recorrer todo el catálogo uno por uno.
class ProductSearchIndex {
  ProductSearchIndex(List<Product> products)
      : _entries = [for (final p in products) (product: p, text: _searchableText(p))],
        _byBarcode = {
          for (final p in products)
            if (p.barcode != null && p.barcode!.isNotEmpty) p.barcode!: p,
        },
        _byPlu = {
          for (final p in products)
            if (p.isSoldByWeight && p.plu != null && p.plu!.isNotEmpty) p.plu!: p,
        };

  final List<({Product product, String text})> _entries;
  final Map<String, Product> _byBarcode;
  final Map<String, Product> _byPlu;

  static String _searchableText(Product p) {
    final parts = <String>[p.name];
    if (p.barcode != null) parts.add(p.barcode!);
    if (p.sku != null) parts.add(p.sku!);
    return normalizeForSearch(parts.join(' '));
  }

  /// Producto con ese código de barras exacto, o null. O(1): para que un
  /// lector de código de barras (USB o cámara) agregue el producto al toque
  /// aunque el catálogo tenga miles de artículos.
  Product? byBarcode(String code) => _byBarcode[code];

  /// Producto por peso con ese código PLU (de un código de balanza), o null.
  Product? byPlu(String plu) => _byPlu[plu];

  /// Productos cuyo nombre, código de barras o SKU contiene "query" (sin
  /// tildes ni mayúsculas) — usa el texto ya normalizado del índice, no
  /// vuelve a normalizar cada producto en cada búsqueda.
  List<Product> search(String query) {
    final q = normalizeForSearch(query);
    if (q.isEmpty) return [for (final e in _entries) e.product];
    return [for (final e in _entries) if (e.text.contains(q)) e.product];
  }
}
