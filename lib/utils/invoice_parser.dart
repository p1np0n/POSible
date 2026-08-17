/// Una línea de artículo detectada dentro del texto de una factura.
class InvoiceLine {
  String name;
  double quantity;

  InvoiceLine({required this.name, required this.quantity});
}

final _noiseWords = [
  'total',
  'subtotal',
  'iva',
  'factura',
  'boleta',
  'fecha',
  'rut',
  'giro',
  'folio',
  'cliente',
  'vendedor',
  'forma de pago',
  'neto',
  'descuento',
  'cajero',
  'gracias',
];

final _quantityAtStart = RegExp(r'^(\d{1,4})\s*[xX]?\s+(.+)$');
final _trailingNumbers = RegExp(r'[\$]?\s*[\d]{1,3}(?:[.,]\d{3})*(?:[.,]\d{1,2})?\s*$');

/// Intenta separar el texto reconocido por OCR en líneas de "cantidad +
/// nombre de artículo". Es una aproximación (no entiende el formato exacto
/// de cada factura), pensada para revisar y corregir a mano antes de
/// aplicarla al inventario — nunca para confiar en ella a ciegas.
List<InvoiceLine> parseInvoiceText(String text) {
  final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
  final results = <InvoiceLine>[];

  for (final line in lines) {
    if (line.length < 3) continue;
    final lower = line.toLowerCase();
    if (_noiseWords.any((w) => lower.contains(w))) continue;
    // Una línea que es solo números (ej. un RUT o un total suelto) no es
    // un artículo.
    if (RegExp(r'^[\d.,\-\s]+$').hasMatch(line)) continue;

    double quantity = 1;
    String name = line;

    final startMatch = _quantityAtStart.firstMatch(line);
    if (startMatch != null) {
      final q = int.tryParse(startMatch.group(1)!);
      if (q != null && q > 0 && q < 1000) {
        quantity = q.toDouble();
        name = startMatch.group(2)!.trim();
      }
    }

    // Le quita precios/montos que suelen venir al final de la línea (ej.
    // "Coca cola 1.5L $1.500" -> "Coca cola 1.5L").
    name = name.replaceAll(_trailingNumbers, '').trim();
    name = name.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
    if (name.length < 3) continue;

    results.add(InvoiceLine(name: name, quantity: quantity));
  }
  return results;
}
