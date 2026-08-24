import 'package:aiba_pos_terminal/core/providers/core_providers.dart';
import 'package:aiba_pos_terminal/features/menu/domain/entities/product.dart';
import 'package:aiba_pos_terminal/features/orders/domain/entities/cart.dart';
import 'package:aiba_pos_terminal/features/orders/domain/entities/payment_method.dart';
import 'package:aiba_pos_terminal/features/orders/presentation/providers/cart_provider.dart';
import 'package:aiba_pos_terminal/features/orders/presentation/widgets/cart_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // CartPanel appConfig (rasm URL'lari) uchun SharedPreferences'ni o'qiydi.
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  ProviderContainer makeContainer() => ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
  /// Savat paneli Figma dizaynida: mahsulot soni, jami summa va to'lov
  /// tugmalari (Karta F4 / Naqd F5 / Keldi-ketdi F6 / QR F3).
  testWidgets('CartPanel shows item count and formatted total', (tester) async {
    final container = makeContainer();
    addTearDown(container.dispose);

    // Savatga 2 ta burger @ 25 000 = 50 000.
    container.read(cartProvider.notifier)
      ..addProduct(const Product(id: 'p1', name: 'Burger', price: 25000))
      ..addProduct(const Product(id: 'p1', name: 'Burger', price: 25000));

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: CartPanel(onCheckout: (_) {}),
          ),
        ),
      ),
    );

    expect(find.text('Burger'), findsOneWidget);
    expect(find.textContaining('ta mahsulot'), findsOneWidget);
    expect(find.textContaining('50 000'), findsWidgets);
  });

  testWidgets('bo\'sh savatda to\'lov bosilmaydi', (tester) async {
    final container = makeContainer();
    addTearDown(container.dispose);

    PaymentMethod? tapped;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(body: CartPanel(onCheckout: (m) => tapped = m)),
        ),
      ),
    );

    expect(find.text("Savatcha hozircha bo'sh"), findsOneWidget);
    // Karta tugmasini bosamiz — savat bo'sh, callback chaqirilmasligi kerak.
    await tester.tap(find.text('Karta'), warnIfMissed: false);
    await tester.pump();
    expect(tapped, isNull);
  });

  testWidgets('to\'lov usuli callbackga uzatiladi', (tester) async {
    final container = makeContainer();
    addTearDown(container.dispose);
    container
        .read(cartProvider.notifier)
        .addProduct(const Product(id: 'p1', name: 'Burger', price: 25000));

    PaymentMethod? tapped;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(body: CartPanel(onCheckout: (m) => tapped = m)),
        ),
      ),
    );

    await tester.tap(find.text('Naqd'));
    await tester.pump();
    expect(tapped, PaymentMethod.cash);

    await tester.tap(find.text('QR'));
    await tester.pump();
    expect(tapped, PaymentMethod.qr);
  });

  test('cartProvider total reflects added products minus discount', () {
    final container = makeContainer();
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
