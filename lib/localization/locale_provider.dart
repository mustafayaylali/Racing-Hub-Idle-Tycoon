import 'package:flutter_riverpod/flutter_riverpod.dart';

/// TR veya EN dil tercihini tutan Riverpod StateProvider.
/// Varsayılan değer Türkçe ('tr').
final localeProvider = StateProvider<String>((ref) => 'tr');

/// Ses efektleri tercihini tutan provider.
final soundEnabledProvider = StateProvider<bool>((ref) => true);

/// Arka plan müziği tercihini tutan provider.
final musicEnabledProvider = StateProvider<bool>((ref) => true);

/// Titreşim tercihini tutan provider.
final vibrateEnabledProvider = StateProvider<bool>((ref) => true);

