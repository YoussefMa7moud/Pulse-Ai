import 'package:home_widget/home_widget.dart';
import 'package:flutter/material.dart';
import '../core/theme.dart';

String _colorToHex(Color color) {
  return '#${color.value.toRadixString(16).padLeft(8, '0')}';
}

/// Pushes in-app theme choices to Android home screen widgets.
Future<void> syncWidgetThemeToAndroid(ThemeSettings settings) async {
  try {
    await HomeWidget.saveWidgetData<String>('widget_card_theme', settings.widgetCardTheme.name);
    await HomeWidget.saveWidgetData<String>('theme_variant', settings.variant.name);
    await HomeWidget.saveWidgetData<String>('theme_mode', PulseTheme.isDark ? 'dark' : 'light');

    await HomeWidget.saveWidgetData<String>('color_background', _colorToHex(PulseTheme.background));
    await HomeWidget.saveWidgetData<String>('color_surface', _colorToHex(PulseTheme.surface));
    await HomeWidget.saveWidgetData<String>('color_primary', _colorToHex(PulseTheme.primary));
    await HomeWidget.saveWidgetData<String>('color_secondary', _colorToHex(PulseTheme.secondary));
    await HomeWidget.saveWidgetData<String>('color_accent', _colorToHex(PulseTheme.accent));
    await HomeWidget.saveWidgetData<String>('color_recovery_high', _colorToHex(PulseTheme.recoveryHigh));
    await HomeWidget.saveWidgetData<String>('color_recovery_low', _colorToHex(PulseTheme.recoveryLow));
    await HomeWidget.saveWidgetData<String>('color_sleep', _colorToHex(PulseTheme.sleepPrimary));
    await HomeWidget.saveWidgetData<String>('color_strain', _colorToHex(PulseTheme.strainPrimary));

    const providers = [
      'PulseRecoveryWidgetProvider',
      'PulseSleepWidgetProvider',
      'PulseStrainWidgetProvider',
      'PulseReadinessWidgetProvider',
      'PulseStressWidgetProvider',
      'PulseStepsWidgetProvider',
      'PulseHeartWidgetProvider',
      'PulseOverviewWidgetProvider',
    ];

    for (final name in providers) {
      await HomeWidget.updateWidget(name: name);
    }
  } catch (_) {
    // Non-fatal
  }
}
