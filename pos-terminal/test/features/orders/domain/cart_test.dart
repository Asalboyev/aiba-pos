import 'package:aiba_pos_terminal/features/menu/domain/entities/product.dart';
import 'package:aiba_pos_terminal/features/orders/domain/entities/cart.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const burger = Product(id: 'p1', name: 'Burger', price: 25000);
  const cola = Product(id: 'p2', name: 'Cola', price: 8000);

  group('Cart totals', () {
    test('empty cart has zero subtotal, total and count', () {
      const cart = Cart();
      expect(cart.subtotal, 0);
      expect(cart.total, 0);
      expect(cart.itemCount, 0);
      expect(cart.isEmpty, isTrue);
    });

    test('adding a product creates one line with qty 1', () {
      final cart = const Cart().addProduct(burger);
      expect(cart.items.length, 1);
      expect(cart.items.first.qty, 1);
      expect(cart.subtotal, 25000);
      expect(cart.itemCount, 1);
    });

    test('adding the same product twice merges into qty 2', () {
      final cart = const Cart().addProduct(burger).addProduct(burger);
      expect(cart.items.length, 1);
      expect(cart.items.first.qty, 2);
      expect(cart.subtotal, 50000);
      // itemCount — QATORLAR soni (qty yig'indisi emas): tarozili mahsulotда
      // qty kasrli bo'ladi (1.5 kg), "1.5 ta mahsulot" xunuk chiqadi.
      expect(cart.itemCount, 1);
    });

    test('subtotal sums line totals across products', () {
      final cart = const Cart()
          .addProduct(burger) // 25000
          .addProduct(cola) // 8000
          .addProduct(cola); // +8000
      expect(cart.subtotal, 25000 + 8000 + 8000);
      expect(cart.itemCount, 2); // 2 qator: burger + cola(qty 2)
    });

    test('increment and decrement adjust quantity', () {
      var cart = const Cart().addProduct(burger);
      cart = cart.increment(0);
      expect(cart.items.first.qty, 2);
      cart = cart.decrement(0);
      expect(cart.items.first.qty, 1);
    });

    // Savatdan o'chirish YO'Q (nazorat talabi): miqdor 0 ga tushsa qator
    // O'CHMAYDI — minimal 1 da qoladi. Bekor qilish faqat F9 (xato chek).
    test('decrementing to zero KEEPS the line at qty 1', () {
      var cart = const Cart().addProduct(burger);
      cart = cart.decrement(0);
      expect(cart.items.length, 1);
      expect(cart.items.first.qty, 1);
    });

    test('setQty to 0 KEEPS the line at qty 1', () {
      var cart = const Cart().addProduct(cola);
      cart = cart.setQty(0, 0);
      expect(cart.items.length, 1);
      expect(cart.items.first.qty, 1);
    });

    test('removeAt removes the correct line', () {
      var cart = const Cart().addProduct(burger).addProduct(cola);
      cart = cart.removeAt(0);
      expect(cart.items.length, 1);
      expect(cart.items.first.name, 'Cola');
    });
  });

  group('Cart discount', () {
    test('total subtracts discount', () {
      final cart =
          const Cart().addProduct(burger).addProduct(cola).setDiscount(5000);
      expect(cart.subtotal, 33000);
      expect(cart.total, 28000);
    });

    test('discount is clamped to subtotal (total never negative)', () {
      final cart = const Cart().addProduct(cola).setDiscount(999999);
      expect(cart.discount, 8000); // clamped to subtotal
      expect(cart.total, 0);
    });

    test('negative discount is clamped to zero', () {
      final cart = const Cart().addProduct(burger).setDiscount(-100);
      expect(cart.discount, 0);
      expect(cart.total, 25000);
    });
  });

  group('Cart immutability', () {
    test('operations return new instances, original unchanged', () {
      const original = Cart();
      final modified = original.addProduct(burger);
      expect(original.isEmpty, isTrue);
      expect(modified.isEmpty, isFalse);
    });

    test('out-of-range index operations are no-ops', () {
      final cart = const Cart().addProduct(burger);
      expect(cart.increment(5), cart);
      expect(cart.decrement(-1), cart);
      expect(cart.removeAt(99), cart);
      expect(cart.setQty(3, 2), cart);
    });
  });
}
