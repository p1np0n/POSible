import 'dart:async';

import 'package:flutter/foundation.dart';

import '../config/current_store.dart';
import '../models/product.dart';
import '../services/local_cache_service.dart';
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
///
/// Además queda guardado en el celular (ver [LocalCacheService]): la
/// primera vez que se entra a Ventas en la sesión, se muestra de inmediato
/// lo que había guardado de la última vez (aunque no haya internet
/// todavía) mientras de fondo se pide la versión real al servidor — así la
/// app abre con algo que mostrar incluso sin conexión, y se pone al día
/// sola apenas la haya.
class ProductCacheProvider extends ChangeNotifier {
  final ProductRepository _repository = ProductRepository();

  List<Product> products = [];
  bool loading = false;
  String? error;
  bool _loaded = false;

  String get _cacheKey => 'product_cache_v1_${CurrentStore.id ?? "sin_tienda"}';

  /// Pide el catálogo solo si todavía no se había cargado en esta sesión
  /// (o si el intento anterior falló) — llamarlo repetidas veces (ej. cada
  /// vez que se entra a Ventas) no genera pedidos de más.
  Future<void> ensureLoaded() async {
    if (_loaded || loading) return;
    // Antes de pedirle nada al servidor, muestra de inmediato lo que ya
    // había guardado del catálogo la última vez que se pudo — así Ventas
    // no aparece vacía ni "cargando" mientras se espera la red, y sigue
    // sirviendo aunque no haya internet en este momento.
    final cached = await LocalCacheService.loadList(_cacheKey);
    if (cached != null && cached.isNotEmpty && products.isEmpty) {
      try {
        products = cached.map(Product.fromMap).toList();
        notifyListeners();
      } catch (_) {
        // Caché de un formato viejo/dañado — se ignora, sigue con la red.
      }
    }
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
      _persistToDisk();
    } catch (e) {
      // Sin internet (u otro error de red): si ya se estaba mostrando el
      // catálogo guardado (ver ensureLoaded), se sigue mostrando ese en
      // vez de un error — mejor un catálogo desactualizado que ninguno.
      // Solo se muestra el error si no había nada que mostrar.
      if (products.isEmpty) {
        error = '$e';
      } else {
        _loaded = true;
      }
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
    _persistToDisk();
  }

  /// Saca un producto de la lista en memoria (ej. al archivarlo — mismo
  /// criterio que [ProductRepository.getAll], que ya excluye los
  /// archivados del catálogo).
  void removeLocal(String id) {
    products = products.where((p) => p.id != id).toList();
    notifyListeners();
    _persistToDisk();
  }

  /// Guarda el catálogo actual en el celular, para que un cambio puntual
  /// (subir stock, editar un precio) también quede reflejado la próxima
  /// vez que la app abra sin internet — no solo lo que trajo el último
  /// [refresh] completo.
  void _persistToDisk() {
    unawaited(LocalCacheService.saveList(_cacheKey, products.map((p) => p.toJson()).toList()));
  }
}
