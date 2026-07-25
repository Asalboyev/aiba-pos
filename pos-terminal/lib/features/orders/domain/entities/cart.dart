import 'package:equatable/equatable.dart';

import '../../../menu/domain/entities/product.dart';

/// A single line in the cart. [productId] is null for ad-hoc/manual items.
class CartItem extends Equatable {
  final String? productId;
  final String name;
  final num price;
  final int qty;
  final String? mxikCode;
  final String? packageCode;
  final num? vatPercent;
  final bool markingRequired;
  /// Har dona uchun bitta DataMatrix (qty ga teng bo'lishi kerak).
  /// Har chek qatori 1 birlik sifatida E-POS'ga jo'natilgani sabab, hozircha
  /// birinchi label ishlatiladi; kelajakda qty > 1 bo'lsa har dona uchun
  /// alohida qator ochish mumkin.
  final List<String> labels;

  const CartItem({
    this.productId,
    required this.name,
    required this.price,
    required this.qty,
    this.mxikCode,
    this.packageCode,
    this.vatPercent,
    this.markingRequired = false,
    this.labels = const [],
  });

  /// Line total = price × qty.
  num get lineTotal => price * qty;

  bool get needsMoreLabels => markingRequired && labels.length < qty;

  CartItem copyWith({int? qty, List<String>? labels}) => CartItem(
        productId: productId,
        name: name,
        price: price,
        qty: qty ?? this.qty,
        mxikCode: mxikCode,
        packageCode: packageCode,
        vatPercent: vatPercent,
        markingRequired: markingRequired,
        labels: labels ?? this.labels,
      );

  factory CartItem.fromProduct(Product p, {int qty = 1, List<String>? labels}) => CartItem(
        productId: p.id,
        name: p.name,
        price: p.price,
        qty: qty,
        mxikCode: p.mxikCode,
        packageCode: p.packageCode,
        vatPercent: p.vatPercent,
        markingRequired: p.markingRequired,
        labels: labels ?? const [],
      );

  @override
  List<Object?> get props => [
        productId, name, price, qty, mxikCode, packageCode,
        vatPercent, markingRequired, labels,
      ];
}

/// The shopping cart. Pure value object — all total math lives here so it can
/// be unit tested without any Flutter/Riverpod dependency.
class Cart extends Equatable {
  final List<CartItem> items;
  final num discount;

  const Cart({this.items = const [], this.discount = 0});

  /// Sum of all line totals before discount.
  num get subtotal =>
      items.fold<num>(0, (sum, item) => sum + item.lineTotal);

  /// Total after discount, never negative.
  num get total {
    final t = subtotal - discount;
    return t < 0 ? 0 : t;
  }

  int get itemCount => items.fold<int>(0, (sum, item) => sum + item.qty);

  bool get isEmpty => items.isEmpty;

  /// Add a product, merging quantity if a line for the same product exists.
  /// [label] — DataMatrix code (markirovka mahsulotlar uchun). Har chaqirishda
  /// yangi label ro'yxatga qo'shiladi (har dona uchun bittadan bo'lishi kerak).
  Cart addProduct(Product product, {String? label}) {
    final idx = items.indexWhere((i) => i.productId == product.id);
    final next = [...items];
    if (idx >= 0) {
      final cur = next[idx];
      final newLabels = label != null ? [...cur.labels, label] : cur.labels;
      next[idx] = cur.copyWith(qty: cur.qty + 1, labels: newLabels);
    } else {
      final labels = label != null ? [label] : const <String>[];
      next.add(CartItem.fromProduct(product, labels: labels));
    }
    return copyWith(items: next);
  }

  /// Set the quantity of the line at [index]. Quantities <= 0 remove the line.
  Cart setQty(int index, int qty) {
    if (index < 0 || index >= items.length) return this;
    final next = [...items];
    if (qty <= 0) {
      next.removeAt(index);
    } else {
      next[index] = next[index].copyWith(qty: qty);
    }
    return copyWith(items: next);
  }

  Cart increment(int index) =>
      index < 0 || index >= items.length ? this : setQty(index, items[index].qty + 1);

  Cart decrement(int index) =>
      index < 0 || index >= items.length ? this : setQty(index, items[index].qty - 1);

  Cart removeAt(int index) {
    if (index < 0 || index >= items.length) return this;
    final next = [...items]..removeAt(index);
    return copyWith(items: next);
  }

  /// Discount is clamped to [0, subtotal].
  Cart setDiscount(num value) {
    final clamped = value < 0 ? 0 : (value > subtotal ? subtotal : value);
    return copyWith(discount: clamped);
  }

  Cart clear() => const Cart();

  Cart copyWith({List<CartItem>? items, num? discount}) =>
      Cart(items: items ?? this.items, discount: discount ?? this.discount);

  @override
  List<Object?> get props => [items, discount];
}
