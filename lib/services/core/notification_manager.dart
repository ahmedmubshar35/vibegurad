import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter/material.dart';

/// Centralized notification manager to prevent duplicates and ensure consistent UX
class NotificationManager {
  static final NotificationManager _instance = NotificationManager._internal();
  factory NotificationManager() => _instance;
  NotificationManager._internal();

  // Track recent notifications to prevent spam
  String? _lastNotificationMessage;
  DateTime? _lastNotificationTime;
  static const Duration _cooldownDuration = Duration(seconds: 3);

  /// Show an error notification (always shows)
  void showError(String message) {
    _showToast(message, Colors.red, force: true, category: 'error');
  }

  /// Show a success notification
  void showSuccess(String message) {
    _showToast(message, Colors.green, category: 'success');
  }

  /// Show an info notification
  void showInfo(String message) {
    _showToast(message, Colors.blue, category: 'info');
  }

  /// Show a warning notification
  void showWarning(String message) {
    _showToast(message, Colors.orange, category: 'warning');
  }

  /// Clear notification history (useful when navigating between major sections)
  void clearHistory() {
    _lastNotificationMessage = null;
    _lastNotificationTime = null;
  }

  /// Show session-related notification (with session category)
  void showSessionNotification(String message) {
    _showToast(message, Colors.blue, force: true, category: 'session');
  }

  /// Show tool-related notification (with tool category)
  void showToolNotification(String message) {
    _showToast(message, Colors.purple, category: 'tool');
  }

  /// Show camera-related notification (with camera category)
  void showCameraNotification(String message) {
    _showToast(message, Colors.teal, category: 'camera');
  }

  /// Internal method to show colored toast with duplicate prevention
  void _showToast(
    String message,
    Color backgroundColor, {
    bool force = false,
    String? category,
  }) {
    final now = DateTime.now();

    // Create a unique key for this notification
    final notificationKey = category != null ? '$category:$message' : message;

    // Check if we should suppress this notification
    if (!force &&
        _lastNotificationMessage == notificationKey &&
        _lastNotificationTime != null &&
        now.difference(_lastNotificationTime!) < _cooldownDuration) {
      print('🔕 Toast suppressed (duplicate): $message');
      return;
    }

    // Track this notification
    _lastNotificationMessage = notificationKey;
    _lastNotificationTime = now;

    // Show the toast notification with ~1.5 seconds duration
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT, // ~2 seconds on Android, 1 second on iOS
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 1, // 1-1.5 seconds for iOS/Web
      backgroundColor: backgroundColor.withValues(alpha: 0.9),
      textColor: Colors.white,
      fontSize: 16.0,
      webBgColor: "linear-gradient(to right, #000000, #000000)",
      webPosition: "bottom",
    );
  }
}