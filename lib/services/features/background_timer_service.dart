import 'dart:async';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:injectable/injectable.dart';
import 'package:stacked_services/stacked_services.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'timer_service.dart';
import '../../config/app_config.dart';

@lazySingleton
class BackgroundTimerService {
  static const String _sessionActiveKey = 'background_session_active';
  static const String _sessionStartTimeKey = 'background_session_start_time';
  static const String _sessionToolIdKey = 'background_session_tool_id';
  static const String _sessionUserIdKey = 'background_session_user_id';

  final TimerService _timerService = GetIt.instance<TimerService>();
  final SnackbarService _snackbarService = GetIt.instance<SnackbarService>();

  bool _isInitialized = false;
  Timer? _backgroundTimer;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize background service
      await FlutterBackgroundService().configure(
        androidConfiguration: AndroidConfiguration(
          onStart: onStart,
          autoStart: false,
          isForegroundMode: true,
          notificationChannelId: AppConfig.notificationChannelId,
          initialNotificationTitle: 'VibeGuard Timer',
          initialNotificationContent: 'Timer is running in background',
        ),
        iosConfiguration: IosConfiguration(
          autoStart: false,
          onForeground: onStart,
          onBackground: onIosBackground,
        ),
      );

      _isInitialized = true;
    } catch (e) {
      _snackbarService.showSnackbar(
        message: 'Failed to initialize background service: $e',
      );
    }
  }

  // Start background timer operation
  Future<void> startBackgroundTimer() async {
    if (!_isInitialized) await initialize();

    try {
      final currentSession = _timerService.currentSession;
      if (currentSession == null) return;

      // Save session info to persistent storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_sessionActiveKey, true);
      await prefs.setString(_sessionStartTimeKey, currentSession.startTime.toIso8601String());
      await prefs.setString(_sessionToolIdKey, currentSession.toolId);
      await prefs.setString(_sessionUserIdKey, currentSession.workerId);

      // Start background service
      await FlutterBackgroundService().startService();
      
      _snackbarService.showSnackbar(
        message: 'Timer will continue running in background',
      );
    } catch (e) {
      _snackbarService.showSnackbar(
        message: 'Failed to start background timer: $e',
      );
    }
  }

  // Stop background timer operation
  Future<void> stopBackgroundTimer() async {
    try {
      // Clear session info from persistent storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_sessionActiveKey);
      await prefs.remove(_sessionStartTimeKey);
      await prefs.remove(_sessionToolIdKey);
      await prefs.remove(_sessionUserIdKey);

      // Stop background service
      FlutterBackgroundService().invoke('stop_service');
    } catch (e) {
      _snackbarService.showSnackbar(
        message: 'Error stopping background timer: $e',
      );
    }
  }

  // Check if timer should continue running in background on app resume
  Future<void> checkAndRestoreBackgroundTimer() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isActive = prefs.getBool(_sessionActiveKey) ?? false;
      
      if (!isActive) return;

      final startTimeStr = prefs.getString(_sessionStartTimeKey);
      final toolId = prefs.getString(_sessionToolIdKey);
      final userId = prefs.getString(_sessionUserIdKey);

      if (startTimeStr != null && toolId != null && userId != null) {
        final startTime = DateTime.parse(startTimeStr);
        final elapsed = DateTime.now().difference(startTime);

        // Show notification about background timer
        _snackbarService.showSnackbar(
          message: 'Timer continued running in background for ${_formatDuration(elapsed)}',
          duration: const Duration(seconds: 4),
        );

        // Sync with timer service
        await _timerService.initialize();
      }
    } catch (e) {
      // Silently handle restoration errors
    }
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  // Dispose resources
  void dispose() {
    _backgroundTimer?.cancel();
  }
}

// Background service entry point
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  // Background timer logic runs here
  Timer.periodic(const Duration(seconds: 1), (timer) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isActive = prefs.getBool(BackgroundTimerService._sessionActiveKey) ?? false;
      
      if (!isActive) {
        timer.cancel();
        service.stopSelf();
        return;
      }

      final startTimeStr = prefs.getString(BackgroundTimerService._sessionStartTimeKey);
      if (startTimeStr != null) {
        final startTime = DateTime.parse(startTimeStr);
        final elapsed = DateTime.now().difference(startTime);
        
        // Update notification with current time
        service.invoke('update_notification', {
          'elapsed': elapsed.inSeconds,
          'title': 'VibeGuard Timer',
          'body': 'Running: ${_formatDurationBg(elapsed)}',
        });

        // Check for safety thresholds
        final minutes = elapsed.inMinutes;
        if (minutes > 0 && minutes % AppConfig.restPeriodMinutes == 0) {
          // Trigger rest break notification
          service.invoke('rest_break_alert', {
            'minutes': minutes,
          });
        }
      }
    } catch (e) {
      // Handle background errors silently
    }
  });

  service.on('stop_service').listen((event) {
    service.stopSelf();
  });

  service.on('update_notification').listen((event) {
    final data = event;
    if (data != null) {
      // Update foreground notification (method availability varies by platform)
      try {
        // This would be platform-specific implementation
        // For now, we'll skip the notification update
      } catch (e) {
        // Silently handle notification update errors
      }
    }
  });

  service.on('rest_break_alert').listen((event) {
    // Trigger system notification for rest break
    // This would use the notification channel configured
  });
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  // iOS background handling
  return true;
}

String _formatDurationBg(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);

  if (hours > 0) {
    return '${hours}h ${minutes}m ${seconds}s';
  } else if (minutes > 0) {
    return '${minutes}m ${seconds}s';  
  } else {
    return '${seconds}s';
  }
}