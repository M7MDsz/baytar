import 'package:flutter/material.dart';

/// Brand colours from the Baytar logo.
const juniper = Color(0xFF0E2A25);
const sand = Color(0xFFF4EEE2);
const amber = Color(0xFFD9772B);

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: juniper,
    primary: juniper,
    secondary: amber,
    surface: const Color(0xFFFFFCF7),
  );
  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: sand,
    appBarTheme: const AppBarTheme(backgroundColor: sand, foregroundColor: juniper, centerTitle: false),
    inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
    cardTheme: CardThemeData(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
    ),
  );
}
