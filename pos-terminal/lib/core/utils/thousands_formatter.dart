import 'package:flutter/services.dart';

/// Summa maydonlarida raqamlarni probel bilan guruhlab ko'rsatadi:
/// 216700 → "216 700". Qiymatni o'qishda probellarni olib tashlang
/// (masalan `text.replaceAll(RegExp(r'[^0-9]'), '')`).
class ThousandsInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return const TextEditingValue(text: '');
    final text = groupDigits(digits);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  /// "216700" → "216 700".
  static String groupDigits(String digits) {
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buf.write(' ');
      buf.write(digits[i]);
    }
    return buf.toString();
  }

  /// num → probelli matn (input boshlang'ich qiymati uchun).
  static String format(num v) => groupDigits(v.round().toString());
}
