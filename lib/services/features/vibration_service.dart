import 'package:vibration/vibration.dart';
import 'package:injectable/injectable.dart';
import 'package:stacked_services/stacked_services.dart';
import 'package:get_it/get_it.dart';

import '../../enums/exposure_level.dart';

@lazySingleton
class VibrationService {
  SnackbarService get _snackbarService => GetIt.instance<SnackbarService>();

  // Check if vibration is available on device
  Future<bool> hasVibrator() async {
    try {
      return await Vibration.hasVibrator() ?? false;
    } catch (e) {
      return false;
    }
  }

  // Check if custom vibrations are supported
  Future<bool> hasCustomVibrationsSupport() async {
    try {
      return await Vibration.hasCustomVibrationsSupport() ?? false;
    } catch (e) {
      return false;
    }
  }

  // Simple vibration for general alerts
  Future<void> vibrateSimple({int duration = 500}) async {
    try {
      if (await hasVibrator()) {
        await Vibration.vibrate(duration: duration);
      }
    } catch (e) {
      // Silently handle vibration errors
    }
  }

  // Warning vibration pattern - short pulses
  Future<void> vibrateWarning() async {
    try {
      if (await hasCustomVibrationsSupport()) {
        // Pattern: vibrate 200ms, pause 100ms, vibrate 200ms
        await Vibration.vibrate(
          pattern: [0, 200, 100, 200],
        );
      } else if (await hasVibrator()) {
        // Fallback to simple vibration
        await Vibration.vibrate(duration: 400);
      }
    } catch (e) {
      // Silently handle vibration errors
    }
  }

  // Critical alert vibration - long intense pattern
  Future<void> vibrateCritical() async {
    try {
      if (await hasCustomVibrationsSupport()) {
        // Pattern: long-short-long-short-long (SOS-like)
        await Vibration.vibrate(
          pattern: [0, 500, 200, 200, 200, 500],
        );
      } else if (await hasVibrator()) {
        // Fallback to long vibration
        await Vibration.vibrate(duration: 1000);
      }
    } catch (e) {
      // Silently handle vibration errors
    }
  }

  // Rest break reminder - gentle pulsing pattern
  Future<void> vibrateRestReminder() async {
    try {
      if (await hasCustomVibrationsSupport()) {
        // Pattern: gentle double pulse
        await Vibration.vibrate(
          pattern: [0, 300, 150, 300, 300, 300, 150, 300],
        );
      } else if (await hasVibrator()) {
        // Fallback to medium vibration
        await Vibration.vibrate(duration: 600);
      }
    } catch (e) {
      // Silently handle vibration errors
    }
  }

  // Emergency stop - urgent continuous pattern
  Future<void> vibrateEmergency() async {
    try {
      if (await hasCustomVibrationsSupport()) {
        // Pattern: rapid urgent pulses
        await Vibration.vibrate(
          pattern: [0, 100, 50, 100, 50, 100, 50, 300, 100, 300],
        );
      } else if (await hasVibrator()) {
        // Fallback to long urgent vibration
        await Vibration.vibrate(duration: 800);
      }
    } catch (e) {
      // Silently handle vibration errors
    }
  }

  // Vibration based on exposure level
  Future<void> vibrateForExposureLevel(ExposureLevel level) async {
    switch (level) {
      case ExposureLevel.low:
        await vibrateSimple(duration: 200);
        break;
      case ExposureLevel.medium:
        await vibrateWarning();
        break;
      case ExposureLevel.high:
        await vibrateWarning();
        break;
      case ExposureLevel.critical:
        await vibrateCritical();
        break;
    }
  }

  // Stop all vibrations
  Future<void> cancel() async {
    try {
      await Vibration.cancel();
    } catch (e) {
      // Silently handle vibration errors
    }
  }
}