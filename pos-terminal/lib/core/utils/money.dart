/// Money helpers. All amounts in the AIBA POS are **so'm** (no tiyin / no
/// fractional currency). The backend serializes decimals as strings
/// (e.g. "12000.00"), so parsing must be tolerant of both String and num.
class Money {
  const Money._();

  /// Parse a backend money value that may arrive as a String ("12000.00"),
  /// an int, a double, or null. Always returns a [num], 0 on failure.
  static num parse(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value;
    if (value is String) {
      final cleaned = value.trim();
      if (cleaned.isEmpty) return 0;
      return num.tryParse(cleaned) ?? 0;
    }
    return 0;
  }

  /// Parse to int so'm (rounded). Used when we only ever deal in whole so'm.
  static int parseSom(dynamic value) => parse(value).round();

  /// Format a so'm amount with thousands separators, e.g. 1250000 -> "1 250 000".
  static String format(num value) {
    final isNegative = value < 0;
    final digits = value.abs().round().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(' ');
      buffer.write(digits[i]);
    }
    return '${isNegative ? '-' : ''}$buffer';
  }

  /// Format with the so'm suffix, e.g. "1 250 000 so'm".
  static String formatSom(num value) => "${format(value)} so'm";

  /// Qisqartma pul formati (Figma mini-kartalari): 500 → "500",
  /// 500 000 → "500 K", 1 150 000 → "1.15 mln".
  static String compact(num value) {
    final v = value.abs();
    String s;
    if (v >= 1000000) {
      s = (v / 1000000).toStringAsFixed(2);
      s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
      s = '$s mln';
    } else if (v >= 1000) {
      s = '${(v / 1000).round()} K';
    } else {
      s = v.round().toString();
    }
    return value < 0 ? '-$s' : s;
  }

  /// Miqdor formati — butun bo'lsa kasrsiz, aks holda 3 xonagacha (trim).
  static String formatQty(num value) {
    if (value % 1 == 0) return value.toInt().toString();
    var s = value.toStringAsFixed(3);
    s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
    return s;
  }
}
