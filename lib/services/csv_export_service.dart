import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';

import '../models/category.dart';
import '../models/product.dart';

class CsvExportService {
  Future<void> exportProducts(List<Product> products, List<Category> categories) async {
    String categoryName(String? id) {
      if (id == null) return '';
      final match = categories.where((c) => c.id == id);
      return match.isEmpty ? '' : match.first.name;
    }

    final rows = <List<dynamic>>[
      [
        'Nombre',
        'Categoría',
        'Precio',
        'Costo',
        'SKU',
        'Código de barras',
        'Stock',
        'Controla inventario',
        'Umbral inventario bajo',
      ],
      ...products.map((p) => [
            p.name,
            categoryName(p.categoryId),
            p.price,
            p.cost ?? '',
            p.sku ?? '',
            p.barcode ?? '',
            p.trackStock ? p.stockQuantity : '',
            p.trackStock ? 'si' : 'no',
            p.lowStockThreshold ?? '',
          ]),
    ];

    final csvString = const ListToCsvConverter().convert(rows);
    final bytes = utf8.encode(csvString);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(bytes, mimeType: 'text/csv')],
        fileNameOverrides: ['productos.csv'],
      ),
    );
  }
}
