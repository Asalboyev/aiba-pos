import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../menu/domain/entities/product.dart';
import '../../domain/entities/cart.dart';

/// Holds the live cart for the POS sale screen.
class CartNotifier extends StateNotifier<Cart> {
  CartNotifier() : super(const Cart());

  void addProduct(Product product, {String? label}) =>
      state = state.addProduct(product, label: label);
  void increment(int index) => state = state.increment(index);
  void decrement(int index) => state = state.decrement(index);
  void setQty(int index, num qty) => state = state.setQty(index, qty);
  void removeAt(int index) => state = state.removeAt(index);
  void setDiscount(num value) => state = state.setDiscount(value);
  void clear() => state = state.clear();
}

final cartProvider =
    StateNotifierProvider<CartNotifier, Cart>((ref) => CartNotifier());
