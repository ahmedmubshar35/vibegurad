import 'dart:async';
import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';
import 'package:get_it/get_it.dart';

import '../../../services/features/timer_service.dart';
import '../../../services/features/notification_service.dart';
import '../../../services/features/tool_service.dart';
import '../../../services/core/authentication_service.dart';
import '../../../models/timer/timer_session.dart';
import '../../../models/tool/tool.dart';
import '../../../enums/timer_status.dart';
import '../../../enums/exposure_level.dart';
import '../../../app/app.router.dart';

class TimerViewModel extends ReactiveViewModel {
  final TimerService _timerService = GetIt.instance<TimerService>();
  final NotificationService _notificationService = GetIt.instance<NotificationService>();
  final NavigationService _navigationService = GetIt.instance<NavigationService>();
  final SnackbarService _snackbarService = GetIt.instance<SnackbarService>();
  final ToolService _toolService = GetIt.instance<ToolService>();
  final AuthenticationService _authService = GetIt.instance<AuthenticationService>();

  @override
  List<ListenableServiceMixin> get listenableServices => [_timerService];

  // Getters for reactive properties
  TimerSession? get activeSession => _timerService.activeSession;
  TimerStatus get status => _timerService.status;
  Duration get elapsedTime => _timerService.currentSessionDuration;
  Tool? get currentTool => _timerService.currentTool;
  ExposureLevel get exposureLevel => _timerService.exposureLevel;
  
  bool get hasActiveSession => activeSession != null;
  bool get isRunning => status == TimerStatus.running;
  bool get isPaused => status == TimerStatus.paused;
  bool get isStopped => status == TimerStatus.stopped || status == TimerStatus.completed;

  // Session statistics
  Map<String, dynamic> get sessionStats => _timerService.getSessionStats();
  double get exposurePercentage => (sessionStats['percentage'] as double?) ?? 0.0;
  bool get isNearLimit => (sessionStats['isNearLimit'] as bool?) ?? false;
  bool get isAtLimit => (sessionStats['isAtLimit'] as bool?) ?? false;
  bool get isOverLimit => (sessionStats['isOverLimit'] as bool?) ?? false;

  // Display formatting
  String get formattedElapsedTime {
    final hours = elapsedTime.inHours;
    final minutes = elapsedTime.inMinutes % 60;
    final seconds = elapsedTime.inSeconds % 60;
    
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
  }

  String get remainingTimeText {
    if (currentTool == null) return 'No limit set';
    
    final limitMinutes = currentTool!.dailyExposureLimit;
    final elapsedMinutes = elapsedTime.inMinutes;
    final remainingMinutes = limitMinutes - elapsedMinutes;
    
    if (remainingMinutes <= 0) {
      return 'Limit exceeded';
    }
    
    final hours = remainingMinutes ~/ 60;
    final minutes = remainingMinutes % 60;
    
    if (hours > 0) {
      return '${hours}h ${minutes}m remaining';
    } else {
      return '${minutes}m remaining';
    }
  }

  String get exposureLevelText {
    switch (exposureLevel) {
      case ExposureLevel.low:
        return 'Safe - Low Exposure';
      case ExposureLevel.medium:
        return 'Moderate - Monitor Closely';
      case ExposureLevel.high:
        return 'High - Caution Required';
      case ExposureLevel.critical:
        return 'Critical - Stop Immediately';
    }
  }

  Color get exposureLevelColor {
    switch (exposureLevel) {
      case ExposureLevel.low:
        return Colors.green;
      case ExposureLevel.medium:
        return Colors.blue;
      case ExposureLevel.high:
        return Colors.orange;
      case ExposureLevel.critical:
        return Colors.red;
    }
  }

  String get toolDisplayName => currentTool?.displayName ?? 'Unknown Tool';
  String get toolVibrationInfo => currentTool?.vibrationMagnitude != null 
      ? '${currentTool!.vibrationMagnitude!.toStringAsFixed(1)} m/s²'
      : 'No vibration data';

  // Session controls
  Future<void> pauseSession() async {
    if (!hasActiveSession || !isRunning) return;
    
    setBusy(true);
    try {
      final success = await _timerService.pauseSession();
      if (success) {
        await _notificationService.showRestBreakReminder(
          toolName: toolDisplayName,
          restMinutes: 10,
        );
      }
    } finally {
      setBusy(false);
    }
  }

