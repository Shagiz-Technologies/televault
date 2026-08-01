import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color primary = Color(0xFF168CE8);
  static const Color primaryDeep = Color(0xFF0868C7);
  static const Color primarySoft = Color(0xFFE7F3FD);

  static const Color paper = Color(0xFFF7F4EE);
  static const Color paperMuted = Color(0xFFF0ECE4);
  static const Color surface = Color(0xFFFFFDF9);
  static const Color surfaceHighlight = Color(0xFFF5F1E9);
  static const Color background = paper;

  static const Color ink = Color(0xFF14212B);
  static const Color inkMuted = Color(0xFF52616C);
  static const Color textSecondary = inkMuted;
  static const Color outline = Color(0xFFDCD8D0);

  static const Color success = Color(0xFF2EBF91);
  static const Color successSoft = Color(0xFFE3F7F0);
  static const Color error = Color(0xFFF26B5B);
  static const Color errorSoft = Color(0xFFFFE9E5);
  static const Color warning = Color(0xFFE9A23B);
  static const Color warningSoft = Color(0xFFFFF2D9);

  static const Color secure = Color(0xFF0A1822);
  static const Color secureSurface = Color(0xFF102C3A);
  static const Color secureOutline = Color(0xFF244858);
  static const Color encrypted = Color(0xFFD7A54A);
  static const Color white = Colors.white;

  static const double radiusSmall = 12;
  static const double radius = 18;
  static const double radiusLarge = 24;

  static ThemeData get lightTheme {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: primary,
          brightness: Brightness.light,
          primary: primary,
          surface: surface,
          error: error,
        ).copyWith(
          onPrimary: Colors.white,
          onSurface: ink,
          outline: outline,
          secondary: success,
          tertiary: warning,
        );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: paper,
      canvasColor: paper,
      splashFactory: InkSparkle.splashFactory,
    );

    return base.copyWith(
      textTheme: _textTheme(base.textTheme, ink),
      primaryTextTheme: _textTheme(base.primaryTextTheme, ink),
      appBarTheme: AppBarTheme(
        backgroundColor: paper,
        surfaceTintColor: Colors.transparent,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.manrope(
          color: ink,
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
        iconTheme: const IconThemeData(color: ink),
      ),
      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: const BorderSide(color: outline),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        hintStyle: const TextStyle(color: inkMuted),
        labelStyle: const TextStyle(color: inkMuted),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: _inputBorder(outline),
        enabledBorder: _inputBorder(outline),
        focusedBorder: _inputBorder(primary, width: 1.6),
        errorBorder: _inputBorder(error, width: 1.4),
        focusedErrorBorder: _inputBorder(error, width: 1.6),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: outline,
          disabledForegroundColor: inkMuted,
          elevation: 0,
          minimumSize: const Size(48, 54),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          textStyle: GoogleFonts.manrope(
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          minimumSize: const Size(48, 52),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          side: const BorderSide(color: outline),
          textStyle: GoogleFonts.manrope(fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryDeep,
          textStyle: GoogleFonts.manrope(fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: primarySoft,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return GoogleFonts.manrope(
            color: states.contains(WidgetState.selected)
                ? primaryDeep
                : inkMuted,
            fontSize: 11,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w800
                : FontWeight.w600,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            color: states.contains(WidgetState.selected) ? primary : inkMuted,
            size: 23,
          );
        }),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: surface,
        showDragHandle: true,
        dragHandleColor: outline,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: ink,
        contentTextStyle: const TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dividerTheme: const DividerThemeData(color: outline, thickness: 1),
      chipTheme: ChipThemeData(
        backgroundColor: surface,
        selectedColor: primarySoft,
        side: const BorderSide(color: outline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        labelStyle: GoogleFonts.manrope(
          color: ink,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primary,
        linearTrackColor: paperMuted,
        circularTrackColor: paperMuted,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? Colors.white : inkMuted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? success : outline,
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.dark,
        surface: secure,
        primary: primary,
        secondary: success,
        error: error,
      ),
      scaffoldBackgroundColor: secure,
    );

    return base.copyWith(
      textTheme: _textTheme(base.textTheme, Colors.white),
      appBarTheme: AppBarTheme(
        backgroundColor: secure,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        titleTextStyle: GoogleFonts.manrope(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  static TextTheme _textTheme(TextTheme base, Color color) {
    return GoogleFonts.manropeTextTheme(base)
        .apply(bodyColor: color, displayColor: color)
        .copyWith(
          headlineLarge: GoogleFonts.manrope(
            color: color,
            fontSize: 32,
            fontWeight: FontWeight.w800,
            letterSpacing: -1,
          ),
          headlineMedium: GoogleFonts.manrope(
            color: color,
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.7,
          ),
          titleLarge: GoogleFonts.manrope(
            color: color,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.35,
          ),
          titleMedium: GoogleFonts.manrope(
            color: color,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
          bodyLarge: GoogleFonts.manrope(
            color: color,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
          bodyMedium: GoogleFonts.manrope(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          labelLarge: GoogleFonts.manrope(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        );
  }

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}
