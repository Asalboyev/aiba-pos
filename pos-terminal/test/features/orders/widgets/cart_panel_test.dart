import 'package:aiba_pos_terminal/features/menu/domain/entities/product.dart';
import 'package:aiba_pos_terminal/features/orders/domain/entities/cart.dart';
import 'package:aiba_pos_terminal/features/orders/presentation/providers/cart_provider.dart';
import 'package:aiba_pos_terminal/features/orders/presentation/widgets/cart_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('CartPanel shows item count and formatted total', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // Seed the cart: 2 burgers @ 25 000 = 50 000.
    container.read(cartProvider.notifier)
      ..addProduct(const Product(id: 'p1', name: 'Burger', price: 25000))
      ..addProduct(const Product(id: 'p1', name: 'Burger', price: 25000));

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: CartPanel(onCheckout: () {}),
          ),
        ),
      ),
    );

    expect(find.text('Savat (2)'), findsOneWidget);
    expect(find.text('Burger'), findsOneWidget);
    // The total appears in the checkout button label.
    expect(find.textContaining('50 000'), findsWidgets);
  });

  testWidgets('checkout button is disabled for an empty cart', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(body: CartPanel(onCheckout: () {})),
        ),
      ),
    );

    expect(find.text("Savat bo'sh"), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.byType(FilledButton),
    );
    expect(button.onPressed, isNull);
  });

  test('cartProvider total reflects added products minus discount', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(cartProvider.notifier)
      ..addProduct(const Product(id: 'p1', name: 'A', price: 10000))
      ..addProduct(const Product(id: 'p2', name: 'B', price: 5000))
      ..setDiscount(2000);
    final Cart cart = container.read(cartProvider);
    expect(cart.subtotal, 15000);
    expect(cart.total, 13000);
  });
}
