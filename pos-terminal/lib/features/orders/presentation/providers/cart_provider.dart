import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../menu/domain/entities/product.dart';
import '../../domain/entities/cart.dart';

/// Bir nechta ochiq buyurtma (Zakaz - 1, Zakaz - 2, ...). `state` — hozir
/// tanlangan (aktiv) savat. Barcha o'qiydiganlar aynan aktiv savatni ko'radi;
/// tab'lar (soni/aktiv indeks) uchun [cartTabsVersionProvider] kuzatiladi.
class CartNotifier extends StateNotifier<Cart> {
  CartNotifier(this._ref) : super(const Cart()) {
    // Vizual tekshiruv uchun (--dart-define=DEBUG_SEED_CART=true). Prod'da o'chiq.
    if (const bool.fromEnvironment('DEBUG_SEED_CART')) {
      _orders[0] = const Cart(items: [
        CartItem(name: 'Margarita Pizza', price: 45000, qty: 2),
        CartItem(name: 'KFC (kg)', price: 85000, qty: 0.5, soldByWeight: true),
        CartItem(name: 'Coca-Cola 0.5L', price: 9000, qty: 1),
      ]);
      state = _orders[0];
    }
  }

  final Ref _ref;
  final List<Cart> _orders = [const Cart()];
  int _active = 0;

  int get orderCount => _orders.length;
  int get activeOrder => _active;

  void _bumpTabs() => _ref.read(cartTabsVersionProvider.notifier).state++;

  void _apply(Cart c) {
    _orders[_active] = c;
    state = c;
  }

  void addProduct(Product product, {String? label, num qty = 1}) =>
      _apply(state.addProduct(product, label: label, qty: qty));
  void increment(int index) => _apply(state.increment(index));
  void decrement(int index) => _apply(state.decrement(index));
  void setQty(int index, num qty) => _apply(state.setQty(index, qty));
  void removeAt(int index) => _apply(state.removeAt(index));
  void setDiscount(num value) => _apply(state.setDiscount(value));

  /// Aktiv buyurtmani tozalaydi (to'lovdan keyin).
  void clear() => _apply(const Cart());

  /// Yangi buyurtma qo'shib, unga o'tadi.
  void newOrder() {
    _orders.add(const Cart());
    _active = _orders.length - 1;
    state = _orders[_active];
    _bumpTabs();
  }

  /// Boshqa buyurtmaga o'tish.
  void switchOrder(int index) {
    if (index < 0 || index >= _orders.length || index == _active) return;
    _active = index;
    state = _orders[_active];
    _bumpTabs();
  }

  /// Buyurtma tab'ini yopish (kamida bittasi qoladi).
  void closeOrder(int index) {
    if (_orders.length <= 1 || index < 0 || index >= _orders.length) return;
    _orders.removeAt(index);
    if (_active >= _orders.length) _active = _orders.length - 1;
    state = _orders[_active];
    _bumpTabs();
  }

  /// To'lov yakunlangach: tab bir nechta bo'lsa aktivini YOPADI (kassir F7
  /// bilan ochgan qo'shimcha zakaz to'langach o'zi yo'qoladi), yagona tab
  /// bo'lsa shunchaki tozalanadi.
  void finishActiveOrder() {
    if (_orders.length > 1) {
      closeOrder(_active);
    } else {
      clear();
    }
  }
}

final cartProvider =
    StateNotifierProvider<CartNotifier, Cart>((ref) => CartNotifier(ref));

/// Zakaz tab'lari o'zgarganда (qo'shildi/o'chdi/almashdi) oshiriladi.
final cartTabsVersionProvider = StateProvider<int>((ref) => 0);
