import "package:flutter/material.dart";

ThemeData buildAppTheme() {
  const background = Color(0xFFF6F1EA);
  const panel = Color(0xFFFFFCF7);
  const primaryText = Color(0xFF1D1B18);
  const accent = Color(0xFF7C6A58);

  return ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.light,
      surface: panel,
      primary: accent,
    ),
    scaffoldBackgroundColor: background,
    textTheme: const TextTheme(
      headlineMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: primaryText,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: primaryText,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        height: 1.5,
        color: primaryText,
      ),
    ),
    cardTheme: CardThemeData(
      color: panel,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
    ),
  );
}
