import 'product.dart';

class CartItem {
  final Product product;
  double quantity;

  CartItem({required this.product, this.quantity = 1});

  double get subtotal => product.price * quantity;
}
