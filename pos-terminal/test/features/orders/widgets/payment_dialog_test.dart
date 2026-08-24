import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aiba_pos_terminal/features/orders/domain/entities/payment_method.dart';
import 'package:aiba_pos_terminal/features/orders/presentation/widgets/payment_dialog.dart';

/// To'lov oynasi: ortiq summa kiritilsa QAYTIM ko'rinishi va kam summa
/// kiritilsa BO'LIB TO'LASH ochilishi. Ikkisi ham "maydonga yozganda oyna
/// qayta chizilmaydi" xatosidan keyin qo'shildi — regressiya bo'lmasin.
void main() {
  Future<void> open(WidgetTester tester, num total, PaymentMethod m) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => PaymentDialog.show(context, total, initialMethod: m),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('ortiq summa kiritilsa qaytim ko\'rsatiladi (kartada ham)',
      (tester) async {
    await open(tester, 45600, PaymentMethod.card);
    expect(find.textContaining('Qaytim'), findsNothing);

    await tester.enterText(find.byType(TextField), '50000');
    await tester.pump();

    expect(find.textContaining('Qaytim'), findsOneWidget);
    expect(find.text('4 400 so\'m'), findsOneWidget);
  });

  testWidgets('naqdda ham qaytim hisoblanadi', (tester) async {
    await open(tester, 12000, PaymentMethod.cash);
    await tester.enterText(find.byType(TextField), '20000');
    await tester.pump();
    expect(find.text('8 000 so\'m'), findsOneWidget);
  });

  testWidgets('kam summa kiritilsa bo\'lib to\'lash ochiladi', (tester) async {
    await open(tester, 45600, PaymentMethod.card);
    await tester.enterText(find.byType(TextField), '20000');
    await tester.pump();

    // Tugma matni kiritilgan qism va qolgan summani ko'rsatadi.
    expect(find.textContaining("Bo'lib to'lash: 20 000 so'm"), findsOneWidget);

    await tester.tap(find.textContaining("Bo'lib to'lash:"));
    await tester.pumpAndSettle();

    // Sarlavha "Bo'lib to'lash: {qoldi}" ga o'tadi va qoldi ko'rinadi.
    expect(find.textContaining("Bo'lib to'lash: 25 600 so'm"), findsOneWidget);
    expect(find.text('Qoldi:'), findsOneWidget);
  });
}
