import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TwamboColors {
  // Sunny base
  static const bg          = Color(0xFFFFFBF0); // warm cream
  static const surface     = Color(0xFFFFFFFF); // white cards
  static const surfaceAlt  = Color(0xFFFFF8E7); // soft warm fill
  // Text
  static const textPrimary   = Color(0xFF1A1A1A);
  static const textSecondary = Color(0xFF6B6B6B);
  // Brand
  static const primary     = Color(0xFFFFC300); // taxi yellow
  static const primaryDark = Color(0xFFE6A800); // deeper yellow
  static const secondary   = Color(0xFF1565C0); // Zambian sky blue
  static const accent      = Color(0xFFFF8C00); // amber warmth
  // Status
  static const error   = Color(0xFFD32F2F);
  static const success = Color(0xFF2E7D32);
  // Borders
  static const line    = Color(0xFFE8D5A3); // warm yellow border
  // Legacy alias
  static const cardBg  = surface;
}

ThemeData twamboTheme() {
  final base = ThemeData.light(useMaterial3: true);

  final textTheme = GoogleFonts.manropeTextTheme(base.textTheme).apply(
    bodyColor: TwamboColors.textPrimary,
    displayColor: TwamboColors.textPrimary,
  );

  return base.copyWith(
    colorScheme: const ColorScheme.light(
      primary:     TwamboColors.primary,
      secondary:   TwamboColors.secondary,
      surface:     TwamboColors.surface,
      error:       TwamboColors.error,
      onPrimary:   TwamboColors.textPrimary,
      onSecondary: Colors.white,
      onSurface:   TwamboColors.textPrimary,
    ),
    scaffoldBackgroundColor: TwamboColors.bg,
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: TwamboColors.surface,
      foregroundColor: TwamboColors.textPrimary,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: GoogleFonts.spaceGrotesk(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: TwamboColors.textPrimary,
        letterSpacing: 0.3,
      ),
      iconTheme: const IconThemeData(color: TwamboColors.secondary),
      shape: const Border(
        bottom: BorderSide(color: TwamboColors.line, width: 1.5),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: TwamboColors.primary,
        foregroundColor: TwamboColors.textPrimary,
        minimumSize: const Size.fromHeight(50),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: GoogleFonts.manrope(fontWeight: FontWeight.w800, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: TwamboColors.secondary,
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: const BorderSide(color: TwamboColors.secondary, width: 1.5),
        textStyle: GoogleFonts.manrope(fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: TwamboColors.secondary,
        textStyle: GoogleFonts.manrope(fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: TwamboColors.surfaceAlt,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: TwamboColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: TwamboColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: TwamboColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: TwamboColors.error),
      ),
      labelStyle: const TextStyle(color: TwamboColors.textSecondary),
      hintStyle: const TextStyle(color: TwamboColors.textSecondary),
      prefixIconColor: TwamboColors.textSecondary,
      suffixIconColor: TwamboColors.textSecondary,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    cardTheme: CardThemeData(
      color: TwamboColors.surface,
      elevation: 2,
      shadowColor: TwamboColors.primary.withValues(alpha: 0.15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: TwamboColors.line),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    ),
    dividerTheme: const DividerThemeData(color: TwamboColors.line, thickness: 1),
    chipTheme: ChipThemeData(
      backgroundColor: TwamboColors.surfaceAlt,
      labelStyle: const TextStyle(color: TwamboColors.textPrimary, fontSize: 12),
      side: const BorderSide(color: TwamboColors.line),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    iconTheme: const IconThemeData(color: TwamboColors.secondary),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? TwamboColors.primary : Colors.grey.shade400,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? TwamboColors.primary.withValues(alpha: 0.4)
            : Colors.grey.shade200,
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: TwamboColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: TwamboColors.textPrimary,
      contentTextStyle: GoogleFonts.manrope(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

ThemeData twamboDarkTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  final textTheme = GoogleFonts.manropeTextTheme(base.textTheme).apply(
    bodyColor: Colors.white,
    displayColor: Colors.white,
  );
  return base.copyWith(
    colorScheme: const ColorScheme.dark(
      primary: TwamboColors.primary,
      secondary: Color(0xFF90CAF9),
      surface: Color(0xFF1E1E1E),
      error: Color(0xFFEF9A9A),
      onPrimary: Color(0xFF1A1A1A),
      onSecondary: Colors.white,
      onSurface: Colors.white,
    ),
    scaffoldBackgroundColor: const Color(0xFF0D0D0D),
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: const Color(0xFF1A1A1A),
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: GoogleFonts.spaceGrotesk(
        fontSize: 18, fontWeight: FontWeight.w800,
        color: Colors.white, letterSpacing: 0.3,
      ),
      iconTheme: const IconThemeData(color: Colors.white),
      shape: const Border(bottom: BorderSide(color: Color(0xFF2E2E2E), width: 1.5)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: TwamboColors.primary,
        foregroundColor: const Color(0xFF1A1A1A),
        minimumSize: const Size.fromHeight(50),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: GoogleFonts.manrope(fontWeight: FontWeight.w800, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF90CAF9),
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: const BorderSide(color: Color(0xFF90CAF9), width: 1.5),
        textStyle: GoogleFonts.manrope(fontWeight: FontWeight.w700),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF2A2A2A),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF3E3E3E)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF3E3E3E)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: TwamboColors.primary, width: 2),
      ),
      labelStyle: const TextStyle(color: Color(0xFF9E9E9E)),
      hintStyle: const TextStyle(color: Color(0xFF9E9E9E)),
      prefixIconColor: const Color(0xFF9E9E9E),
      suffixIconColor: const Color(0xFF9E9E9E),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    cardTheme: CardThemeData(
      color: const Color(0xFF1E1E1E),
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF2E2E2E)),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    ),
    dividerTheme: const DividerThemeData(color: Color(0xFF2E2E2E), thickness: 1),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: Colors.white,
      contentTextStyle: GoogleFonts.manrope(color: const Color(0xFF1A1A1A)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

// Yellow → amber gradient for primary buttons and accents
const twamboPrimaryGradient = LinearGradient(
  colors: [TwamboColors.primary, TwamboColors.accent],
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
);
