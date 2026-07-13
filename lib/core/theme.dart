import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ThemeVariant { midnightSlate, neonHorizon, forestZen, sunsetCrimson }
enum WidgetCardTheme { glassmorphism, cyberpunk, animatedAura, minimalStark }

class ThemeSettings {
  final ThemeMode mode;
  final ThemeVariant variant;
  final WidgetCardTheme widgetCardTheme;

  ThemeSettings({
    required this.mode,
    required this.variant,
    required this.widgetCardTheme,
  });

  ThemeSettings copyWith({
    ThemeMode? mode,
    ThemeVariant? variant,
    WidgetCardTheme? widgetCardTheme,
  }) {
    return ThemeSettings(
      mode: mode ?? this.mode,
      variant: variant ?? this.variant,
      widgetCardTheme: widgetCardTheme ?? this.widgetCardTheme,
    );
  }
}

// Pre-initialized in main.dart
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences has not been initialized');
});

final themeSettingsProvider = StateNotifierProvider<ThemeSettingsNotifier, ThemeSettings>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return ThemeSettingsNotifier(prefs);
});

class ThemeSettingsNotifier extends StateNotifier<ThemeSettings> {
  final SharedPreferences prefs;

  ThemeSettingsNotifier(this.prefs)
      : super(ThemeSettings(
          mode: ThemeMode.values[prefs.getInt('theme_mode') ?? ThemeMode.dark.index],
          variant: ThemeVariant.values[prefs.getInt('theme_variant') ?? ThemeVariant.midnightSlate.index],
          widgetCardTheme: WidgetCardTheme.values[prefs.getInt('widget_card_theme') ?? WidgetCardTheme.glassmorphism.index],
        ));

  void updateThemeMode(ThemeMode mode) {
    state = state.copyWith(mode: mode);
    prefs.setInt('theme_mode', mode.index);
  }

  void updateThemeVariant(ThemeVariant variant) {
    state = state.copyWith(variant: variant);
    prefs.setInt('theme_variant', variant.index);
  }

  void updateWidgetCardTheme(WidgetCardTheme cardTheme) {
    state = state.copyWith(widgetCardTheme: cardTheme);
    prefs.setInt('widget_card_theme', cardTheme.index);
  }
}

class PulseTheme {
  static ThemeMode _mode = ThemeMode.dark;
  static ThemeVariant _variant = ThemeVariant.midnightSlate;
  static WidgetCardTheme _widgetCardTheme = WidgetCardTheme.glassmorphism;
  static bool _isDark = true;

  static void updateTheme(ThemeMode mode, ThemeVariant variant, WidgetCardTheme cardTheme, bool isSystemDark) {
    _mode = mode;
    _variant = variant;
    _widgetCardTheme = cardTheme;
    if (mode == ThemeMode.system) {
      _isDark = isSystemDark;
    } else {
      _isDark = mode == ThemeMode.dark;
    }
  }

  // Active theme properties
  static ThemeMode get activeMode => _mode;
  static ThemeVariant get activeVariant => _variant;
  static WidgetCardTheme get activeWidgetCardTheme => _widgetCardTheme;
  static bool get isDark => _isDark;

  // ── COLOR PALETTES ────────────────────────────────────────────────────────

  static const _midnightSlateDark = _Palette(
    background: Color(0xFF090D14),
    surface: Color(0xFF131A28),
    surfaceLight: Color(0xFF1E283D),
    primary: Color(0xFFE2E8F0),
    secondary: Color(0xFF94A3B8),
    accent: Color(0xFF38BDF8),
    recoveryHigh: Color(0xFF22D3EE),
    recoveryMedium: Color(0xFFFBBF24),
    recoveryLow: Color(0xFFF43F5E),
    sleepPrimary: Color(0xFF818CF8),
    strainPrimary: Color(0xFFFB923C),
  );

  static const _midnightSlateLight = _Palette(
    background: Color(0xFFF1F5F9),
    surface: Color(0xFFFFFFFF),
    surfaceLight: Color(0xFFE2E8F0),
    primary: Color(0xFF0F172A),
    secondary: Color(0xFF475569),
    accent: Color(0xFF0284C7),
    recoveryHigh: Color(0xFF0891B2),
    recoveryMedium: Color(0xFFD97706),
    recoveryLow: Color(0xFFE11D48),
    sleepPrimary: Color(0xFF4F46E5),
    strainPrimary: Color(0xFFEA580C),
  );

  static const _neonHorizonDark = _Palette(
    background: Color(0xFF0C0516),
    surface: Color(0xFF1A0E2E),
    surfaceLight: Color(0xFF291745),
    primary: Color(0xFFF8FAFC),
    secondary: Color(0xFFCBD5E1),
    accent: Color(0xFFEC4899), // Hot Pink
    recoveryHigh: Color(0xFF10B981),
    recoveryMedium: Color(0xFFFBBF24),
    recoveryLow: Color(0xFFF43F5E),
    sleepPrimary: Color(0xFF8B5CF6), // Neon Purple
    strainPrimary: Color(0xFFF97316),
  );

  static const _neonHorizonLight = _Palette(
    background: Color(0xFFFAF7FF),
    surface: Color(0xFFFFFFFF),
    surfaceLight: Color(0xFFF3E8FF),
    primary: Color(0xFF2E1065),
    secondary: Color(0xFF6B21A8),
    accent: Color(0xFFDB2777),
    recoveryHigh: Color(0xFF059669),
    recoveryMedium: Color(0xFFD97706),
    recoveryLow: Color(0xFFDC2626),
    sleepPrimary: Color(0xFF7C3AED),
    strainPrimary: Color(0xFFEA580C),
  );

