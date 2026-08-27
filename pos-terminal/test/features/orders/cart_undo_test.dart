import 'package:flutter_test/flutter_test.dart';

import 'package:aiba_pos_terminal/features/orders/domain/entities/cart.dart';

// Savatdan tasodifan o'chirilgan qator QAYTARISH bilan o'z joyiga qaytadi.
void main() {
  test('removeAt + insertAt — undo o\'z joyiga qaytaradi', () {
    const c = Cart(items: [
      CartItem(name: 'Osh', price: 25000, qty: 2),
      CartItem(name: 'Choy', price: 2000, qty: 1),
      CartItem(name: 'Somsa', price: 4000, qty: 3),
    ]);
    final removed = c.items[1];
    final after = c.removeAt(1);
    expect(after.items.length, 2);
    final undone = after.insertAt(1, removed);
    expect(undone.items.length, 3);
    expect(undone.items[1].name, 'Choy');
    expect(undone.items[1].qty, 1);
    // Chegara: indeks oshib ketsa ham yiqilmaydi — oxiriga qo'shadi.
    final tail = after.insertAt(99, removed);
    expect(tail.items.last.name, 'Choy');
  });
}
