import 'package:flutter/material.dart';

class AppTheme {
  // 🎨 COLORS (DEFINED HERE – NO ERRORS)
  static const Color primaryBlue = Color(0xFF0B4DBA);
  static const Color lightBlue = Color(0xFFEAF2FB);
  static const Color cardWhite = Colors.white;
  static const Color textDark = Color(0xFF1C2A39);

  static ThemeData theme = ThemeData(
    useMaterial3: false,

    // ---------------- BASIC ----------------
    scaffoldBackgroundColor: lightBlue,
    primaryColor: primaryBlue,

    // ---------------- APP BAR ----------------
    appBarTheme: const AppBarTheme(
      backgroundColor: primaryBlue,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    ),

    // ---------------- TEXT ----------------
    textTheme: const TextTheme(
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: textDark,
      ),
      bodyMedium: TextStyle(fontSize: 14, color: textDark),
    ),

    // ---------------- CARD ----------------
    cardTheme: CardThemeData(
      color: cardWhite,
      elevation: 3,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),

    // ---------------- BUTTONS ----------------
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        minimumSize: const Size(double.infinity, 48),
        textStyle: const TextStyle(fontWeight: FontWeight.bold),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryBlue,
        side: const BorderSide(color: primaryBlue),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        minimumSize: const Size(double.infinity, 48),
      ),
    ),

    // ---------------- INPUT ----------------
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: cardWhite,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primaryBlue),
      ),
      labelStyle: const TextStyle(color: primaryBlue),
    ),
  );
}
