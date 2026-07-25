import 'package:aiba_pos_terminal/core/utils/money.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Money.parse', () {
    test('parses backend decimal strings', () {
      expect(Money.parse('12000.00'), 12000);
      expect(Money.parse('8000'), 8000);
    });

    test('parses numbers as-is', () {
      expect(Money.parse(5000), 5000);
      expect(Money.parse(1250.5), 1250.5);
    });

    test('null and empty are zero', () {
      expect(Money.parse(null), 0);
      expect(Money.parse(''), 0);
      expect(Money.parse('not-a-number'), 0);
    });
  });

  group('Money.format', () {
    test('groups thousands with spaces', () {
      expect(Money.format(1250000), '1 250 000');
      expect(Money.format(0), '0');
      expect(Money.format(999), '999');
      expect(Money.format(1000), '1 000');
    });

    test('handles negatives (e.g. discount line)', () {
      expect(Money.format(-5000), '-5 000');
    });

    test('formatSom adds the suffix', () {
      expect(Money.formatSom(25000), "25 000 so'm");
    });
  });
}
