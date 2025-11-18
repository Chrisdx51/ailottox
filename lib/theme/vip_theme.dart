import 'package:flutter/material.dart';

class VipTheme {
  // MAIN VIP ACCENT COLOURS
  static const Color accent = Color(0xFF00FEFC);
  static const Color accentSoft = Color(0xFF72FFD6);

  // GLASS GRADIENT FOR VIP ONLY
  static LinearGradient glassGradient = LinearGradient(
    colors: [
      Colors.white.withOpacity(0.12),
      Colors.white.withOpacity(0.04),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // OUTER VIP GLOW
  static List<BoxShadow> glow(Color color) => [
    BoxShadow(
      color: color.withOpacity(0.45),
      blurRadius: 30,
      spreadRadius: 6,
    ),
  ];
}
