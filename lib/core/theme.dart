import 'package:flutter/material.dart';

class PV {
  static const bg = Color(0xFF0B0F1A);
  static const surface = Color(0xFF121829);
  static const card = Color(0xFF1A2236);
  static const accent = Color(0xFF22D3EE);
  static const accent2 = Color(0xFF7C5CFF);
  static const live = Color(0xFFEF4444);
  static const textDim = Color(0xFF8A94A8);
}

ThemeData buildTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: PV.bg,
    colorScheme: const ColorScheme.dark(
      primary: PV.accent,
      secondary: PV.accent2,
      surface: PV.surface,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: PV.bg,
      elevation: 0,
      centerTitle: false,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: PV.surface,
      indicatorColor: PV.accent.withAlpha(45),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: PV.surface,
      indicatorColor: PV.accent.withAlpha(45),
    ),
  );
}
