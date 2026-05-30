import 'package:flutter/material.dart';

class AppTheme {
  // Cozy Pastel Palette
  static const Color creamBackground = Color(0xFFFAF6EE);
  static const Color cardSurface = Color(0xFFFFFFFF);
  static const Color mintGreen = Color(0xFF6EC6A1);
  static const Color salmonPink = Color(0xFFFF8B94);
  static const Color softAmber = Color(0xFFFCD381);
  static const Color charcoalBrown = Color(0xFF4D4342);
  static const Color mutedBrown = Color(0xFF8E8280);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: mintGreen,
        onPrimary: Colors.white,
        secondary: salmonPink,
        onSecondary: Colors.white,
        tertiary: softAmber,
        onTertiary: charcoalBrown,
        error: Color(0xFFE57373),
        onError: Colors.white,
        surface: cardSurface,
        onSurface: charcoalBrown,
      ),
      scaffoldBackgroundColor: creamBackground,
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontFamily: 'Outfit',
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: charcoalBrown,
        ),
        displayMedium: TextStyle(
          fontFamily: 'Outfit',
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: charcoalBrown,
        ),
        titleLarge: TextStyle(
          fontFamily: 'Outfit',
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: charcoalBrown,
          letterSpacing: 0.15,
        ),
        titleMedium: TextStyle(
          fontFamily: 'Outfit',
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: charcoalBrown,
        ),
        bodyLarge: TextStyle(
          fontFamily: 'Outfit',
          fontSize: 16,
          fontWeight: FontWeight.normal,
          color: charcoalBrown,
        ),
        bodyMedium: TextStyle(
          fontFamily: 'Outfit',
          fontSize: 14,
          fontWeight: FontWeight.normal,
          color: mutedBrown,
        ),
        labelLarge: TextStyle(
          fontFamily: 'Outfit',
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: charcoalBrown,
        ),
      ),
      cardTheme: CardThemeData(
        color: cardSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24.0),
          side: const BorderSide(
            color: Color(0xFFF1EADF),
            width: 1.5,
          ),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: charcoalBrown),
        titleTextStyle: TextStyle(
          fontFamily: 'Outfit',
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: charcoalBrown,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: mintGreen,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Outfit',
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFEFE8DE),
        thickness: 1.5,
      ),
    );
  }
}
