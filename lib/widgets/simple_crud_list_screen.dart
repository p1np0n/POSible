import 'package:flutter/material.dart';

import '../utils/search_normalize.dart';
import 'empty_state.dart';
import 'error_state.dart';
import 'loading_indicator.dart';

/// Pantalla genérica de "lista simple con buscador + crear + eliminar",
/// para catálogos chicos y parecidos entre sí (categorías, descuentos,
/// modificadores): antes cada una repetía el mismo buscador, la misma
/// lista con tarjetas, y la misma carga/error/vacío escritos a mano por
/// separado — un cambio de estilo o de comportamiento en una había que
/// repetirlo a mano en las otras. Cada pantalla que use esto solo aporta
/// sus propios textos, su propio diálogo de "nuevo" y sus propias
/// llamadas al repositorio correspondiente.
class SimpleCrudListScreen<T> extends StatefulWidget {
  /// Texto del campo de búsqueda (ej. "Buscar categoría").
  final String searchLabel;

  /// Mensaje y ícono cuando la lista (filtrada) queda vacía.
  final String emptyMessage;
  final IconData emptyIcon;

  /// Texto informativo opcional, arriba del buscador (ej. la explicación
  /// de qué son los modificadores). Si es null, no se muestra nada ahí.
  final String? infoText;

  /// Prefijo del mensaje de error al no poder cargar la lista (se le
  /// agrega ": <detalle>" al final).
  final String loadErrorPrefix;

  /// Pide la lista completa al repositorio correspondiente.
  final Future<List<T>> Function() load;

  /// Muestra el diálogo de "nuevo" (cada pantalla arma el suyo) y, si se
  /// confirmó, llama al repositorio para crearlo — devuelve true si se
  /// creó algo (para recargar la lista), o false si se canceló.
  final Future<bool> Function(BuildContext context) onAdd;

  /// Elimina un elemento ya existente (llama al repositorio).
  final Future<void> Function(T item) onDelete;

  /// Nombre a mostrar de cada elemento — también se usa para buscar.
  final String Function(T item) titleOf;

  /// Texto secundario de cada elemento (ej. el valor de un descuento).
  /// Si es null, la tarjeta no muestra subtítulo.
  final String? Function(T item)? subtitleOf;

  /// Si no es null, cada tarjeta muestra un interruptor de activo/inactivo
  /// a la izquierda — junto con [onToggleActive], que hace el cambio.
  final bool Function(T item)? activeOf;
  final Future<void> Function(T item)? onToggleActive;

  const SimpleCrudListScreen({
    super.key,
    required this.searchLabel,
    required this.emptyMessage,
    required this.emptyIcon,
    this.infoText,
    required this.loadErrorPrefix,
    required this.load,
    required this.onAdd,
    required this.onDelete,
    required this.titleOf,
    this.subtitleOf,
    this.activeOf,
    this.onToggleActive,
  });

  @override
  State<SimpleCrudListScreen<T>> createState() => _SimpleCrudListScreenState<T>();
}

class _SimpleCrudListScreenState<T> extends State<SimpleCrudListScreen<T>> {
  List<T> _items = [];
  bool _loading = true;
  String? _error;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await widget.load();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '${widget.loadErrorPrefix}: $e';
        _loading = false;
      });
    }
  }

  List<T> get _filtered => _items
      .where((item) =>
          _search.isEmpty || normalizeForSearch(widget.titleOf(item)).contains(normalizeForSearch(_search)))
      .toList();

  Future<void> _add() async {
    try {
      final added = await widget.onAdd(context);
      if (added) _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo crear: $e')));
      }
    }
  }

  Future<void> _delete(T item) async {
    try {
      await widget.onDelete(item);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo eliminar: $e')));
      }
    }
  }

  Future<void> _toggleActive(T item) async {
    final onToggleActive = widget.onToggleActive;
    if (onToggleActive == null) return;
    try {
      await onToggleActive(item);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo actualizar: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return RefreshIndicator(
      onRefresh: _load,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.infoText != null) ...[
                  Text(widget.infoText!, style: const TextStyle(color: Color(0xFF616161))),
                  const SizedBox(height: 12),
                ],
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          labelText: widget.searchLabel,
                          prefixIcon: const Icon(Icons.search),
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (value) => setState(() => _search = value),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: _add,
                      icon: const Icon(Icons.add),
                      label: const Text('Nuevo'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const LoadingIndicator()
                : _error != null
                    ? ErrorState(message: _error!, onRetry: _load)
                    : filtered.isEmpty
                        ? EmptyState(message: widget.emptyMessage, icon: widget.emptyIcon)
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final item = filtered[index];
                              final subtitle = widget.subtitleOf?.call(item);
                              return Card(
                                child: ListTile(
                                  title: Text(widget.titleOf(item)),
                                  subtitle: subtitle == null ? null : Text(subtitle),
                                  leading: widget.activeOf == null
                                      ? null
                                      : Switch(
                                          value: widget.activeOf!(item),
                                          onChanged: (_) => _toggleActive(item),
                                        ),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () => _delete(item),
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
