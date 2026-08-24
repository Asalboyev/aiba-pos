import 'package:flutter/material.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF1E6F5C),
      brightness: Brightness.light,
    );
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      fontFamily: 'Inter', // Figma "Pos Design" shrifti
      visualDensity: VisualDensity.adaptivePlatformDensity,
    );
  }

  /// Figma "Pos Design" qorong'i mavzusi — POS terminal shu mavzuda ishlaydi.
  /// Barcha custom widgetlar PosColors ni to'g'ridan ishlatadi; bu mavzu esa
  /// Material komponentlari (splash, snackbar, mini-savat, tugmalar) ham
  /// Figma ranglarida chiqishini ta'minlaydi.
  static ThemeData dark() {
    const bg = Color(0xFF06090B);
    const card = Color(0xFF1B1B1C);
    const blue = Color(0xFF2277EA);
    const white = Color(0xFFFAFAFA);
    final scheme = const ColorScheme.dark(
      primary: blue,
      onPrimary: Colors.white,
      secondary: blue,
      surface: card,
      onSurface: white,
      error: Color(0xFFE5484D),
    );
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      fontFamily: 'Inter',
      scaffoldBackgroundColor: bg,
      canvasColor: bg,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: Color(0xFF1C1D22),
        contentTextStyle: TextStyle(color: white, fontSize: 14),
        actionTextColor: blue,
        behavior: SnackBarBehavior.floating,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: blue),
    );
  }
}
