import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../models/product.dart';
import '../../providers/cash_session_provider.dart';
import '../../utils/currency_format_cl.dart';
import '../../widgets/currency_text.dart';
import '../../widgets/product_avatar.dart';
import '../../widgets/status_badge.dart';

/// Ancho aproximado de cada mosaico de producto — a partir de esto se
/// calculan cuántas columnas caben según el ancho real de la pantalla
/// (da mosaicos chicos, unos 5x5 visibles a la vez en una tablet, como se
/// pidió, para ver más productos sin desplazarse).
const double _targetTileWidth = 120.0;

/// Muestra los productos filtrados de Ventas, como mosaico (vitrina, con
/// foto) o como lista simple, según [useListLayout] — extraído de
/// PosScreen para que ese archivo no tuviera que cargar también con todo
/// el dibujo del mosaico. No guarda ningún estado propio: todo lo que
/// necesita (qué pestaña está activa, qué hacer al tocar un producto,
/// etc.) llega por parámetro desde PosScreen, que sigue siendo el único
/// dueño de esos datos.
class PosProductBrowser extends StatelessWidget {
  final List<Product> products;
  final bool useListLayout;
  final CashSessionProvider cashSession;
  final String? selectedPageId;
  final void Function(Product product) onAddToCart;
  final void Function(Product product) onEditStock;
  final void Function(Product product) onEditProduct;
  final void Function(String pageId) onQuickAddToPage;

  const PosProductBrowser({
    super.key,
    required this.products,
    required this.useListLayout,
    required this.cashSession,
    required this.selectedPageId,
    required this.onAddToCart,
    required this.onEditStock,
    required this.onEditProduct,
    required this.onQuickAddToPage,
  });

  @override
  Widget build(BuildContext context) {
    return useListLayout ? _buildList() : _buildTileGrid();
  }

