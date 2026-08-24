import 'package:flutter/material.dart';

/// Ilova umumiy foni — Figma dizaynidagi to'q "suv" teksturasi (haqiqiy
/// dizayndan olingan rasm). Butun ekranни qoplaydi, ustiga mayin vinetka
/// tushiб kartalar ajralib turadi.
class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Color(0xFF0E1F24)),
        Image.asset(
          'assets/water_bg.png',
          fit: BoxFit.cover,
          alignment: Alignment.center,
        ),
        // Mayin qorayish — chetlarda chuqurroq, markazда ochroq.
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(-0.2, -0.4),
              radius: 1.3,
              colors: [Color(0x00000000), Color(0x55000000)],
              stops: [0.55, 1.0],
            ),
          ),
        ),
        child,
      ],
    );
  }
}
