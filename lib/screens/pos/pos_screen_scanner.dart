part of 'pos_screen.dart';

/// Todo lo relacionado con leer/interpretar un código de barras en Ventas
/// (código normal, código de balanza, o uno que no coincide con ningún
/// producto) — separado de pos_screen.dart para que ese archivo no
/// tuviera que cargar también con esta parte. Al ser un "part of" de la
/// misma librería, sigue teniendo acceso directo a los campos y métodos
/// privados de _PosScreenState (_products, _searchIndex, _addToCart,
/// etc.), exactamente igual que si este código siguiera en el mismo
/// archivo — no cambia ningún comportamiento, solo dónde vive el texto.
extension _PosScreenScannerX on _PosScreenState {
  /// Códigos de balanza (peso variable): 13 dígitos que empiezan con "2".
  /// Dígitos 2-6: código PLU del producto. Dígitos 7-11: peso en gramos. El
  /// último dígito es de control (no se valida). Devuelve null si "code" no
  /// tiene esa forma (no es un código de balanza).
  ({String plu, double weightKg})? _decodeWeightBarcode(String code) {
    if (code.length != 13 || !code.startsWith('2') || int.tryParse(code) == null) return null;
    final plu = code.substring(1, 6);
    final grams = int.tryParse(code.substring(6, 11));
    if (grams == null) return null;
    return (plu: plu, weightKg: grams / 1000);
  }

  /// Si "code" es un código de balanza, busca el producto por PLU y lo
  /// agrega al carrito con el peso escaneado. Devuelve true si "code" se
  /// reconoció como código de balanza (se haya encontrado el producto o
  /// no), para que quien llama no lo trate además como una búsqueda normal.
  Future<bool> _tryAddWeightBarcode(String code) async {
    final decoded = _decodeWeightBarcode(code);
    if (decoded == null) return false;
    final product = _searchIndex.byPlu(decoded.plu);
    if (!mounted) return true;
    if (product == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No hay ningún producto por peso con el código ${decoded.plu}')),
      );
      return true;
    }
    if (!context.read<CashSessionProvider>().isOpen) return true;
    context.read<CartProvider>().addVariableItem(product, quantity: decoded.weightKg);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Agregado: ${product.name} (${decoded.weightKg.toStringAsFixed(3)} kg)')),
    );
    return true;
  }

  /// Si "code" coincide exactamente con el código de barras de un producto
  /// (normal, no de balanza), lo agrega de inmediato al carrito — así el
  /// lector de código de barras USB no necesita nada más que este campo
  /// tenga el foco. Devuelve true si "code" coincidió con algún producto,
  /// para que quien llama no lo trate además como una búsqueda de texto.
  Future<bool> _tryAddScannedBarcode(String code) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty) return false;
    final product = _searchIndex.byBarcode(trimmed);
    if (product == null) return false;
    if (!mounted) return true;
    if (!context.read<CashSessionProvider>().isOpen) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Abre la caja antes de vender')),
      );
      return true;
    }
    await _addToCart(product);
    return true;
  }

  /// Un código de barras real es solo dígitos (EAN-13, EAN-8, UPC-A, los
  /// numéricos de balanza, etc.) — se usa para distinguir "esto se escaneó
  /// o se tecleó como código" de una búsqueda de texto común que
  /// simplemente no encontró nada, y así no ofrecer "crear producto" ante
  /// cualquier búsqueda sin resultados.
  bool _looksLikeBarcode(String value) => RegExp(r'^\d{6,}$').hasMatch(value);

  /// Maneja lo que llega al buscador (visible o el campo invisible del
  /// lector USB) al presionar Enter — el lector manda el código y un Enter
  /// automático, así que esto es lo que hace que escanear agregue el
  /// producto solo, sin tocar la pantalla. Si el código tiene forma de
  /// código de barras pero no coincide con ningún producto, ofrece crearlo
  /// al toque (ver _offerCreateProductForBarcode).
  Future<void> _handleScanSubmit(String value) async {
    final handled = await _tryAddWeightBarcode(value) || await _tryAddScannedBarcode(value);
    final trimmed = value.trim();
    if (handled || _looksLikeBarcode(trimmed)) {
      if (mounted) {
        _localFilterDebounce?.cancel();
        _searchController.clear();
        setState(() => _search = '');
      }
    }
    if (!handled && _looksLikeBarcode(trimmed) && mounted) {
      await _offerCreateProductForBarcode(trimmed);
    }
    _refocusSearch();
  }

  /// Avisa que no existe ningún producto con ese código de barras y ofrece
  /// crearlo al toque, sin tener que ir a Lista de artículos ni escanear
  /// una segunda vez.
  Future<void> _offerCreateProductForBarcode(String barcode) async {
    final create = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Artículo no encontrado'),
        content: Text('No hay ningún producto con el código de barras $barcode.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cerrar')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Agregar producto')),
        ],
      ),
    );
    if (create == true && mounted) {
      await _quickCreateProductFromBarcode(barcode);
    }
  }

  /// Crea el producto con el código de barras ya escaneado (pidiendo solo
  /// nombre y precio, lo mínimo para poder cobrarlo) y lo agrega de
  /// inmediato al carrito — así el flujo completo (escanear algo que no
  /// existe → crearlo → venderlo) no necesita una segunda pasada.
  Future<void> _quickCreateProductFromBarcode(String barcode) async {
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    Future<void> pickPrice(StateSetter setState) async {
      final price = await showNumberPadDialog(
        context,
        title: 'Precio',
        initialValue: double.tryParse(priceController.text),
        prefixText: '\$',
        minValue: 1,
      );
      if (price != null) setState(() => priceController.text = price.round().toString());
    }

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Agregar artículo nuevo'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Código de barras: $barcode', style: TextStyle(color: const Color(0xFF616161))),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Nombre', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: priceController,
                readOnly: true,
                decoration: const InputDecoration(labelText: 'Precio', border: OutlineInputBorder()),
                onTap: () => pickPrice(setState),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Agregar')),
          ],
        ),
      ),
    );
    if (saved != true || !mounted) return;
    final name = nameController.text.trim();
    final price = double.tryParse(priceController.text);
    if (name.isEmpty || price == null || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa un nombre y un precio válido')),
      );
      return;
    }
    if (!context.read<CashSessionProvider>().isOpen) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Abre la caja antes de vender')),
      );
      return;
    }
    try {
      final created = await _productRepository.create(Product(
        id: '',
        name: name,
        price: price,
        stockQuantity: 0,
        trackStock: false,
        active: true,
        barcode: barcode,
      ));
      if (!mounted) return;
      setState(() {
        _products = _sortedByName([..._products, created]);
        _searchIndex = ProductSearchIndex(_products);
      });
      context.read<ProductCacheProvider>().upsertLocal(created);
      try {
        await _catalogRepository.upsert(barcode: barcode, name: name, suggestedPrice: price, source: 'store');
      } catch (_) {
        // Aporte al catálogo global es "mejor esfuerzo" — el producto ya
        // quedó guardado en el inventario propio de todas formas.
      }
      await _addToCart(created);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al crear el producto: $e')));
      }
    }
  }

  Future<void> _scanBarcode() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (code != null && mounted) {
      final handled = await _tryAddWeightBarcode(code) || await _tryAddScannedBarcode(code);
      if (!handled && mounted) {
        _localFilterDebounce?.cancel();
        _searchController.text = code;
        setState(() => _search = code);
      }
    }
    _refocusSearch();
  }
}
