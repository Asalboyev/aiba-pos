import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aiba_pos_terminal/core/providers/core_providers.dart';
import 'package:aiba_pos_terminal/features/auth/presentation/screens/login_screen.dart';

// Kichik kassa/noutbuk ekranlarida login paneli TO'LIQ ko'rinishi kerak —
// avval 0/backspace qatori kesilib qolardi (overflow yoki scroll ostida).
void main() {
  Future<void> pumpAt(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const MaterialApp(home: LoginScreen()),
      ),
    );
    await tester.pump();
  }

  for (final size in const [Size(1024, 600), Size(1366, 700), Size(800, 560)]) {
    testWidgets('login ${size.width.toInt()}x${size.height.toInt()}: '
        'overflow yo\'q, 0 va backspace ko\'rinadi', (tester) async {
      await pumpAt(tester, size);
      // RenderFlex overflow bo'lsa takeException qaytaradi.
      expect(tester.takeException(), isNull);
      // Klaviaturaning pastki qatori ekranда to'liq ichkarida.
      final zero = find.text('0');
      expect(zero, findsOneWidget);
      final rect = tester.getRect(zero);
      expect(rect.bottom, lessThanOrEqualTo(size.height));
      expect(find.byIcon(Icons.backspace_outlined), findsOneWidget);
    });
  }
}
