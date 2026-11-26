import 'package:flutter/material.dart';

class AppColors {
  // Common Colors
  static const Color primary = Color(0xFF2563EB);
  static const Color secondary = Color(0xFF014E73);
  static const Color income = Color(0xFF2E7D32);
  static const Color expense = Color(0xFFC62828);
  static const Color transfer = Color(0xFF1E88E5);
  static const Color inactive = Color(0xFF808080);
  static const Color description = Color(0xFF777777);

  // Light Theme
  static const Color lightBackground = Color(0xFFF2F2F2);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightText = Color(0xFF11181C);
  static const Color lightBorder = Color(0xFFE5E5E5);
  static const Color lightBottomBar = Color(0xFFE5E7EB);

  // Dark Theme
  static const Color darkBackground = Color(0xFF050B10);
  static const Color darkCard = Color(0xFF0A1A24);
  static const Color darkText = Color(0xFFBFBFBF);
  static const Color darkBorder = Color(0xFF13222D);
  static const Color darkBottomBar = Color(0xFF0A1A24);

  static Color parseHex(String? hexString, [Color defaultColor = Colors.grey]) {
    if (hexString == null || hexString.isEmpty) return defaultColor;
    try {
      String cleanHex = hexString.replaceAll('#', '').trim();
      if (cleanHex.length == 6) {
        cleanHex = 'FF$cleanHex';
      }
      return Color(int.parse(cleanHex, radix: 16));
    } catch (_) {
      return defaultColor;
    }
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primary,
      scaffoldBackgroundColor: lightBackground,
      cardColor: lightCard,
      dividerColor: lightBorder,
      bottomAppBarTheme: const BottomAppBarThemeData(
        color: lightBottomBar,
        elevation: 8,
      ),
      colorScheme: const ColorScheme.light(
        primary: primary,
        secondary: secondary,
        surface: lightCard,
        error: expense,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: lightBackground,
        foregroundColor: lightText,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primary,
      scaffoldBackgroundColor: darkBackground,
      cardColor: darkCard,
      dividerColor: darkBorder,
      bottomAppBarTheme: const BottomAppBarThemeData(
        color: darkBottomBar,
        elevation: 8,
      ),
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: secondary,
        surface: darkCard,
        error: expense,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: darkBackground,
        foregroundColor: darkText,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
      ),
    );
  }
}
