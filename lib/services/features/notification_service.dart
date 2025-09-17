import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:injectable/injectable.dart';
import 'package:stacked_services/stacked_services.dart';
import 'package:get_it/get_it.dart';

import '../../config/app_config.dart';
import '../../enums/exposure_level.dart';

@lazySingleton
class NotificationService {
  SnackbarService get _snackbarService => GetIt.instance<SnackbarService>();

  // Flutter Local Notifications
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  NotificationService();

  // Initialize the service
  Future<void> initialize() async {
    try {
      // Initialize Flutter Local Notifications
      await _initializeLocalNotifications();

    } catch (e) {
      _snackbarService.showSnackbar(
        message: 'Failed to initialize notifications: $e',
      );
    }
  }

  // Initialize Flutter Local Notifications
  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
  }

  // Show safety warning notification
  Future<void> showSafetyWarning({
    required String title,
    required String body,
    required ExposureLevel level,
    Map<String, String>? payload,
  }) async {
    try {
      final icon = _getExposureLevelIcon(level);
      final id = DateTime.now().millisecondsSinceEpoch.remainder(100000);

      const androidDetails = AndroidNotificationDetails(
        'safety_warnings',
        'Safety Warnings',
        channelDescription: 'Critical safety notifications for tool exposure',
        importance: Importance.high,
        priority: Priority.high,
        enableVibration: true,
        enableLights: true,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _localNotifications.show(
        id,
        '$icon $title',
        body,
        details,
        payload: 'safety_warning,${level.name}',
      );
    } catch (e) {
      _snackbarService.showSnackbar(
        message: 'Failed to show safety warning: $e',
      );
    }
  }

  // Show exposure limit notification
  Future<void> showExposureLimitNotification({
    required String toolName,
    required int percentage,
    required int remainingMinutes,
  }) async {
    final level = ExposureLevel.fromUsagePercentage(percentage.toDouble());

    await showSafetyWarning(
      title: 'Exposure Limit Alert',
      body: 'You have used $toolName for ${percentage}% of your daily limit. '
            '${remainingMinutes} minutes remaining.',
      level: level,
      payload: {'tool': toolName, 'percentage': percentage.toString()},
    );
  }

  // Show percentage-based exposure notifications (75%, 90%, 100%)
  Future<void> showPercentageBasedExposureNotification({
    required String toolName,
    required int percentage,
    required double currentA8,
    required int totalExposureMinutes,
    required int remainingMinutes,
  }) async {
    String title;
    String body;
    ExposureLevel level;
    bool isCritical = false;

    switch (percentage) {
      case 75:
        title = '⚠️ Approaching Exposure Limit';
        body = '$toolName usage at 75% of daily limit.\n'
               'Current A(8): ${currentA8.toStringAsFixed(2)} m/s²\n'
               'Time remaining: ${remainingMinutes}min';
        level = ExposureLevel.medium;
        break;
      case 90:
        title = '🔶 High Exposure Warning';
        body = '$toolName usage at 90% of daily limit!\n'
               'Current A(8): ${currentA8.toStringAsFixed(2)} m/s²\n'
               'Only ${remainingMinutes}min remaining - consider rest break';
        level = ExposureLevel.high;
        break;
      case 100:
        title = '🚨 DAILY LIMIT REACHED';
        body = '$toolName daily exposure limit exceeded!\n'
               'A(8): ${currentA8.toStringAsFixed(2)} m/s² (Limit: 2.5 m/s²)\n'
               'Total: ${totalExposureMinutes}min - STOP USAGE IMMEDIATELY';
        level = ExposureLevel.critical;
        isCritical = true;
        break;
      default:
        // Fallback for other percentages
        title = 'Exposure Limit Update';
        body = '$toolName usage at ${percentage}% of daily limit';
        level = percentage >= 95 ? ExposureLevel.critical :
               percentage >= 80 ? ExposureLevel.high :
               percentage >= 60 ? ExposureLevel.medium : ExposureLevel.low;
    }

    final id = DateTime.now().millisecondsSinceEpoch.remainder(100000);
    final importance = isCritical ? Importance.max : Importance.high;
    final priority = isCritical ? Priority.max : Priority.high;

    final androidDetails = AndroidNotificationDetails(
      'exposure_warnings',
      'Exposure Warnings',
      channelDescription: 'Vibration exposure limit notifications',
      importance: importance,
      priority: priority,
      enableVibration: true,
      enableLights: true,
      ongoing: isCritical,
      autoCancel: !isCritical,
      styleInformation: const BigTextStyleInformation(''),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      id,
      title,
      body,
      details,
      payload: 'percentage_exposure,$toolName,$percentage',
    );
  }

  // Show approaching exposure limit notification (generic)
  Future<void> showApproachingExposureLimitNotification({
    required String toolName,
    required double currentA8,
    required double actionValue,
    required int totalExposureMinutes,
    required int estimatedRemainingMinutes,
  }) async {
    final percentage = ((currentA8 / actionValue) * 100).round();
    final id = DateTime.now().millisecondsSinceEpoch.remainder(100000);

    const androidDetails = AndroidNotificationDetails(
      'approaching_limit',
      'Approaching Limits',
      channelDescription: 'Notifications when approaching exposure limits',
      importance: Importance.high,
      priority: Priority.high,
      enableVibration: true,
      styleInformation: BigTextStyleInformation(''),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      id,
      '📈 Exposure Increasing',
      '$toolName exposure approaching action value\n'
      'Current: ${currentA8.toStringAsFixed(2)} m/s² (${percentage}% of limit)\n'
      'Est. safe time remaining: ${estimatedRemainingMinutes}min',
      details,
      payload: 'approaching_limit,$toolName,$percentage',
    );
  }

  // Show rest break reminder
  Future<void> showRestBreakReminder({
    required String toolName,
    required int restMinutes,
  }) async {
    final id = DateTime.now().millisecondsSinceEpoch.remainder(100000);

    const androidDetails = AndroidNotificationDetails(
      'rest_breaks',
      'Rest Break Reminders',
      channelDescription: 'Reminders to take rest breaks',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      enableVibration: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      id,
      '⏰ Rest Break Reminder',
      'Time to take a $restMinutes-minute break from $toolName.',
      details,
      payload: 'rest_break,$toolName',
    );
  }

  // Show emergency stop notification
  Future<void> showEmergencyStopNotification({
    required String toolName,
    required String reason,
  }) async {
    final id = DateTime.now().millisecondsSinceEpoch.remainder(100000);

    const androidDetails = AndroidNotificationDetails(
      'emergency_stops',
      'Emergency Stops',
      channelDescription: 'Critical emergency stop notifications',
      importance: Importance.max,
      priority: Priority.max,
      enableVibration: true,
      enableLights: true,
      ongoing: true,
      autoCancel: false,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.critical,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      id,
      '🚨 EMERGENCY STOP',
      'Tool usage stopped: $reason',
      details,
      payload: 'emergency_stop,$toolName',
    );
  }

  // Show session completion notification
  Future<void> showSessionCompletionNotification({
    required String toolName,
    required Duration duration,
    required int totalMinutes,
  }) async {
    final id = DateTime.now().millisecondsSinceEpoch.remainder(100000);

    const androidDetails = AndroidNotificationDetails(
      'session_complete',
      'Session Completion',
      channelDescription: 'Notifications when tool sessions are completed',
      importance: Importance.low,
      priority: Priority.low,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: false,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      id,
      '✅ Session Complete',
      'Completed $toolName session: ${duration.inMinutes} minutes '
      '($totalMinutes total today)',
      details,
      payload: 'session_complete,$toolName',
    );
  }

  // Show daily summary notification
  Future<void> showDailySummaryNotification({
    required Map<String, int> toolUsage,
    required int totalExposure,
  }) async {
    final toolList = toolUsage.entries
        .map((e) => '${e.key}: ${e.value} min')
        .join(', ');

    final id = DateTime.now().millisecondsSinceEpoch.remainder(100000);

    const androidDetails = AndroidNotificationDetails(
      'daily_summary',
      'Daily Summary',
      channelDescription: 'Daily usage summary notifications',
      importance: Importance.low,
      priority: Priority.low,
      styleInformation: BigTextStyleInformation(''),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: false,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      id,
      '📊 Daily Summary',
      'Total exposure: $totalExposure minutes\n$toolList',
      details,
      payload: 'daily_summary',
    );
  }

  // Get exposure level color
  Color _getExposureLevelColor(ExposureLevel level) {
    switch (level) {
      case ExposureLevel.low:
        return const Color(0xFF4CAF50);
      case ExposureLevel.medium:
        return const Color(0xFFFF9800);
      case ExposureLevel.high:
        return const Color(0xFFFF5722);
      case ExposureLevel.critical:
        return const Color(0xFFF44336);
    }
  }

  // Get exposure level icon
  String _getExposureLevelIcon(ExposureLevel level) {
    switch (level) {
      case ExposureLevel.low:
        return '🟢';
      case ExposureLevel.medium:
        return '🟡';
      case ExposureLevel.high:
        return '🟠';
      case ExposureLevel.critical:
        return '🔴';
    }
  }

  // Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    // Handle notification tap based on payload
    final payload = response.payload;
    if (payload != null) {
      // Navigate based on notification type
      final type = payload.split(',').first;
      switch (type) {
        case 'safety_warning':
          // Navigate to timer view
          break;
        case 'rest_break':
          // Navigate to rest break screen
          break;
        case 'emergency_stop':
          // Navigate to emergency screen
          break;
        case 'session_complete':
          // Navigate to history
          break;
        case 'daily_summary':
          // Navigate to dashboard
          break;
      }
    }
  }

  // Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _localNotifications.cancelAll();
  }

  // Cancel specific notification
  Future<void> cancelNotification(int id) async {
    await _localNotifications.cancel(id);
  }

  // Check notification permissions
  Future<bool> areNotificationsEnabled() async {
    final result = await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.areNotificationsEnabled();
    return result ?? true;
  }

  // Request notification permissions
  Future<bool> requestNotificationPermissions() async {
    final result = await _localNotifications
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
    return result ?? true;
  }

  // Dispose service
  void dispose() {
    // Flutter local notifications doesn't need explicit disposal
  }
}