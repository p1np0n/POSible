import 'package:flutter/material.dart';

import '../../models/pos_page.dart';

/// Pestañas de acceso rápido (Más vendidos + pestañas personalizadas,
/// creadas a mano por el usuario con cualquier artículo que quiera para
/// venta rápida — no son categorías) en su propia barra al final de la
/// pantalla de Ventas, cerca de donde se toca para vender. No guarda
/// ningún estado propio — PosScreen sigue siendo el dueño de cuál pestaña
/// está activa.
class PosQuickSaleBar extends StatelessWidget {
  final bool showTopSelling;
  final List<PosPage> pages;
  final String? selectedPageId;
  final VoidCallback onSelectTopSelling;
  final void Function(PosPage page) onSelectPage;
  final VoidCallback onCreatePage;
  final void Function(PosPage page) onManagePage;

  const PosQuickSaleBar({
    super.key,
    required this.showTopSelling,
    required this.pages,
    required this.selectedPageId,
    required this.onSelectTopSelling,
    required this.onSelectPage,
    required this.onCreatePage,
    required this.onManagePage,
  });

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 4,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          // Fijas (sin scroll horizontal): todas las pestañas se reparten el
          // ancho disponible con Expanded, y el texto de cada una se achica
          // solo si hace falta (FittedBox dentro de _quickTabButton) para
          // que quepan siempre, aunque se agreguen muchas.
          child: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: _quickTabButton(
                        context,
                        label: 'Más vendidos',
                        icon: Icons.trending_up,
                        selected: showTopSelling,
                        onTap: () {
                          // Siempre tiene que haber una pestaña elegida — si
                          // "Más vendidos" ya está activa, tocarla de nuevo
                          // no hace nada (no existe un estado "ninguna
                          // pestaña" que muestre todo el catálogo de una).
                          if (showTopSelling) return;
                          onSelectTopSelling();
                        },
                      ),
                    ),
                    for (final page in pages) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: _quickTabButton(
                          context,
                          label: page.name,
                          selected: selectedPageId == page.id,
                          onTap: () {
                            if (selectedPageId == page.id) return;
                            onSelectPage(page);
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: Icon(Icons.add_circle_outline, color: onSurface),
                tooltip: 'Crear pestaña',
                onPressed: onCreatePage,
              ),
              if (selectedPageId != null)
                IconButton(
                  icon: Icon(Icons.settings_outlined, color: onSurface),
                  tooltip: 'Editar esta pestaña',
                  onPressed: () {
                    final page = pages.where((p) => p.id == selectedPageId);
                    if (page.isNotEmpty) onManagePage(page.first);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Botón cuadrado (esquinas apenas redondeadas, no en píldora) y más
  /// grande que un Chip normal de Material — para que "Más vendidos" y cada
  /// pestaña personalizada sean fáciles de tocar y de leer de un vistazo
  /// mientras se vende. Ocupa el ancho que le da el Expanded del que
  /// cuelga — con FittedBox el texto se achica solo en vez de cortarse con
  /// "..." cuando hay muchas pestañas y cada una queda angosta.
  Widget _quickTabButton(
    BuildContext context, {
    required String label,
    IconData? icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final bg = selected ? colorScheme.primary : colorScheme.surfaceContainerHighest;
    final fg = selected ? colorScheme.onPrimary : colorScheme.onSurface;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        constraints: const BoxConstraints(minHeight: 60),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: selected ? null : Border.all(color: colorScheme.outlineVariant),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20, color: fg),
              const SizedBox(height: 4),
            ],
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 14),
                textAlign: TextAlign.center,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
