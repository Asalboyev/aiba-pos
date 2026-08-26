import 'package:flutter_test/flutter_test.dart';

import 'package:aiba_pos_terminal/features/menu/presentation/providers/menu_providers.dart';

// "kod*miqdor" yozayotganda jonli filtr miqdor qismini tashlab yuborishi
// kerak — aks holda grid bo'shab qolib kassir adashadi (2026-08-26 bugi).
void main() {
  test('searchTermOf — miqdor qismi olib tashlanadi', () {
    expect(searchTermOf('rec*10'), 'rec');
    expect(searchTermOf('rec *10'), 'rec');
    expect(searchTermOf('rec*'), 'rec'); // hali raqam terilmagan
    expect(searchTermOf('3*cola'), 'cola');
    expect(searchTermOf('0.5*kfc'), 'kfc');
    expect(searchTermOf('cola x2'), 'cola');
    expect(searchTermOf('ric'), 'ric'); // oddiy qidiruv o'zgarmaydi
    expect(searchTermOf('124'), '124'); // sof raqam (kod) o'zgarmaydi
  });
}
