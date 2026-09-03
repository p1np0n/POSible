import 'package:flutter/foundation.dart';

import '../models/product.dart';
import '../services/product_repository.dart';

/// Catálogo de productos compartido entre Ventas y Movimientos de stock.
///
/// Antes cada una de esas pantallas pedía el catálogo completo cada vez
/// que se seleccionaba — la app no reutiliza pantallas entre pestañas del
/// menú, así que cambiar de Ventas a Turno y volver bajaba TODO el
/// catálogo de nuevo, gastando ancho de banda de más con cada cambio de
/// pestaña. Ahora se pide una sola vez por sesión y se mantiene en
/// memoria; [refresh] lo vuelve a pedir a mano (botón "Actualizar
/// catálogo" en Ventas y en Movimientos de stock) — no hay refresco
/// automático por tiempo, a propósito, para no gastar ancho de banda solo
/// por tener la pantalla abierta.
class ProductCacheProvider extends ChangeNotifier {
  final ProductRepository _repository = ProductRepository();

  List<Product> products = [];
  bool loading = false;
  String? error;
  bool _loaded = false;

  /// Pide el catálogo solo si todavía no se había cargado en esta sesión
  /// (o si el intento anterior falló) — llamarlo repetidas veces (ej. cada
  /// vez que se entra a Ventas) no genera pedidos de más.
  Future<void> ensureLoaded() async {
    if (_loaded || loading) return;
    await refresh();
  }

  /// Vuelve a pedir el catálogo completo al servidor, sin importar si ya
  /// se había cargado antes — la llama a mano el botón "Actualizar
  /// catálogo", o el flujo de crear/editar un producto completo (ahí sí
  /// hace falta ver el cambio reflejado al toque).
  Future<void> refresh() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      products = await _repository.getAll();
      _loaded = true;
    } catch (e) {
      error = '$e';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Agrega o reemplaza un producto en memoria (ej. tras ajustar su stock,
  /// editar su precio, o agregar uno nuevo) sin tener que volver a pedir
  /// todo el catálogo — así una acción puntual no cuesta ancho de banda de
  /// más, y las demás pantallas que usan este mismo catálogo ven el
  /// cambio al toque.
  void upsertLocal(Product product) {
    final index = products.indexWhere((p) => p.id == product.id);
    final updated = [...products];
    if (index >= 0) {
      updated[index] = product;
    } else {
      updated.add(product);
    }
    updated.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    products = updated;
    notifyListeners();
  }

  /// Saca un producto de la lista en memoria (ej. al archivarlo — mismo
  /// criterio que [ProductRepository.getAll], que ya excluye los
  /// archivados del catálogo).
  void removeLocal(String id) {
    products = products.where((p) => p.id != id).toList();
    notifyListeners();
  }
}
