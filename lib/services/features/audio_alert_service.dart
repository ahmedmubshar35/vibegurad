import 'package:flutter/services.dart';
import 'package:injectable/injectable.dart';
import 'package:stacked_services/stacked_services.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../enums/exposure_level.dart';

@lazySingleton
class AudioAlertService {
  SnackbarService get _snackbarService => GetIt.instance<SnackbarService>();
  
  // Audio player removed - using system sounds only
  SharedPreferences? _prefs;
  
  // Available alert sounds
  static const Map<String, String> alertSounds = {
    'beep_short': 'sounds/beep_short.mp3',
    'beep_long': 'sounds/beep_long.mp3',
    'chime_warning': 'sounds/chime_warning.mp3',
    'siren_emergency': 'sounds/siren_emergency.mp3',
    'bell_rest': 'sounds/bell_rest.mp3',
    'buzzer_critical': 'sounds/buzzer_critical.mp3',
    'notification_gentle': 'sounds/notification_gentle.mp3',
  };

  // Default sound assignments
  static const Map<ExposureLevel, String> defaultSoundMapping = {
    ExposureLevel.low: 'notification_gentle',
    ExposureLevel.medium: 'chime_warning',
    ExposureLevel.high: 'beep_long',
    ExposureLevel.critical: 'siren_emergency',
  };

  AudioAlertService();

  // Initialize the service
  Future<void> initialize() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      
      // Audio context setup removed - using system sounds
    } catch (e) {
      _snackbarService.showSnackbar(
        message: 'Failed to initialize audio alerts: $e',
      );
    }
  }

  // Play alert sound based on exposure level
  Future<void> playAlertForExposureLevel(ExposureLevel level) async {
    final soundKey = getSelectedSoundForLevel(level);
    await playAlert(soundKey);
  }

  // Play specific alert sound
  Future<void> playAlert(String soundKey) async {
    try {
      if (!alertSounds.containsKey(soundKey)) {
        throw Exception('Sound not found: $soundKey');
      }

      if (!await isAudioEnabled()) {
        return; // Audio alerts disabled
      }

      // Custom sound playback not available - using system sound
      await _playSystemSound();
    } catch (e) {
      // Fallback to system sound
      await _playSystemSound();
      _snackbarService.showSnackbar(
        message: 'Custom audio alert failed, using system sound',
      );
    }
  }

  // Play system sound fallback
  Future<void> _playSystemSound() async {
    try {
      await SystemSound.play(SystemSoundType.alert);
    } catch (e) {
      // Silent fallback if system sound also fails
    }
  }

  // Play custom warning patterns
  Future<void> playWarningPattern() async {
    try {
      if (!await isAudioEnabled()) return;

      // Play triple beep warning
      for (int i = 0; i < 3; i++) {
        await playAlert('beep_short');
        await Future.delayed(const Duration(milliseconds: 200));
      }
    } catch (e) {
      await _playSystemSound();
    }
  }

  // Play critical alert pattern
  Future<void> playCriticalPattern() async {
    try {
      if (!await isAudioEnabled()) return;

      // Play urgent siren pattern
      // Play urgent pattern with system sounds
      for (int i = 0; i < 5; i++) {
        await _playSystemSound();
        await Future.delayed(const Duration(milliseconds: 100));
      }
    } catch (e) {
      await _playSystemSound();
    }
  }

  // Play rest break reminder
  Future<void> playRestReminder() async {
    try {
      if (!await isAudioEnabled()) return;

      await playAlert('bell_rest');
    } catch (e) {
      await _playSystemSound();
    }
  }

  // Play emergency stop sound
  Future<void> playEmergencyStop() async {
    try {
      if (!await isAudioEnabled()) return;

      // Play urgent buzzer
      await playAlert('buzzer_critical');
    } catch (e) {
      await _playSystemSound();
    }
  }

  // Settings management
  Future<void> setAudioEnabled(bool enabled) async {
    await _prefs?.setBool('audio_alerts_enabled', enabled);
  }

  Future<bool> isAudioEnabled() async {
    return _prefs?.getBool('audio_alerts_enabled') ?? true;
  }

  Future<void> setVolumeLevel(double volume) async {
    final clampedVolume = volume.clamp(0.0, 1.0);
    await _prefs?.setDouble('audio_volume', clampedVolume);
    // Volume control not available with system sounds
  }

  Future<double> getVolumeLevel() async {
    return _prefs?.getDouble('audio_volume') ?? 0.7;
  }

  // Sound selection per exposure level
  Future<void> setSoundForLevel(ExposureLevel level, String soundKey) async {
    if (!alertSounds.containsKey(soundKey)) {
      throw Exception('Invalid sound key: $soundKey');
    }
    await _prefs?.setString('sound_${level.name}', soundKey);
  }

  String getSelectedSoundForLevel(ExposureLevel level) {
    final saved = _prefs?.getString('sound_${level.name}');
    return saved ?? defaultSoundMapping[level] ?? 'notification_gentle';
  }

  // Test sound functionality
  Future<void> testSound(String soundKey) async {
    try {
      await playAlert(soundKey);
    } catch (e) {
      _snackbarService.showSnackbar(
        message: 'Failed to play test sound: $e',
      );
    }
  }

  // Get sound display name
  String getSoundDisplayName(String soundKey) {
    switch (soundKey) {
      case 'beep_short':
        return 'Short Beep';
      case 'beep_long':
        return 'Long Beep';
      case 'chime_warning':
        return 'Warning Chime';
      case 'siren_emergency':
        return 'Emergency Siren';
      case 'bell_rest':
        return 'Rest Bell';
      case 'buzzer_critical':
        return 'Critical Buzzer';
      case 'notification_gentle':
        return 'Gentle Notification';
      default:
        return soundKey;
    }
  }

  // Stop all audio
  Future<void> stopAllAudio() async {
    // System sounds cannot be stopped programmatically
  }

  // Dispose service
  void dispose() {
    // No resources to dispose for system sounds
  }
}

// Audio alert settings model
class AudioAlertSettings {
  final bool enabled;
  final double volume;
  final Map<ExposureLevel, String> soundMapping;

  AudioAlertSettings({
    required this.enabled,
    required this.volume,
    required this.soundMapping,
  });

  factory AudioAlertSettings.defaults() {
    return AudioAlertSettings(
      enabled: true,
      volume: 0.7,
      soundMapping: Map.from(AudioAlertService.defaultSoundMapping),
    );
  }

  AudioAlertSettings copyWith({
    bool? enabled,
    double? volume,
    Map<ExposureLevel, String>? soundMapping,
  }) {
    return AudioAlertSettings(
      enabled: enabled ?? this.enabled,
      volume: volume ?? this.volume,
      soundMapping: soundMapping ?? this.soundMapping,
    );
  }
}