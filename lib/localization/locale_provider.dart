import 'dart:ui' as ui;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../main.dart'; // Import global sharedPrefs

/// Supported locales: tr, en, es, pt, ru, de, fr
final List<String> _supportedLocales = ['tr', 'en', 'es', 'pt', 'ru', 'de', 'fr'];

String _getInitialLocale() {
  // 1. Try to load from saved shared preferences
  try {
    final String? savedLocale = sharedPrefs.getString('locale');
    if (savedLocale != null && _supportedLocales.contains(savedLocale)) {
      return savedLocale;
    }
  } catch (_) {}

  // 2. Try to match with device language
  try {
    final String deviceLanguage = ui.PlatformDispatcher.instance.locale.languageCode.toLowerCase();
    if (_supportedLocales.contains(deviceLanguage)) {
      return deviceLanguage;
    }
  } catch (_) {}

  return 'en'; // Default fallback to English
}

/// Holds the active locale code (e.g. 'tr', 'en', 'es', etc.)
final localeProvider = StateProvider<String>((ref) {
  return _getInitialLocale();
});

/// Holds the sound effects preference.
final soundEnabledProvider = StateProvider<bool>((ref) => true);

/// Holds the background music preference.
final musicEnabledProvider = StateProvider<bool>((ref) => true);

/// Holds the vibration preference.
final vibrateEnabledProvider = StateProvider<bool>((ref) => true);