  /// Mosaico de productos, parecido a una vitrina: foto de fondo con el
  /// precio arriba y el nombre superpuesto abajo para los que tienen foto,
  /// un círculo gris con precio y nombre para los que no. La cantidad de
  /// columnas se ajusta sola al ancho disponible (unas 5 en una tablet
  /// ancha, menos en un celular). En una pestaña personalizada, mantener
  /// presionado en cualquier parte (o tocar el mosaico "Agregar producto"
  /// al final) abre el buscador para agregar un producto ahí.
  Widget _buildTileGrid() {
    final pageId = selectedPageId;
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = (constraints.maxWidth / _targetTileWidth).floor().clamp(2, 8).toInt();
        final grid = GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.92,
          ),
          itemCount: products.length + (pageId != null ? 1 : 0),
          itemBuilder: (context, index) {
            if (pageId != null && index == products.length) {
              return _addTile(pageId);
            }
            return _buildTile(products[index]);
          },
        );
        if (pageId == null) return grid;
        return GestureDetector(
          onLongPress: () => onQuickAddToPage(pageId),
          child: grid,
        );
      },
    );
  }

  Widget _addTile(String pageId) {
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      color: Colors.grey.shade100,
      child: InkWell(
        onTap: () => onQuickAddToPage(pageId),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_circle_outline, size: 32, color: const Color(0xFF616161)),
              SizedBox(height: 6),
              Text('Agregar\nproducto', textAlign: TextAlign.center, style: TextStyle(color: const Color(0xFF616161), fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTile(Product product) {
    // "Agotado" es solo informativo (el badge de abajo) — se puede seguir
    // vendiendo igual, y el stock queda en negativo (se avisa antes de
    // cobrar, ver _confirmNegativeStock en checkout_sheet.dart).
    final outOfStock = product.trackStock && product.stockQuantity <= 0;
    final hasImage = product.imageUrl != null && product.imageUrl!.isNotEmpty;
    final canTap = cashSession.isOpen;

    return _ProductTile(
      cardColor: hasImage ? null : Colors.grey.shade50,
      onTap: canTap ? () => onAddToCart(product) : null,
      child: hasImage ? _photoTile(product, outOfStock) : _placeholderTile(product, outOfStock),
    );
  }

  Widget _priceLabel(Product product, {bool bold = false, Color? color}) {
    final baseStyle = TextStyle(color: color, fontSize: bold ? 14 : 12);
    if (product.isVariablePrice) {
      return Text('Precio variable', style: baseStyle.copyWith(fontStyle: FontStyle.italic));
    }
    if (product.isSoldByWeight) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CurrencyText(product.price, bold: bold, style: TextStyle(color: color)),
          Text(' /kg', style: baseStyle),
        ],
      );
    }
    if (product.isPromoActive || product.isMarkedDownForExpiry) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            formatCurrencyCl(product.price),
            style: baseStyle.copyWith(fontSize: 11, decoration: TextDecoration.lineThrough),
          ),
          CurrencyText(product.effectivePrice, bold: bold, style: TextStyle(color: color ?? Colors.red)),
        ],
      );
    }
    return CurrencyText(product.price, bold: bold, style: TextStyle(color: color));
  }

  Widget _priceBadge(Product product, {required bool overlay}) {
    final label = _priceLabel(product, bold: true, color: overlay ? Colors.white : Colors.black87);
    if (!overlay) return label;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(6),
      ),
      child: label,
    );
  }

  /// Solo aparece si el producto controla inventario (igual que "Agotado").
  /// Color según estado (verde con stock normal, ámbar con stock bajo, rojo
  /// agotado) — antes era siempre un pill gris/negro sin distinguir estado.
  /// Tocarlo abre el popup para editar el stock — el resto del mosaico
  /// sigue agregando el producto al carrito con normalidad.
  Widget _stockBadge(Product product, {required bool overlay}) {
    if (!product.trackStock) return const SizedBox.shrink();
    final outOfStock = product.stockQuantity <= 0;
    final label = outOfStock
        ? 'Agotado'
        : 'Stock: ${product.isSoldByWeight ? product.stockQuantity.toStringAsFixed(3) : formatNumberCl(product.stockQuantity)}';
    final tone = outOfStock
        ? StatusBadgeTone.danger
        : (product.isLowStock ? StatusBadgeTone.warning : StatusBadgeTone.ok);
    return GestureDetector(
      onTap: () => onEditStock(product),
      child: StatusBadge(label: label, tone: tone, dense: true),
    );
  }

  /// Foto a pantalla completa, precio arriba en una etiqueta y el nombre en
  /// una franja oscura abajo.
  Widget _photoTile(Product product, bool outOfStock) {
    return Stack(
      fit: StackFit.expand,
      children: [
        CachedNetworkImage(
          imageUrl: product.thumbnailUrl ?? product.imageUrl!,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) => Container(color: Colors.grey.shade200),
        ),
        Positioned(
          top: 6,
          left: 6,
          child: _priceBadge(product, overlay: true),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(8, 18, 8, 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withOpacity(0.75)],
              ),
            ),
            child: Text(
              product.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ),
        if (outOfStock)
          Container(
            color: Colors.black.withOpacity(0.55),
            alignment: Alignment.center,
            child: const StatusBadge(label: 'AGOTADO', tone: StatusBadgeTone.danger),
          ),
        Positioned(
          top: 6,
          right: 6,
          child: _stockBadge(product, overlay: true),
        ),
      ],
    );
  }

  /// Sin foto: precio arriba, un círculo gris (como una estantería sin
  /// etiqueta) y el nombre debajo — para que la grilla se vea igual de
  /// ordenada aunque no todos los productos tengan foto todavía.
  Widget _placeholderTile(Product product, bool outOfStock) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _priceBadge(product, overlay: false),
              _stockBadge(product, overlay: false),
            ],
          ),
          Expanded(
            child: Center(
              child: ProductAvatar(name: product.name, categoryId: product.categoryId, radius: 28),
            ),
          ),
          Text(
            product.name,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    return ListView.builder(
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        final outOfStock = product.trackStock && product.stockQuantity <= 0;
        return ListTile(
          leading: ProductAvatar(
            name: product.name,
            categoryId: product.categoryId,
            imageUrl: product.thumbnailUrl ?? product.imageUrl,
          ),
          title: Text(product.name, maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: !product.trackStock
              ? null
              : Align(
                  alignment: Alignment.centerLeft,
                  child: outOfStock
                      ? const StatusBadge(label: 'Agotado', tone: StatusBadgeTone.danger, dense: true)
                      : Text('Stock: ${formatNumberCl(product.stockQuantity)}'),
                ),
          // Íconos aparte para editar stock y el artículo completo (en vez
          // de que el texto chico de arriba fuera el único lugar para
          // tocar, que costaba acertar) — el resto de la fila sigue
          // agregando el producto al carrito.
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _priceLabel(product, bold: true),
              if (product.trackStock)
                IconButton(
                  icon: const Icon(Icons.inventory_2_outlined, size: 20),
                  tooltip: 'Editar stock',
                  onPressed: () => onEditStock(product),
                ),
              if (!product.isQuickItem)
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  tooltip: 'Editar artículo',
                  onPressed: () => onEditProduct(product),
                ),
            ],
          ),
          enabled: cashSession.isOpen,
          onTap: () => onAddToCart(product),
        );
      },
    );
  }
}

/// Envuelve un mosaico de producto para dar un feedback breve (rebote +
/// ícono de check) al tocarlo y agregarlo al carrito, en vez de que el
/// único cambio visible sea en el panel del carrito (que puede quedar
/// fuera de foco en pantallas angostas).
class _ProductTile extends StatefulWidget {
  final Widget child;
  final Color? cardColor;
  final VoidCallback? onTap;

  const _ProductTile({required this.child, required this.cardColor, required this.onTap});

  @override
  State<_ProductTile> createState() => _ProductTileState();
}

class _ProductTileState extends State<_ProductTile> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _checkOpacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 260));
    _scale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.94), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 0.94, end: 1.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _checkOpacity = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 2),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    final onTap = widget.onTap;
    if (onTap == null) return;
    onTap();
    _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Transform.scale(
          scale: _scale.value,
          child: Card(
            clipBehavior: Clip.antiAlias,
            margin: EdgeInsets.zero,
            color: widget.cardColor,
            child: Stack(
              fit: StackFit.expand,
              children: [
                InkWell(onTap: widget.onTap == null ? null : _handleTap, child: widget.child),
                if (_checkOpacity.value > 0)
                  IgnorePointer(
                    child: Opacity(
                      opacity: _checkOpacity.value,
                      child: Container(
                        color: Colors.black.withOpacity(0.25),
                        alignment: Alignment.center,
                        child: const Icon(Icons.check_circle, color: Colors.white, size: 40),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
