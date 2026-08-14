import 'modifier.dart';
import 'product.dart';

class CartItem {
  final Product product;
  double quantity;
  final List<Modifier> modifiers;

  CartItem({required this.product, this.quantity = 1, this.modifiers = const []});

  double get modifiersAdjustment => modifiers.fold(0, (sum, m) => sum + m.priceAdjustment);

  double get unitPrice => product.price + modifiersAdjustment;

  double get subtotal => unitPrice * quantity;

  String get modifiersLabel => modifiers.map((m) => m.name).join(', ');

  bool hasSameModifiers(List<Modifier> other) {
    if (modifiers.length != other.length) return false;
    final ids = modifiers.map((m) => m.id).toSet();
    return other.every((m) => ids.contains(m.id));
  }
}
