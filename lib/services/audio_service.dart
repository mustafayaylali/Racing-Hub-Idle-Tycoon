import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../localization/locale_provider.dart';

enum HapticType { light, medium, heavy, selection }

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  final AudioPlayer _sfxPlayer = AudioPlayer();
  final AudioPlayer _bgmPlayer = AudioPlayer();
  bool _isBgmPlaying = false;

  /// Trigger haptic vibration based on user preference
  void triggerVibration(WidgetRef ref, {HapticType type = HapticType.light}) {
    final bool isVibrateEnabled = ref.read(vibrateEnabledProvider);
    if (!isVibrateEnabled) return;

    switch (type) {
      case HapticType.light:
        HapticFeedback.lightImpact();
        break;
      case HapticType.medium:
        HapticFeedback.mediumImpact();
        break;
      case HapticType.heavy:
        HapticFeedback.heavyImpact();
        break;
      case HapticType.selection:
        HapticFeedback.selectionClick();
        break;
    }
  }

  /// Play sound effect if enabled
  Future<void> _playSfx(WidgetRef ref, String assetName) async {
    final bool isSoundEnabled = ref.read(soundEnabledProvider);
    if (!isSoundEnabled) return;

    try {
      await _sfxPlayer.stop();
      await _sfxPlayer.play(AssetSource('audio/$assetName'));
    } catch (_) {
      // Silently handle missing asset files until added by user
    }
  }

  /// Helper methods for common sound effects & haptics
  void playClick(WidgetRef ref) {
    triggerVibration(ref, type: HapticType.light);
    _playSfx(ref, 'click.mp3');
  }

  void playUpgrade(WidgetRef ref) {
    triggerVibration(ref, type: HapticType.medium);
    _playSfx(ref, 'upgrade.mp3');
  }

  void playWin(WidgetRef ref) {
    triggerVibration(ref, type: HapticType.heavy);
    _playSfx(ref, 'win.mp3');
  }

  void playCollect(WidgetRef ref) {
    triggerVibration(ref, type: HapticType.selection);
    _playSfx(ref, 'collect.mp3');
  }

  /// Start playing background music
  Future<void> startBgm(WidgetRef ref, {String assetName = 'bgm.mp3'}) async {
    final bool isMusicEnabled = ref.read(musicEnabledProvider);
    if (!isMusicEnabled) {
      stopBgm();
      return;
    }

    if (_isBgmPlaying) return;

    try {
      await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
      await _bgmPlayer.play(AssetSource('audio/$assetName'));
      _isBgmPlaying = true;
    } catch (_) {
      // Silently handle missing asset files until added by user
    }
  }

  /// Stop background music
  Future<void> stopBgm() async {
    try {
      await _bgmPlayer.stop();
      _isBgmPlaying = false;
    } catch (_) {}
  }

  /// Update BGM state when user toggles settings
  void updateBgmState(WidgetRef ref) {
    final bool isMusicEnabled = ref.read(musicEnabledProvider);
    if (isMusicEnabled && !_isBgmPlaying) {
      startBgm(ref);
    } else if (!isMusicEnabled && _isBgmPlaying) {
      stopBgm();
    }
  }
}

final audioServiceProvider = Provider<AudioService>((ref) => AudioService());
