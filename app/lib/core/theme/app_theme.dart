import "package:flutter/material.dart";

ThemeData buildAppTheme() {
  const background = Color(0xFFFAF8F4);
  const panel = Color(0xFFFFFFFF);
  const primaryText = Color(0xFF1D1B18);
  const accent = Color(0xFF718867);

  return ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.light,
      surface: panel,
      primary: accent,
    ),
    scaffoldBackgroundColor: background,
    fontFamilyFallback: const ["Noto Sans CJK SC", "sans-serif"],
    textTheme: const TextTheme(
      headlineMedium: TextStyle(
        fontSize: 26,
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
        borderRadius: BorderRadius.circular(18),
      ),
    ),
    dividerTheme:
        const DividerThemeData(color: Color(0xFFEDE8E0), thickness: 1),
    navigationBarTheme: NavigationBarThemeData(
      height: 70,
      backgroundColor: Colors.white,
      indicatorColor: const Color(0xFFE5EDE1),
      labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
            fontSize: 11,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? accent
                : const Color(0xFF77736D),
          )),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
          minimumSize: const Size(0, 50),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
    ),
  );
}