  Future<void> resumeSession() async {
    if (!hasActiveSession || !isPaused) return;
    
    setBusy(true);
    try {
      await _timerService.resumeSession();
    } finally {
      setBusy(false);
    }
  }

  Future<void> stopSession() async {
    if (!hasActiveSession) return;
    
    // Show confirmation dialog first
    final result = await _showStopConfirmationDialog();
    if (!result) return;
    
    setBusy(true);
    try {
      final success = await _timerService.stopSession();
      if (success) {
        await _notificationService.showSessionCompletionNotification(
          toolName: toolDisplayName,
          duration: elapsedTime,
          totalMinutes: elapsedTime.inMinutes,
        );
        
        // Navigate back to home
        _navigationService.back();
      }
    } finally {
      setBusy(false);
    }
  }

  Future<void> emergencyStop() async {
    if (!hasActiveSession) return;
    
    setBusy(true);
    try {
      const reason = 'Emergency stop triggered by user';
      final success = await _timerService.emergencyStop(reason);
      
      if (success) {
        await _notificationService.showEmergencyStopNotification(
          toolName: toolDisplayName,
          reason: reason,
        );
        
        // Navigate back to home immediately
        _navigationService.back();
      }
    } finally {
      setBusy(false);
    }
  }

  // Show stop confirmation dialog
  Future<bool> _showStopConfirmationDialog() async {
    // This will be handled by the view showing a dialog
    // For now, return true (proceed with stop)
    return true;
  }

  // Add rest break
  Future<void> takeRestBreak() async {
    if (!hasActiveSession) return;
    
    await pauseSession();
    
    _snackbarService.showSnackbar(
      message: 'Rest break started. Take at least 10 minutes off from vibrating tools.',
      duration: const Duration(seconds: 4),
    );
  }

  // Navigate to camera for tool recognition
  void scanNewTool() {
    _navigationService.navigateTo(Routes.cameraView);
  }

  // Navigate to tool selection (manual)
  Future<void> selectToolManually() async {
    setBusy(true);
    
    try {
      // Get company tools
      final currentUser = _authService.currentUser;
      if (currentUser?.companyId == null) {
        _snackbarService.showSnackbar(message: 'No company tools available');
        setBusy(false);
        return;
      }
      
      final toolsStream = _toolService.getCompanyTools(currentUser!.companyId!);
      final tools = await toolsStream.first;
      
      if (tools.isEmpty) {
        _snackbarService.showSnackbar(message: 'No tools found for your company');
        setBusy(false);
        return;
      }
      
      setBusy(false);
      
      // Show tool selection dialog
      _showToolSelectionDialog(tools);
      
    } catch (e) {
      setBusy(false);
      _snackbarService.showSnackbar(message: 'Error loading tools: $e');
    }
  }
  
  void _showToolSelectionDialog(List tools) {
    // For now, show a message that tools are available and navigate to tool management
    _snackbarService.showSnackbar(
      message: 'Found ${tools.length} tools. Tool selection dialog will be implemented.',
      duration: const Duration(seconds: 3),
    );
    
    // TODO: Implement custom tool selection dialog
    // For now, just use the first available tool as demonstration
    if (tools.isNotEmpty) {
      _startTimerWithTool(tools.first);
    }
  }
  
  void _startTimerWithTool(dynamic tool) {
    _navigationService.navigateTo('/active-timer', arguments: {
      'tool': tool,
      'startMode': 'manual'
    });
  }

  // Navigate to history
  void viewHistory() {
    _navigationService.navigateTo(Routes.historyView);
  }

  // Navigate back
  void goBack() {
    _navigationService.back();
  }

  // Get progress bar value (0.0 to 1.0)
  double get progressValue {
    if (currentTool == null) return 0.0;
    return (exposurePercentage / 100.0).clamp(0.0, 1.0);
  }

  // Get warnings and alerts from current session
  List<String> get sessionWarnings {
    return activeSession?.warnings ?? [];
  }

  List<String> get sessionAlerts {
    return activeSession?.alerts ?? [];
  }

  bool get hasWarnings => sessionWarnings.isNotEmpty;
  bool get hasAlerts => sessionAlerts.isNotEmpty;
}