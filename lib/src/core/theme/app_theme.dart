import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // --- Colors (iOS/Premium Dark Palette) ---
  static const Color primary = Color(0xFF0A84FF); // iOS Blue
  static const Color background = Color(0xFF000000); // OLED Black
  static const Color surface = Color(0xFF1C1C1E); // iOS Dark Gray Surface
  static const Color surfaceHighlight = Color(0xFF2C2C2E); // Lighter Gray
  static const Color error = Color(0xFFFF453A); // iOS Red
  static const Color white = Colors.white;
  static const Color textSecondary = Color(0xFF8E8E93); // iOS Gray Text

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: primary,

      // Text Theme
      textTheme: GoogleFonts.manropeTextTheme(
        ThemeData.dark().textTheme,
      ).apply(bodyColor: white, displayColor: white),

      // Input Decoration (Minimalist & Clean)
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        hintStyle: const TextStyle(color: textSecondary),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: error, width: 1.5),
        ),
      ),

      // Button Theme (Rounded, Full Width usually adjusted in widget, but default style here)
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: white,
          elevation: 0,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              14,
            ), // Highly rounded like iOS buttons
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),

      // AppBar Theme
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        centerTitle: true,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          color: white,
          fontSize: 17, // iOS Standard Title Size
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: primary),
      ),
    );
  }
}
