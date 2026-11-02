import 'package:flutter/material.dart';

class AppTheme {
  // Brand MSRTC Palette
  static const Color msrtcRed = Color(0xFF8E1616);          // Deep Heritage Crimson
  static const Color msrtcRedDark = Color(0xFF6B0E0E);      // Hero card gradient dark
  static const Color msrtcRedLight = Color(0xFFB91C1C);     // Accent Red
  static const Color msrtcGold = Color(0xFFD97706);         // Transport Ochre Gold
  static const Color msrtcGoldDark = Color(0xFFB45309);     // Deep Gold Accent

  // Surface Tokens
  static const Color parchment = Color(0xFFFAF7F2);         // Warm terminal parchment background
  static const Color surfaceLow = Color(0xFFF4EFEA);        // Low container
  static const Color surfaceMid = Color(0xFFEFE9E2);        // Default container
  static const Color surfaceHigh = Color(0xFFE8E1D9);       // High container
  static const Color inkPrimary = Color(0xFF1C1917);        // Primary typography
  static const Color inkSecondary = Color(0xFF7A706C);      // Subtitle / muted text
  static const Color outline = Color(0xFFDED6CD);           // Card boundary outline

  // Destination Board Tokens
  static const Color boardCream = parchment;
  static const Color boardBorder = outline;
  static const Color boardInk = inkPrimary;

  // Local Bundled Offline Font Helpers
  static TextStyle devanagari({
    double fontSize = 16,
    FontWeight fontWeight = FontWeight.w600,
    Color? color,
    double? height,
    double? letterSpacing,
    List<FontFeature>? fontFeatures,
  }) {
    return TextStyle(
      fontFamily: 'Mukta',
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
      fontFeatures: fontFeatures,
    );
  }

  static TextStyle latin({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w600,
    Color? color,
    double? letterSpacing,
    double? height,
    List<FontFeature>? fontFeatures,
  }) {
    return TextStyle(
      fontFamily: 'PlusJakartaSans',
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
      fontFeatures: fontFeatures,
    );
  }

  // Light Theme
  // Built once and cached: recreating ThemeData on every access defeats
  // Flutter's theme-change short circuits.
  static final ThemeData lightTheme = _buildLightTheme();

  static ThemeData _buildLightTheme() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: msrtcRed,
      brightness: Brightness.light,
      primary: msrtcRed,
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFFFFDAD6),
      onPrimaryContainer: const Color(0xFF410002),
      secondary: msrtcGoldDark,
      onSecondary: Colors.white,
      surface: parchment,
      onSurface: inkPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: 'PlusJakartaSans',
      colorScheme: colorScheme,
      scaffoldBackgroundColor: parchment,
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontFamily: 'Mukta', fontSize: 32, fontWeight: FontWeight.bold, color: inkPrimary),
        titleLarge: TextStyle(fontFamily: 'Mukta', fontSize: 20, fontWeight: FontWeight.w700, color: inkPrimary),
        titleMedium: TextStyle(fontFamily: 'Mukta', fontSize: 16, fontWeight: FontWeight.w600, color: inkPrimary),
        bodyLarge: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 15, fontWeight: FontWeight.w500, color: inkPrimary),
        bodyMedium: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13, fontWeight: FontWeight.w400, color: inkSecondary),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: parchment,
        foregroundColor: inkPrimary,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: outline, width: 1),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF1E1716),
        contentTextStyle: const TextStyle(
          fontFamily: 'Mukta',
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF423430), width: 1.0),
        ),
        behavior: SnackBarBehavior.floating,
        actionTextColor: msrtcGold,
        elevation: 8,
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 2,
        backgroundColor: surfaceMid,
        indicatorColor: msrtcRed.withValues(alpha: 0.14),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 12, fontWeight: FontWeight.w800, color: msrtcRed);
          }
          return const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 12, fontWeight: FontWeight.w600, color: inkSecondary);
        }),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: msrtcRed,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  // Dark Theme
  static final ThemeData darkTheme = _buildDarkTheme();

  static ThemeData _buildDarkTheme() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: msrtcRed,
      brightness: Brightness.dark,
      primary: const Color(0xFFFFB4AB),
      onPrimary: const Color(0xFF690005),
      surface: const Color(0xFF171211),
      onSurface: const Color(0xFFEDE0DE),
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: 'PlusJakartaSans',
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFF140E0D),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF171211),
        foregroundColor: Color(0xFFEDE0DE),
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF221A19),
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF3B2E2C), width: 1),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF2A1F1D),
        contentTextStyle: const TextStyle(
          fontFamily: 'Mukta',
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Color(0xFFEDE0DE),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF4A3835), width: 1.0),
        ),
        behavior: SnackBarBehavior.floating,
        actionTextColor: msrtcGold,
        elevation: 8,
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: Color(0xFF1D1514),
        indicatorColor: Color(0xFF3B1E1C),
      ),
    );
  }
}
