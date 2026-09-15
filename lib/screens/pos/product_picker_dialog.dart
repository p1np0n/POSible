import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../models/product.dart';
import '../../services/product_repository.dart';

/// Diálogo simple para buscar y elegir un producto — usado para agregarlo a
/// una pestaña personalizada de Ventas.
///
/// Busca directo en el servidor (igual que "Lista de artículos") en vez de
/// filtrar la lista de productos ya cargada en la pantalla de Ventas: así
/// siempre ve el catálogo al día, aunque se haya agregado un producto nuevo
/// desde otra pantalla sin volver a entrar a Ventas.
class ProductPickerDialog extends StatefulWidget {
  final ProductRepository productRepository;

  const ProductPickerDialog({super.key, required this.productRepository});

  @override
  State<ProductPickerDialog> createState() => _ProductPickerDialogState();
}

class _ProductPickerDialogState extends State<ProductPickerDialog> {
  final _controller = TextEditingController();
  List<Product> _results = [];
  bool _loading = true;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search(String term) async {
    final requestId = ++_requestId;
    setState(() => _loading = true);
    final results = await widget.productRepository.getPage(offset: 0, pageSize: 30, search: term.trim());
    if (!mounted || requestId != _requestId) return;
    setState(() {
      _results = results;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Buscar producto para agregar'),
      content: SizedBox(
        width: 400,
        height: 400,
        child: Column(
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Buscar producto o código',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: _search,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _results.isEmpty
                      ? const Center(child: Text('Sin resultados'))
                      : ListView.builder(
                          itemCount: _results.length,
                          itemBuilder: (context, index) {
                            final p = _results[index];
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundImage: (p.thumbnailUrl ?? p.imageUrl) != null
                                    ? CachedNetworkImageProvider((p.thumbnailUrl ?? p.imageUrl)!)
                                    : null,
                                child: p.imageUrl == null ? const Icon(Icons.inventory_2, size: 18) : null,
                              ),
                              title: Text(p.name),
                              onTap: () => Navigator.of(context).pop(p),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
      ],
    );
  }
}
