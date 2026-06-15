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
