import 'package:flutter/foundation.dart';

import '../models/cart_item.dart';
import '../models/customer.dart';
import '../models/discount.dart';
import '../models/modifier.dart';
import '../models/product.dart';

class CartProvider extends ChangeNotifier {
  final List<CartItem> _items = [];
  Customer? _selectedCustomer;
  Discount? _selectedDiscount;

  List<CartItem> get items => List.unmodifiable(_items);

  double get total => _items.fold(0, (sum, item) => sum + item.subtotal);

  int get itemCount => _items.fold(0, (sum, item) => sum + item.quantity.toInt());

  Customer? get selectedCustomer => _selectedCustomer;
  Discount? get selectedDiscount => _selectedDiscount;

  void setCustomer(Customer? customer) {
    _selectedCustomer = customer;
    notifyListeners();
  }

  void setDiscount(Discount? discount) {
    _selectedDiscount = discount;
    notifyListeners();
  }

  void addProduct(Product product, {List<Modifier> modifiers = const []}) {
    final index = _items.indexWhere(
      (item) => item.product.id == product.id && item.hasSameModifiers(modifiers),
    );
    if (index >= 0) {
      _items[index].quantity += 1;
    } else {
      _items.add(CartItem(product: product, modifiers: modifiers));
    }
    notifyListeners();
  }

  void incrementItem(CartItem item) {
    final index = _items.indexOf(item);
    if (index >= 0) {
      _items[index].quantity += 1;
      notifyListeners();
    }
  }

  void decrementItem(CartItem item) {
    final index = _items.indexOf(item);
    if (index >= 0) {
      if (_items[index].quantity > 1) {
        _items[index].quantity -= 1;
      } else {
        _items.removeAt(index);
      }
      notifyListeners();
    }
  }

  void removeItem(CartItem item) {
    _items.remove(item);
    notifyListeners();
  }

  void clear() {
    _items.clear();
    _selectedCustomer = null;
    _selectedDiscount = null;
    notifyListeners();
  }

  /// Reemplaza el carrito actual por estas líneas (ej. al retomar un ticket
  /// que se había dejado en espera).
  void loadItems(List<CartItem> items, {Customer? customer, Discount? discount}) {
    _items
      ..clear()
      ..addAll(items);
    _selectedCustomer = customer;
    _selectedDiscount = discount;
    notifyListeners();
  }
}