  static const _forestZenDark = _Palette(
    background: Color(0xFF050E09),
    surface: Color(0xFF0C2116),
    surfaceLight: Color(0xFF143825),
    primary: Color(0xFFECFDF5),
    secondary: Color(0xFF86EFAC),
    accent: Color(0xFF10B981), // Emerald
    recoveryHigh: Color(0xFF34D399),
    recoveryMedium: Color(0xFFF59E0B),
    recoveryLow: Color(0xFFEF4444),
    sleepPrimary: Color(0xFF6EE7B7),
    strainPrimary: Color(0xFFD97706),
  );

  static const _forestZenLight = _Palette(
    background: Color(0xFFF2FBF7),
    surface: Color(0xFFFFFFFF),
    surfaceLight: Color(0xFFD1FAE5),
    primary: Color(0xFF064E3B),
    secondary: Color(0xFF065F46),
    accent: Color(0xFF059669),
    recoveryHigh: Color(0xFF047857),
    recoveryMedium: Color(0xFFB45309),
    recoveryLow: Color(0xFFB91C1C),
    sleepPrimary: Color(0xFF059669),
    strainPrimary: Color(0xFFD97706),
  );

  static const _sunsetCrimsonDark = _Palette(
    background: Color(0xFF140606),
    surface: Color(0xFF260D0D),
    surfaceLight: Color(0xFF3F1919),
    primary: Color(0xFFFEF2F2),
    secondary: Color(0xFFFECACA),
    accent: Color(0xFFF97316), // Sunset Orange
    recoveryHigh: Color(0xFF4ADE80),
    recoveryMedium: Color(0xFFFBBF24),
    recoveryLow: Color(0xFFEF4444),
    sleepPrimary: Color(0xFFF472B6),
    strainPrimary: Color(0xFFEA580C),
  );

  static const _sunsetCrimsonLight = _Palette(
    background: Color(0xFFFFF8F8),
    surface: Color(0xFFFFFFFF),
    surfaceLight: Color(0xFFFFE4E4),
    primary: Color(0xFF450A0A),
    secondary: Color(0xFF7F1D1D),
    accent: Color(0xFFC2410C),
    recoveryHigh: Color(0xFF15803D),
    recoveryMedium: Color(0xFFB45309),
    recoveryLow: Color(0xFF991B1B),
    sleepPrimary: Color(0xFFBE185D),
    strainPrimary: Color(0xFFC2410C),
  );

  static _Palette get _currentPalette {
    if (_isDark) {
      switch (_variant) {
        case ThemeVariant.midnightSlate:
          return _midnightSlateDark;
        case ThemeVariant.neonHorizon:
          return _neonHorizonDark;
        case ThemeVariant.forestZen:
          return _forestZenDark;
        case ThemeVariant.sunsetCrimson:
          return _sunsetCrimsonDark;
      }
    } else {
      switch (_variant) {
        case ThemeVariant.midnightSlate:
          return _midnightSlateLight;
        case ThemeVariant.neonHorizon:
          return _neonHorizonLight;
        case ThemeVariant.forestZen:
          return _forestZenLight;
        case ThemeVariant.sunsetCrimson:
          return _sunsetCrimsonLight;
      }
    }
  }

  // Dynamic getters to replace static constants
  static Color get background => _currentPalette.background;
  static Color get surface => _currentPalette.surface;
  static Color get surfaceLight => _currentPalette.surfaceLight;
  static Color get primary => _currentPalette.primary;
  static Color get secondary => _currentPalette.secondary;
  static Color get accent => _currentPalette.accent;

  static Color get recoveryHigh => _currentPalette.recoveryHigh;
  static Color get recoveryMedium => _currentPalette.recoveryMedium;
  static Color get recoveryLow => _currentPalette.recoveryLow;
  static Color get sleepPrimary => _currentPalette.sleepPrimary;
  static Color get strainPrimary => _currentPalette.strainPrimary;

  static ThemeData getThemeData(ThemeMode mode, ThemeVariant variant, WidgetCardTheme cardTheme, bool isSystemDark) {
    updateTheme(mode, variant, cardTheme, isSystemDark);
    final themeMode = _isDark ? Brightness.dark : Brightness.light;

    return ThemeData(
      useMaterial3: true,
      brightness: themeMode,
      scaffoldBackgroundColor: Colors.transparent, // Background handled by mesh gradient
      primaryColor: primary,
      colorScheme: ColorScheme(
        brightness: themeMode,
        primary: primary,
        onPrimary: _isDark ? Colors.black : Colors.white,
        secondary: secondary,
        onSecondary: Colors.white,
        error: recoveryLow,
        onError: Colors.white,
        surface: surface,
        onSurface: primary,
      ),
      textTheme: GoogleFonts.outfitTextTheme(
        (_isDark ? ThemeData.dark() : ThemeData.light()).textTheme,
      ).copyWith(
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
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: primary),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
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

  // Backward compatibility
  static ThemeData get darkTheme => getThemeData(ThemeMode.dark, ThemeVariant.midnightSlate, WidgetCardTheme.glassmorphism, true);
}

class _Palette {
  final Color background;
  final Color surface;
  final Color surfaceLight;
  final Color primary;
  final Color secondary;
  final Color accent;

  final Color recoveryHigh;
  final Color recoveryMedium;
  final Color recoveryLow;
  final Color sleepPrimary;
  final Color strainPrimary;

  const _Palette({
    required this.background,
    required this.surface,
    required this.surfaceLight,
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.recoveryHigh,
    required this.recoveryMedium,
    required this.recoveryLow,
    required this.sleepPrimary,
    required this.strainPrimary,
  });
}
