import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PulseTheme {
  // Midnight Slate Theme
  static const Color background = Color(0xFF090D14);
  
  // Surfaces
  static const Color surface = Color(0xFF131A28);
  static const Color surfaceLight = Color(0xFF1E283D);
  
  // Accent Colors
  static const Color primary = Color(0xFFE2E8F0); // Off-white/slate text
  static const Color secondary = Color(0xFF94A3B8); // Subdued text
  static const Color accent = Color(0xFF38BDF8); // Electric Blue
  
  // Status Colors (Vibrant/Neon)
  static const Color recoveryHigh = Color(0xFF22D3EE); // Neon Cyan
  static const Color recoveryMedium = Color(0xFFFBBF24); // Warm Gold
  static const Color recoveryLow = Color(0xFFF43F5E); // Rose Red
  static const Color sleepPrimary = Color(0xFF818CF8); // Indigo
  static const Color strainPrimary = Color(0xFFFB923C); // Vibrant Orange

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: Colors.transparent, // Background handled by mesh gradient
      primaryColor: primary,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: secondary,
        surface: surface,
        error: recoveryLow,
      ),
      textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme).copyWith(
        displayLarge: GoogleFonts.outfit(
          fontSize: 64,
          fontWeight: FontWeight.w700,
          color: primary,
          letterSpacing: -1.5,
        ),
        displayMedium: GoogleFonts.outfit(
          fontSize: 48,
          fontWeight: FontWeight.w700,
          color: primary,
          letterSpacing: -1.0,
        ),
        titleLarge: GoogleFonts.outfit(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: primary,
          letterSpacing: -0.5,
        ),
        bodyLarge: GoogleFonts.outfit(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: primary,
        ),
        bodyMedium: GoogleFonts.outfit(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: secondary,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: primary),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: accent,
        unselectedItemColor: secondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: surface.withOpacity(0.5),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
    );
  }
}
