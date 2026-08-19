import 'package:flutter/material.dart';

class AppTheme {
  const AppTheme._();

  static const Color primaryBlue = Color(0xFF1E88E5);
  static const Color emergencyRed = Color(0xFFE53935);
  static const Color successGreen = Color(0xFF43A047);
  static const Color warningOrange = Color(0xFFFB8C00);
  static const Color background = Color(0xFFF5F7FA);
  static const Color textDark = Color(0xFF263338);

  static ThemeData get light => _theme(Brightness.light);
  static ThemeData get dark => _theme(Brightness.dark);

  static ThemeData _theme(Brightness brightness) {
    final ColorScheme colors = ColorScheme.fromSeed(
      seedColor: primaryBlue,
      brightness: brightness,
    ).copyWith(
      primary: primaryBlue,
      error: emergencyRed,
      tertiary: successGreen,
      secondary: warningOrange,
      surface: brightness == Brightness.light
          ? Colors.white
          : const Color(0xFF111A20),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colors,
      scaffoldBackgroundColor:
          brightness == Brightness.light ? background : const Color(0xFF0B141A),
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shadowColor: Colors.black12,
        color: brightness == Brightness.light
            ? Colors.white
            : const Color(0xFF172229),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: brightness == Brightness.light
            ? Colors.white
            : const Color(0xFF172229),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD8DEE6)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD8DEE6)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 52),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 50),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
