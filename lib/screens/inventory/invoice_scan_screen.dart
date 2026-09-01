import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/product.dart';
import '../../services/invoice_ocr_service.dart';
import '../../services/product_repository.dart';
import '../../services/stock_movement_repository.dart';
import '../../utils/currency_format_cl.dart';
import '../../utils/invoice_parser.dart';

enum _InvoiceSource { camera, pdf }

class _InvoiceRow {
  final TextEditingController nameController;
  final TextEditingController qtyController;
  bool include;
  Product? linkedProduct;
  final List<Product> candidates;

  _InvoiceRow({
    required this.nameController,
    required this.qtyController,
    required this.linkedProduct,
    required this.candidates,
    this.include = true,
  });
}

Set<String> _tokens(String s) => s
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9áéíóúñ\s]'), ' ')
    .split(RegExp(r'\s+'))
    .where((t) => t.length >= 3)
    .toSet();

int _similarity(String a, String b) {
  final tokensA = _tokens(a);
  final tokensB = _tokens(b);
  return tokensA.where(tokensB.contains).length;
}

/// Toma una foto de una factura, lee el texto (OCR) y detecta líneas de
/// "cantidad + artículo" (aproximado — hay que revisarlas). Por cada línea
/// deja elegir si suma stock a un producto que ya existe o crea uno nuevo.
/// Nunca aplica nada solo: siempre hay que revisar y tocar "Confirmar".
class InvoiceScanScreen extends StatefulWidget {
  final List<Product> products;

  const InvoiceScanScreen({super.key, required this.products});

  @override
  State<InvoiceScanScreen> createState() => _InvoiceScanScreenState();
}

class _InvoiceScanScreenState extends State<InvoiceScanScreen> {
  final ImagePicker _picker = ImagePicker();
  final InvoiceOcrService _ocrService = InvoiceOcrService();
  final ProductRepository _productRepository = ProductRepository();
  final StockMovementRepository _movementRepository = StockMovementRepository();

  bool _loading = false;
  bool _confirming = false;
  String? _rawText;
  bool _showRawText = false;
  List<_InvoiceRow> _rows = [];

  @override
  void dispose() {
    for (final row in _rows) {
      row.nameController.dispose();
      row.qtyController.dispose();
    }
    super.dispose();
  }

  List<Product> _bestCandidates(String name) {
    final scored = widget.products.map((p) => MapEntry(p, _similarity(name, p.name))).where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return scored.take(5).map((e) => e.key).toList();
  }

