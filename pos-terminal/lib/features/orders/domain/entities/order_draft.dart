import 'package:equatable/equatable.dart';

import 'cart.dart';
import 'payment_method.dart';

/// A finalized cart ready to be saved as an order. Carries the idempotency
/// [clientUuid] so the same checkout can be re-sent safely.
class OrderDraft extends Equatable {
  final String clientUuid;
  final List<CartItem> items;
  final num discount;
  final List<Payment> payments;
  final String? tableNo;
  final String? note;

  /// Terminal-generated daily order number (e.g. "T1-7") — assigned at
  /// checkout so the receipt always has one, online or offline.
  final String? number;

  const OrderDraft({
    required this.clientUuid,
    required this.items,
    required this.discount,
    required this.payments,
    this.tableNo,
    this.note,
    this.number,
  });

  num get subtotal => items.fold<num>(0, (s, i) => s + i.lineTotal);
  num get total {
    final t = subtotal - discount;
    return t < 0 ? 0 : t;
  }

  @override
  List<Object?> get props =>
      [clientUuid, items, discount, payments, tableNo, note, number];
}
