import 'package:flutter/material.dart';

/// Brand palette: "Ember & Gold" — warm ember brand, mint income, red expense.
abstract final class AppColors {
  static const ember = Color(0xFFE8590C);
  static const emberLight = Color(0xFFFF8A4C);
  static const emberSoft = Color(0xFFFFEDE0);

  static const income = Color(0xFF12B76A);
  static const expense = Color(0xFFF04438);
  static const warning = Color(0xFFF79009);
  static const info = Color(0xFF2E90FA);

  // Light
  static const lightBg = Color(0xFFFFF8F3);
  static const lightSurface = Colors.white;
  static const lightOutline = Color(0xFFF0E2D8);
  static const lightText = Color(0xFF1F1410);
  static const lightMuted = Color(0xFF7A6A60);

  // Dark
  static const darkBg = Color(0xFF120E0C);
  static const darkSurface = Color(0xFF1C1614);
  static const darkOutline = Color(0xFF2E2522);
  static const darkText = Color(0xFFF8EFE9);
  static const darkMuted = Color(0xFFB5A59B);

  static const brandGradient = LinearGradient(
    colors: [Color(0xFFFF9A2F), Color(0xFFE8384F)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const goldGradient = LinearGradient(
    colors: [Color(0xFFFFC93C), Color(0xFFFF7A2F)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const incomeGradient = LinearGradient(
    colors: [Color(0xFF34D399), Color(0xFF059669)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const expenseGradient = LinearGradient(
    colors: [Color(0xFFFB7185), Color(0xFFE11D48)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