  Future<void> _chooseSource() async {
    final source = await showModalBottomSheet<_InvoiceSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Tomar foto'),
              onTap: () => Navigator.of(context).pop(_InvoiceSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const Text('Elegir archivo PDF'),
              onTap: () => Navigator.of(context).pop(_InvoiceSource.pdf),
            ),
          ],
        ),
      ),
    );
    if (source == _InvoiceSource.camera) {
      await _takePhoto();
    } else if (source == _InvoiceSource.pdf) {
      await _pickPdf();
    }
  }

  Future<void> _takePhoto() async {
    final file = await _picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    await _processDocument(bytes, isPdf: false);
  }

  Future<void> _pickPdf() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: false,
    );
    if (files.isEmpty) return;
    Uint8List bytes;
    try {
      bytes = await files.first.readAsBytes();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('No se pudo leer el archivo elegido')));
      }
      return;
    }
    await _processDocument(bytes, isPdf: true);
  }

  Future<void> _processDocument(Uint8List bytes, {required bool isPdf}) async {
    setState(() {
      _loading = true;
      _rows = [];
      _rawText = null;
    });
    try {
      final text = await _ocrService.extractText(bytes, isPdf: isPdf);
      final parsed = parseInvoiceText(text);
      final rows = parsed.map((line) {
        final candidates = _bestCandidates(line.name);
        return _InvoiceRow(
          nameController: TextEditingController(text: line.name),
          qtyController: TextEditingController(text: line.quantity.toStringAsFixed(0)),
          linkedProduct: candidates.isNotEmpty ? candidates.first : null,
          candidates: candidates,
        );
      }).toList();
      if (!mounted) return;
      setState(() {
        _rawText = text;
        _rows = rows;
      });
      if (rows.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No se reconoció ningún artículo. Revisa el texto reconocido abajo.'),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al leer la factura: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirm() async {
    setState(() => _confirming = true);
    var updated = 0;
    var created = 0;
    for (final row in _rows) {
      if (!row.include) continue;
      final quantity = double.tryParse(row.qtyController.text);
      final name = row.nameController.text.trim();
      if (quantity == null || quantity <= 0 || name.isEmpty) continue;
      try {
        if (row.linkedProduct != null) {
          await _productRepository.adjustStock(row.linkedProduct!.id, quantity);
          await _movementRepository.create(
            productId: row.linkedProduct!.id,
            productName: row.linkedProduct!.name,
            type: 'in',
            quantity: quantity,
            note: 'Factura escaneada',
            costAtTime: row.linkedProduct!.cost,
          );
          updated++;
        } else {
          final product = await _productRepository.create(Product(
            id: '',
            name: name,
            price: 0,
            stockQuantity: quantity,
            trackStock: true,
            active: true,
          ));
          await _movementRepository.create(
            productId: product.id,
            productName: product.name,
            type: 'in',
            quantity: quantity,
            note: 'Factura escaneada',
          );
          created++;
        }
      } catch (_) {
        // Si una línea falla, seguimos con las demás — no se pierde el
        // trabajo ya aplicado.
      }
    }
    if (!mounted) return;
    Navigator.of(context).pop({'updated': updated, 'created': created});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Importar factura')),
      body: _loading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Leyendo la factura...'),
                ],
              ),
            )
          : _rows.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey.shade700),
                        const SizedBox(height: 16),
                        const Text(
                          'Toma una foto o elige un PDF de la factura o boleta. Se va a leer el texto y '
                          'tratar de reconocer los artículos y cantidades — siempre revisa antes de confirmar.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: _chooseSource,
                          icon: const Icon(Icons.add_a_photo_outlined),
                          label: const Text('Foto o PDF de la factura'),
                        ),
                        if (_rawText != null) ...[
                          const SizedBox(height: 16),
                          TextButton(
                            onPressed: () => setState(() => _showRawText = !_showRawText),
                            child: const Text('Ver texto reconocido'),
                          ),
                          if (_showRawText)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: SelectableText(_rawText!, style: const TextStyle(fontSize: 12)),
                            ),
                        ],
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      'Revisa nombre y cantidad de cada artículo antes de confirmar. '
                      'Los que no coincidan con nada quedan para crear como producto nuevo (precio \$0, edítalo después).',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    ..._rows.map((row) => Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Checkbox(
                                      value: row.include,
                                      onChanged: (v) => setState(() => row.include = v ?? true),
                                    ),
                                    Expanded(
                                      child: TextField(
                                        controller: row.nameController,
                                        decoration: const InputDecoration(labelText: 'Nombre', isDense: true),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    SizedBox(
                                      width: 70,
                                      child: TextField(
                                        controller: row.qtyController,
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        decoration: const InputDecoration(labelText: 'Cant.', isDense: true),
                                      ),
                                    ),
                                  ],
                                ),
                                DropdownButtonFormField<Product?>(
                                  value: row.linkedProduct,
                                  isExpanded: true,
                                  decoration: const InputDecoration(isDense: true, border: InputBorder.none),
                                  items: [
                                    const DropdownMenuItem(
                                      value: null,
                                      child: Text('Crear producto nuevo', style: TextStyle(fontStyle: FontStyle.italic)),
                                    ),
                                    ...row.candidates.map((p) => DropdownMenuItem(
                                          value: p,
                                          child: Text(
                                            'Sumar a: ${p.name} (stock ${formatNumberCl(p.stockQuantity)})',
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        )),
                                  ],
                                  onChanged: (value) => setState(() => row.linkedProduct = value),
                                ),
                              ],
                            ),
                          ),
                        )),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _confirming ? null : _confirm,
                      child: _confirming
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Confirmar'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => setState(() => _showRawText = !_showRawText),
                      child: const Text('Ver texto reconocido'),
                    ),
                    if (_showRawText)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: SelectableText(_rawText ?? '', style: const TextStyle(fontSize: 12)),
                      ),
                  ],
                ),
    );
  }
}
