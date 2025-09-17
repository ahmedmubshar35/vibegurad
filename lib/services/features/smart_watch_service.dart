import 'dart:async';
import 'package:flutter/services.dart';
import 'package:injectable/injectable.dart';
import 'package:stacked_services/stacked_services.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../enums/exposure_level.dart';
import '../../models/timer/timer_session.dart';

@lazySingleton
class SmartWatchService {
  SnackbarService get _snackbarService => GetIt.instance<SnackbarService>();
  
  static const MethodChannel _channel = MethodChannel('vibe_guard/smart_watch');
  SharedPreferences? _prefs;
  StreamController<WatchConnectionStatus>? _connectionController;
  bool _isConnected = false;
  String? _connectedDeviceName;

  SmartWatchService();

  // Initialize the service
  Future<void> initialize() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      _connectionController = StreamController<WatchConnectionStatus>.broadcast();
      
      // Set up method call handler for watch events
      _channel.setMethodCallHandler(_handleWatchMethodCall);
      
      // Check for existing connections
      await _checkExistingConnection();
    } catch (e) {
      _snackbarService.showSnackbar(
        message: 'Failed to initialize smart watch service: $e',
      );
    }
  }

  // Handle method calls from native platforms
  Future<dynamic> _handleWatchMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onWatchConnected':
        final deviceName = call.arguments['deviceName'] as String?;
        await _onWatchConnected(deviceName);
        break;
      case 'onWatchDisconnected':
        await _onWatchDisconnected();
        break;
      case 'onWatchDataReceived':
        final data = call.arguments['data'] as Map<String, dynamic>?;
        await _onWatchDataReceived(data);
        break;
      case 'onWatchError':
        final error = call.arguments['error'] as String?;
        await _onWatchError(error);
        break;
    }
  }

  // Check for existing watch connection
  Future<void> _checkExistingConnection() async {
    try {
      final result = await _channel.invokeMethod('checkConnection');
      if (result != null && result['isConnected'] == true) {
        _isConnected = true;
        _connectedDeviceName = result['deviceName'];
        _connectionController?.add(WatchConnectionStatus.connected);
      }
    } catch (e) {
      // No existing connection or platform doesn't support watches
    }
  }

  // Connection management
  Future<bool> scanForWatches() async {
    try {
      if (!await isWatchSupportEnabled()) {
        return false;
      }

      final result = await _channel.invokeMethod('scanForWatches');
      return result == true;
    } catch (e) {
      _snackbarService.showSnackbar(
        message: 'Failed to scan for smart watches: $e',
      );
      return false;
    }
  }

  Future<bool> connectToWatch(String deviceId) async {
    try {
      final result = await _channel.invokeMethod('connectToWatch', {
        'deviceId': deviceId,
      });
      return result == true;
    } catch (e) {
      _snackbarService.showSnackbar(
        message: 'Failed to connect to smart watch: $e',
      );
      return false;
    }
  }

  Future<void> disconnectWatch() async {
    try {
      await _channel.invokeMethod('disconnectWatch');
      _isConnected = false;
      _connectedDeviceName = null;
      _connectionController?.add(WatchConnectionStatus.disconnected);
    } catch (e) {
      _snackbarService.showSnackbar(
        message: 'Failed to disconnect smart watch: $e',
      );
    }
  }

  // Alert methods
  Future<void> sendExposureAlert(ExposureLevel level, {
    String? message,
    Map<String, dynamic>? data,
  }) async {
    if (!_isConnected || !await isWatchSupportEnabled()) return;

    try {
      final alertData = {
        'type': 'exposure_alert',
        'level': level.name,
        'message': message ?? _getDefaultExposureMessage(level),
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'vibrationPattern': _getVibrationPattern(level),
        'data': data ?? {},
      };

      await _channel.invokeMethod('sendWatchAlert', alertData);
    } catch (e) {
      _snackbarService.showSnackbar(
        message: 'Failed to send watch alert: $e',
      );
    }
  }

  Future<void> sendRestBreakAlert({
    required int restMinutes,
    String? toolName,
  }) async {
    if (!_isConnected || !await isWatchSupportEnabled()) return;

    try {
      final alertData = {
        'type': 'rest_break',
        'message': 'Time for ${restMinutes}min break${toolName != null ? ' from $toolName' : ''}',
        'restMinutes': restMinutes,
        'toolName': toolName,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'vibrationPattern': 'gentle_reminder',
      };

      await _channel.invokeMethod('sendWatchAlert', alertData);
    } catch (e) {
      _snackbarService.showSnackbar(
        message: 'Failed to send rest break alert to watch: $e',
      );
    }
  }

  Future<void> sendEmergencyStopAlert({
    required String reason,
    String? toolName,
  }) async {
    if (!_isConnected || !await isWatchSupportEnabled()) return;

    try {
      final alertData = {
        'type': 'emergency_stop',
        'message': 'EMERGENCY STOP: $reason',
        'reason': reason,
        'toolName': toolName,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'vibrationPattern': 'urgent_emergency',
        'priority': 'critical',
      };

      await _channel.invokeMethod('sendWatchAlert', alertData);
    } catch (e) {
      _snackbarService.showSnackbar(
        message: 'Failed to send emergency alert to watch: $e',
      );
    }
  }

  Future<void> sendSessionUpdate(TimerSession session) async {
    if (!_isConnected || !await isWatchSupportEnabled()) return;

    try {
      final sessionData = {
        'type': 'session_update',
        'toolName': session.tool?.name ?? 'Unknown Tool',
        'duration': session.totalMinutes,
        'status': session.isActive ? 'active' : session.isCompleted ? 'completed' : 'paused',
        'vibrationLevel': session.tool?.vibrationLevel ?? 0.0,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      await _channel.invokeMethod('sendWatchUpdate', sessionData);
    } catch (e) {
      // Silent fail for session updates
    }
  }

  Future<void> sendDailySummary({
    required Map<String, int> toolUsage,
    required int totalExposure,
    required double dailyA8,
  }) async {
    if (!_isConnected || !await isWatchSupportEnabled()) return;

    try {
      final summaryData = {
        'type': 'daily_summary',
        'totalExposure': totalExposure,
        'dailyA8': dailyA8,
        'toolCount': toolUsage.length,
        'mostUsedTool': toolUsage.entries.isNotEmpty 
            ? toolUsage.entries.reduce((a, b) => a.value > b.value ? a : b).key
            : 'None',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      await _channel.invokeMethod('sendWatchUpdate', summaryData);
    } catch (e) {
      // Silent fail for daily summary
    }
  }

  // Health monitoring
  Future<WatchHealthData?> requestHealthData() async {
    if (!_isConnected) return null;

    try {
      final result = await _channel.invokeMethod('getWatchHealthData');
      if (result != null) {
        return WatchHealthData.fromMap(result);
      }
    } catch (e) {
      // Silent fail for health data
    }
    return null;
  }

  Future<void> requestHeartRateMonitoring(bool enabled) async {
    if (!_isConnected) return;

    try {
      await _channel.invokeMethod('setHeartRateMonitoring', {
        'enabled': enabled,
      });
    } catch (e) {
      _snackbarService.showSnackbar(
        message: 'Failed to configure heart rate monitoring: $e',
      );
    }
  }

  // Event handlers
  Future<void> _onWatchConnected(String? deviceName) async {
    _isConnected = true;
    _connectedDeviceName = deviceName;
    _connectionController?.add(WatchConnectionStatus.connected);
    
    _snackbarService.showSnackbar(
      message: 'Smart watch connected: ${deviceName ?? 'Unknown Device'}',
    );
  }

  Future<void> _onWatchDisconnected() async {
    _isConnected = false;
    _connectedDeviceName = null;
    _connectionController?.add(WatchConnectionStatus.disconnected);
    
    _snackbarService.showSnackbar(
      message: 'Smart watch disconnected',
    );
  }

  Future<void> _onWatchDataReceived(Map<String, dynamic>? data) async {
    if (data == null) return;

    final type = data['type'] as String?;
    switch (type) {
      case 'health_data':
        // Handle health data updates
        break;
      case 'user_response':
        // Handle user interactions from watch
        break;
      case 'emergency_trigger':
        // Handle emergency button press from watch
        await _handleWatchEmergencyTrigger(data);
        break;
    }
  }

  Future<void> _onWatchError(String? error) async {
    _snackbarService.showSnackbar(
      message: 'Smart watch error: ${error ?? 'Unknown error'}',
    );
  }

  Future<void> _handleWatchEmergencyTrigger(Map<String, dynamic> data) async {
    // Notify main app of emergency trigger from watch
    _snackbarService.showSnackbar(
      message: 'Emergency triggered from smart watch',
    );
    // Could trigger emergency stop or alert supervisors
  }

  // Helper methods
  String _getDefaultExposureMessage(ExposureLevel level) {
    switch (level) {
      case ExposureLevel.low:
        return 'Exposure level: Safe';
      case ExposureLevel.medium:
        return 'Exposure level: Caution';
      case ExposureLevel.high:
        return 'Exposure level: Warning';
      case ExposureLevel.critical:
        return 'CRITICAL: Exposure limit exceeded!';
    }
  }

  String _getVibrationPattern(ExposureLevel level) {
    switch (level) {
      case ExposureLevel.low:
        return 'gentle_single';
      case ExposureLevel.medium:
        return 'moderate_double';
      case ExposureLevel.high:
        return 'strong_triple';
      case ExposureLevel.critical:
        return 'urgent_continuous';
    }
  }

  // Settings management
  Future<void> setWatchSupportEnabled(bool enabled) async {
    await _prefs?.setBool('watch_support_enabled', enabled);
  }

  Future<bool> isWatchSupportEnabled() async {
    return _prefs?.getBool('watch_support_enabled') ?? false;
  }

  Future<void> setWatchNotificationsEnabled(bool enabled) async {
    await _prefs?.setBool('watch_notifications_enabled', enabled);
  }

  Future<bool> areWatchNotificationsEnabled() async {
    return _prefs?.getBool('watch_notifications_enabled') ?? true;
  }

  // Getters
  bool get isConnected => _isConnected;
  String? get connectedDeviceName => _connectedDeviceName;
  Stream<WatchConnectionStatus> get connectionStream => 
      _connectionController?.stream ?? const Stream.empty();

  // Dispose service
  void dispose() {
    _connectionController?.close();
  }
}

// Data models
enum WatchConnectionStatus {
  disconnected,
  connecting,
  connected,
  error,
}

class WatchHealthData {
  final int? heartRate;
  final double? stressLevel;
  final int? steps;
  final DateTime timestamp;

  WatchHealthData({
    this.heartRate,
    this.stressLevel,
    this.steps,
    required this.timestamp,
  });

  factory WatchHealthData.fromMap(Map<String, dynamic> map) {
    return WatchHealthData(
      heartRate: map['heartRate']?.toInt(),
      stressLevel: map['stressLevel']?.toDouble(),
      steps: map['steps']?.toInt(),
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        map['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'heartRate': heartRate,
      'stressLevel': stressLevel,
      'steps': steps,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }
}

class SmartWatchSettings {
  final bool enabled;
  final bool notificationsEnabled;
  final bool heartRateMonitoring;
  final Map<String, bool> alertTypes;

  SmartWatchSettings({
    required this.enabled,
    required this.notificationsEnabled,
    required this.heartRateMonitoring,
    required this.alertTypes,
  });

  factory SmartWatchSettings.defaults() {
    return SmartWatchSettings(
      enabled: false,
      notificationsEnabled: true,
      heartRateMonitoring: false,
      alertTypes: {
        'exposure_alerts': true,
        'rest_breaks': true,
        'emergency_stops': true,
        'session_updates': false,
        'daily_summary': true,
      },
    );
  }

  SmartWatchSettings copyWith({
    bool? enabled,
    bool? notificationsEnabled,
    bool? heartRateMonitoring,
    Map<String, bool>? alertTypes,
  }) {
    return SmartWatchSettings(
      enabled: enabled ?? this.enabled,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      heartRateMonitoring: heartRateMonitoring ?? this.heartRateMonitoring,
      alertTypes: alertTypes ?? this.alertTypes,
    );
  }
}