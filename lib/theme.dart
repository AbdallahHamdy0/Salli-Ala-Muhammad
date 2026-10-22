import 'package:flutter/material.dart';

class AppColors {
  static const gold = Color(0xFFE6BE6E);
  static const goldSoft = Color(0xFFC9A55C);
  static const cream = Color(0xFFF6EED6);
  static const deep = Color(0xFF021F1C);
  static const deepTop = Color(0xFF01252A);
  static const green = Color(0xFF4CD27C);
}

// الخطوط: خط النظام (بدون تحميل من الإنترنت). لو عايز خط مخصص، شوف README_AR.md.
TextStyle quranStyle(double size) => TextStyle(fontSize: size, height: 1.75, color: AppColors.cream);

TextStyle uiStyle(double size, {Color color = AppColors.cream, FontWeight w = FontWeight.w500}) =>
    TextStyle(fontSize: size, color: color, fontWeight: w);

ThemeData buildTheme() => ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.deep,
      colorScheme: const ColorScheme.dark(primary: AppColors.gold, surface: AppColors.deep),
      useMaterial3: true,
    );
