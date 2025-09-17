import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';
import 'package:get_it/get_it.dart';

import '../../models/timer/timer_session.dart';
import '../../models/tool/tool.dart';
import '../../models/core/user.dart';
import '../../enums/timer_status.dart';
import '../../enums/exposure_level.dart';
import '../../config/firebase_config.dart';
import '../../config/app_config.dart';
import 'notification_service.dart';
import 'vibration_service.dart';
import 'exposure_calculation_service.dart';
import 'background_timer_service.dart';

@lazySingleton
class TimerService with ListenableServiceMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  SnackbarService get _snackbarService => GetIt.instance<SnackbarService>();
  NotificationService get _notificationService => GetIt.instance<NotificationService>();
  VibrationService get _vibrationService => GetIt.instance<VibrationService>();
  ExposureCalculationService get _exposureService => GetIt.instance<ExposureCalculationService>();
  BackgroundTimerService get _backgroundService => GetIt.instance<BackgroundTimerService>();

  TimerService() {
    listenToReactiveValues([
      _currentSession,
      _isRunning,
      _elapsedTime,
      _remainingTime,
      _exposureLevel,
    ]);
  }

  // Reactive values
  final ReactiveValue<TimerSession?> _currentSession = ReactiveValue<TimerSession?>(null);
  final ReactiveValue<bool> _isRunning = ReactiveValue<bool>(false);
  final ReactiveValue<Duration> _elapsedTime = ReactiveValue<Duration>(Duration.zero);
  final ReactiveValue<Duration> _remainingTime = ReactiveValue<Duration>(Duration.zero);
  final ReactiveValue<ExposureLevel> _exposureLevel = ReactiveValue<ExposureLevel>(ExposureLevel.low);

  TimerSession? get currentSession => _currentSession.value;
  bool get isRunning => _isRunning.value;
  Duration get elapsedTime => _elapsedTime.value;
  Duration get remainingTime => _remainingTime.value;
  ExposureLevel get exposureLevel => _exposureLevel.value;

  // Timer for updating elapsed time
  Timer? _timer;
  
  // Current user (will be injected)
  User? _currentUser;
  
  // Cached daily and weekly exposure
  Duration _todayCompletedExposure = Duration.zero;
  Duration _weeklyCompletedExposure = Duration.zero;

  // Initialize the service
  Future<void> initialize() async {
    // Check for any active sessions on app start
    await _checkForActiveSessions();
    
    // Load daily and weekly exposure cache
    await _refreshExposureCache();
  }

  // Set current user
  void setCurrentUser(User user) {
    _currentUser = user;
  }

  // Start a new timer session
  Future<bool> startSession(Tool tool, {double? latitude, double? longitude}) async {
    print('🚀 Starting timer session...');
    print('👤 Current user: ${_currentUser?.email}');
    print('🆔 User ID: ${_currentUser?.id}');
    
    if (_currentUser == null) {
      print('❌ User not authenticated');
      _snackbarService.showSnackbar(message: 'User not authenticated.');
      return false;
    }

    if (_currentUser!.id == null || _currentUser!.id!.isEmpty) {
      print('❌ User ID is null or empty: ${_currentUser!.id}');
      _snackbarService.showSnackbar(message: 'User ID is missing. Please log in again.');
      return false;
    }

    if (currentSession != null) {
      _snackbarService.showSnackbar(message: 'A session is already active.');
      return false;
    }

    try {
      // Generate a temporary ID if the tool doesn't have one
      final toolId = tool.id ?? 'temp_${DateTime.now().millisecondsSinceEpoch}';
      
      final session = TimerSession(
        workerId: _currentUser!.id!,
        toolId: toolId,
        tool: tool,
        status: TimerStatus.active,
        startTime: DateTime.now(),
        latitude: latitude,
        longitude: longitude,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Save to Firestore
      final docRef = await _firestore
          .collection(FirebaseConfig.sessionsCollection)
          .add(session.toFirestore());

      // Update session with ID
      final sessionWithId = session.copyWith(id: docRef.id);
      _currentSession.value = sessionWithId;

      // Start timer
      _startTimer();
      _isRunning.value = true;

      _snackbarService.showSnackbar(
        message: 'Started tracking ${tool.displayName} usage.',
      );

      return true;
    } catch (e) {
      _snackbarService.showSnackbar(
        message: 'Failed to start session: $e',
      );
      return false;
    }
  }

  // Pause current session
  Future<bool> pauseSession() async {
    if (currentSession == null || !isRunning) {
      _snackbarService.showSnackbar(message: 'No active session to pause.');
      return false;
    }

    try {
      final pausedSession = currentSession!.pause();
      await _updateSession(pausedSession);
      
      _currentSession.value = pausedSession;
      _stopTimer();
      _isRunning.value = false;

      _snackbarService.showSnackbar(message: 'Session paused.');
      return true;
    } catch (e) {
      _snackbarService.showSnackbar(
        message: 'Failed to pause session: $e',
      );
      return false;
    }
  }

  // Resume paused session
  Future<bool> resumeSession() async {
    if (currentSession == null || currentSession!.status != TimerStatus.paused) {
      _snackbarService.showSnackbar(message: 'No paused session to resume.');
      return false;
    }

    try {
      final resumedSession = currentSession!.resume();
      await _updateSession(resumedSession);
      
      _currentSession.value = resumedSession;
      _startTimer();
      _isRunning.value = true;

      _snackbarService.showSnackbar(message: 'Session resumed.');
      return true;
    } catch (e) {
      _snackbarService.showSnackbar(
        message: 'Failed to resume session: $e',
      );
      return false;
    }
  }

  // Stop current session
  Future<bool> stopSession({String? reason}) async {
    if (currentSession == null) {
      _snackbarService.showSnackbar(message: 'No active session to stop.');
      return false;
    }

    try {
      final stoppedSession = currentSession!.stop(reason: reason);
      await _updateSession(stoppedSession);
      
      _currentSession.value = stoppedSession;
      _stopTimer();
      _isRunning.value = false;

      // Refresh exposure cache after stopping session
      await _refreshExposureCache();

      _snackbarService.showSnackbar(message: 'Session stopped.');
      return true;
    } catch (e) {
      _snackbarService.showSnackbar(
        message: 'Failed to stop session: $e',
      );
      return false;
    }
  }

  // Emergency stop session
  Future<bool> emergencyStop(String reason) async {
    if (currentSession == null) {
      _snackbarService.showSnackbar(message: 'No active session to stop.');
      return false;
    }

    try {
      final emergencyStoppedSession = currentSession!.emergencyStop(reason);
      await _updateSession(emergencyStoppedSession);
      
      _currentSession.value = emergencyStoppedSession;
      _stopTimer();
      _isRunning.value = false;

      _snackbarService.showSnackbar(
        message: 'EMERGENCY STOP: $reason',
        duration: const Duration(seconds: 5),
      );
      return true;
    } catch (e) {
      _snackbarService.showSnackbar(
        message: 'Failed to emergency stop: $e',
      );
      return false;
    }
  }

  // Start timer for updating elapsed time
  void _startTimer() {
    _timer?.cancel();
    _isRunning.value = true;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (currentSession != null && currentSession!.isActive) {
        _updateElapsedTime();
        _checkSafetyThresholds();
      }
    });
  }

  // Stop timer
  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
    _isRunning.value = false;
  }

  // Update elapsed time
  void _updateElapsedTime() {
    if (currentSession == null) return;

    final now = DateTime.now();
    final elapsed = now.difference(currentSession!.startTime) - 
                   Duration(seconds: currentSession!.totalPauseDuration);
    
    _elapsedTime.value = elapsed;

    // Update remaining time based on tool limits
    if (currentSession!.tool != null) {
      final limitMinutes = currentSession!.tool!.dailyExposureLimit;
      final remaining = Duration(minutes: limitMinutes) - elapsed;
      _remainingTime.value = remaining.isNegative ? Duration.zero : remaining;
    }
  }

  // Check safety thresholds and trigger alerts
  void _checkSafetyThresholds() async {
    if (currentSession?.tool == null) return;

    final tool = currentSession!.tool!;
    final elapsedMinutes = elapsedTime.inMinutes;
    
    // Get today's sessions for advanced calculations
    final todaySessions = await getTodaySessions();
    final exposureSessions = todaySessions
        .where((s) => s.isCompleted || s.isStopped)
        .map((s) => ExposureSession.fromTimerSession(s))
        .toList();
    
    // Add current session if active
    if (currentSession != null && currentSession!.isActive) {
      exposureSessions.add(ExposureSession(
        vibrationMagnitude: tool.vibrationLevel,
        durationMinutes: elapsedMinutes,
        date: DateTime.now(),
        toolId: tool.id,
      ));
    }

    // Calculate A(8) daily exposure value
    final dailyA8 = _exposureService.calculateA8DailyExposure(sessions: exposureSessions);
    
    // Calculate HSE points
    final hsePoints = _exposureService.calculateDailyHSEPoints(sessions: exposureSessions);
    
    // Calculate safe time remaining
    final safeTimeRemaining = _exposureService.calculateSafeTimeRemaining(
      vibrationLevel: tool.vibrationLevel,
      currentExposureMinutes: elapsedMinutes,
    );

    // Update exposure level based on A(8)
    if (dailyA8 >= 5.0) {
      _exposureLevel.value = ExposureLevel.critical;
    } else if (dailyA8 >= 2.5) {
      _exposureLevel.value = ExposureLevel.high;
    } else if (dailyA8 >= 2.0) {
      _exposureLevel.value = ExposureLevel.medium;
    } else {
      _exposureLevel.value = ExposureLevel.low;
    }

    // Advanced warning thresholds based on A(8) and HSE guidelines
    if (dailyA8 >= 5.0) {
      _triggerCriticalAlert('CRITICAL: Daily A(8) exposure limit exceeded (${dailyA8.toStringAsFixed(2)} m/s²)! Stop immediately.');
    } else if (dailyA8 >= 2.5) {
      _triggerWarning('WARNING: A(8) action value exceeded (${dailyA8.toStringAsFixed(2)} m/s²). HSE Points: ${hsePoints.toStringAsFixed(1)}');
    } else if (hsePoints >= 400) {
      _triggerWarning('High HSE points accumulated: ${hsePoints.toStringAsFixed(0)} points');
    } else if (safeTimeRemaining <= 30 && safeTimeRemaining > 0) {
      _triggerWarning('Safe time remaining: $safeTimeRemaining minutes');
    }

    // Rest period requirements with advanced calculations
    if (elapsedMinutes >= AppConfig.restPeriodMinutes && elapsedMinutes % AppConfig.restPeriodMinutes == 0) {
      final restPeriod = _exposureService.calculateRestPeriod(
        currentA8: dailyA8,
        exposureTimeMinutes: elapsedMinutes,
        vibrationLevel: tool.vibrationLevel,
      );
      
      _triggerAdvancedRestReminder(restPeriod);
    }
  }

  // Trigger warning
  void _triggerWarning(String message) async {
    if (currentSession != null) {
      final sessionWithWarning = currentSession!.addWarning(message);
      _currentSession.value = sessionWithWarning;
    }
    
    // Trigger vibration
    await _vibrationService.vibrateWarning();
    
    // Show notification
    await _notificationService.showSafetyWarning(
      title: 'Safety Warning',
      body: message,
      level: ExposureLevel.high,
    );
    
    _snackbarService.showSnackbar(
      message: '⚠️ $message',
      duration: const Duration(seconds: 3),
    );
  }

  // Trigger critical alert
  void _triggerCriticalAlert(String message) async {
    if (currentSession != null) {
      final sessionWithAlert = currentSession!.addAlert(message);
      _currentSession.value = sessionWithAlert;
    }
    
    // Trigger critical vibration
    await _vibrationService.vibrateCritical();
    
    // Show critical notification
    await _notificationService.showSafetyWarning(
      title: 'CRITICAL ALERT',
      body: message,
      level: ExposureLevel.critical,
    );
    
    _snackbarService.showSnackbar(
      message: '🚨 $message',
      duration: const Duration(seconds: 5),
    );
  }

  // Trigger rest reminder
  void _triggerRestReminder() async {
    final tool = currentSession?.tool;
    
    // Automatically pause the timer for rest break
    await pauseSession();
    
    // Trigger rest break vibration
    await _vibrationService.vibrateRestReminder();
    
    // Show rest break notification
    if (tool != null) {
      await _notificationService.showRestBreakReminder(
        toolName: tool.displayName,
        restMinutes: 15,
      );
    }
    
    _snackbarService.showSnackbar(
      message: '⏰ Time for a mandatory 15-minute rest break! Timer paused automatically.',
      duration: const Duration(seconds: 6),
    );
  }

  // Trigger advanced rest reminder with detailed calculations
  void _triggerAdvancedRestReminder(RestPeriodResult restPeriod) async {
    final tool = currentSession?.tool;
    
    // Automatically pause the timer for rest break
    await pauseSession();
    
    // Trigger appropriate vibration based on risk level
    await _vibrationService.vibrateForExposureLevel(restPeriod.riskLevel);
    
    // Show detailed notification
    if (tool != null) {
      await _notificationService.showSafetyWarning(
        title: 'Rest Break Required',
        body: '${restPeriod.recommendation}\n'
              'Required rest: ${restPeriod.requiredRestMinutes} minutes\n'
              '${restPeriod.safeTimeRemaining != null ? "Safe time remaining today: ${restPeriod.safeTimeRemaining} min" : ""}',
        level: restPeriod.riskLevel,
      );
    }
    
    _snackbarService.showSnackbar(
      message: '⏰ ${restPeriod.recommendation} (${restPeriod.requiredRestMinutes} min rest)',
      duration: const Duration(seconds: 8),
    );
  }

  // Update session in Firestore
  Future<void> _updateSession(TimerSession session) async {
    if (session.id == null) return;

    await _firestore
        .collection(FirebaseConfig.sessionsCollection)
        .doc(session.id)
        .update(session.toFirestore());
  }

  // Check for active sessions on app start
  Future<void> _checkForActiveSessions() async {
    if (_currentUser == null) return;

    try {
      final querySnapshot = await _firestore
          .collection(FirebaseConfig.sessionsCollection)
          .where('workerId', isEqualTo: _currentUser!.id)
          .where('status', whereIn: [TimerStatus.active.name, TimerStatus.paused.name])
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        final session = TimerSession.fromFirestore(doc.data(), doc.id);
        
        _currentSession.value = session;
        
        if (session.isActive) {
          _startTimer();
          _isRunning.value = true;
          _updateElapsedTime();
        }
      }
    } catch (e) {
      // Silently handle errors for session recovery
    }
  }

  // Refresh cached exposure values
  Future<void> _refreshExposureCache() async {
    if (_currentUser?.id == null) return;

    try {
      // Calculate today's completed sessions
      final todaySessions = await getTodaySessions();
      _todayCompletedExposure = Duration.zero;
      
      for (final session in todaySessions) {
        if (session.isCompleted || session.isStopped) {
          _todayCompletedExposure += session.totalDuration;
        }
      }

      // Calculate this week's completed sessions
      final weekSessions = await getWeekSessions();
      _weeklyCompletedExposure = Duration.zero;
      
      for (final session in weekSessions) {
        if (session.isCompleted || session.isStopped) {
          _weeklyCompletedExposure += session.totalDuration;
        }
      }
    } catch (e) {
      // Silently handle cache refresh errors
    }
  }

  // Get session statistics
  Map<String, dynamic> getSessionStats() {
    if (currentSession?.tool == null) return {};

    final tool = currentSession!.tool!;
    final elapsedMinutes = elapsedTime.inMinutes;
    final limitMinutes = tool.dailyExposureLimit;
    final percentage = (elapsedMinutes / limitMinutes * 100.0).clamp(0.0, 100.0);

    return {
      'elapsedTime': elapsedTime,
      'remainingTime': remainingTime,
      'percentage': percentage,
      'exposureLevel': exposureLevel,
      'isNearLimit': tool.isNearLimit(elapsedMinutes),
      'isAtLimit': tool.isAtLimit(elapsedMinutes),
      'isOverLimit': tool.isOverLimit(elapsedMinutes),
    };
  }

  // Additional getters for home view model
  TimerSession? get activeSession => currentSession;
  TimerStatus get status => currentSession?.status ?? TimerStatus.stopped;
  Duration get currentSessionDuration => elapsedTime;
  Tool? get currentTool => currentSession?.tool;

  // Get today's total exposure
  Duration get todayTotalExposure {
    // Calculate from current session + today's completed sessions
    Duration totalExposure = Duration.zero;
    
    // Add current session time if active
    if (currentSession != null && currentSession!.isActive) {
      totalExposure += elapsedTime;
    }
    
    // Add completed sessions from today (cached value)
    totalExposure += _todayCompletedExposure;
    
    return totalExposure;
  }

  // Get weekly total exposure
  Duration get weeklyTotalExposure {
    // Calculate from current session + this week's completed sessions
    Duration totalExposure = Duration.zero;
    
    // Add current session time if active
    if (currentSession != null && currentSession!.isActive) {
      totalExposure += elapsedTime;
    }
    
    // Add completed sessions from this week (cached value)
    totalExposure += _weeklyCompletedExposure;
    
    return totalExposure;
  }

  // Get today's exposure percentage
  double getTodayExposurePercentage() {
    if (currentTool == null) return 0.0;
    
    final dailyLimitMinutes = currentTool!.dailyExposureLimit;
    final todayMinutes = todayTotalExposure.inMinutes;
    
    return (todayMinutes / dailyLimitMinutes * 100.0).clamp(0.0, 100.0);
  }

  // Get user's sessions from Firestore
  Future<List<TimerSession>> getUserSessions({
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  }) async {
    if (_currentUser?.id == null) return [];

    try {
      Query query = _firestore
          .collection(FirebaseConfig.sessionsCollection)
          .where('workerId', isEqualTo: _currentUser!.id)
          .orderBy('startTime', descending: true);

      if (startDate != null) {
        query = query.where('startTime', isGreaterThanOrEqualTo: startDate);
      }
      
      if (endDate != null) {
        query = query.where('startTime', isLessThanOrEqualTo: endDate);
      }

      if (limit != null) {
        query = query.limit(limit);
      }

      final querySnapshot = await query.get();
      
      return querySnapshot.docs
          .map((doc) => TimerSession.fromFirestore(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
      
    } catch (e) {
      _snackbarService.showSnackbar(
        message: 'Error loading sessions: ${e.toString()}',
      );
      return [];
    }
  }

  // Get today's sessions
  Future<List<TimerSession>> getTodaySessions() async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return getUserSessions(startDate: startOfDay, endDate: endOfDay);
  }

  // Get this week's sessions
  Future<List<TimerSession>> getWeekSessions() async {
    final today = DateTime.now();
    final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
    final startOfWeekDay = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
    final endOfWeek = startOfWeekDay.add(const Duration(days: 7));

    return getUserSessions(startDate: startOfWeekDay, endDate: endOfWeek);
  }

  // Calculate real today's exposure from database
  Future<void> refreshTodayExposure() async {
    // Refresh the cached exposure values
    await _refreshExposureCache();
  }

  // Get current A(8) daily exposure value
  Future<double> getCurrentDailyA8() async {
    final todaySessions = await getTodaySessions();
    final exposureSessions = todaySessions
        .where((s) => s.isCompleted || s.isStopped)
        .map((s) => ExposureSession.fromTimerSession(s))
        .toList();
    
    // Add current session if active
    if (currentSession != null && currentSession!.isActive) {
      exposureSessions.add(ExposureSession(
        vibrationMagnitude: currentSession!.tool?.vibrationLevel ?? 0.0,
        durationMinutes: elapsedTime.inMinutes,
        date: DateTime.now(),
        toolId: currentSession!.toolId,
      ));
    }

    return _exposureService.calculateA8DailyExposure(sessions: exposureSessions);
  }

  // Get current HSE points
  Future<double> getCurrentHSEPoints() async {
    final todaySessions = await getTodaySessions();
    final exposureSessions = todaySessions
        .where((s) => s.isCompleted || s.isStopped)
        .map((s) => ExposureSession.fromTimerSession(s))
        .toList();
    
    // Add current session if active
    if (currentSession != null && currentSession!.isActive) {
      exposureSessions.add(ExposureSession(
        vibrationMagnitude: currentSession!.tool?.vibrationLevel ?? 0.0,
        durationMinutes: elapsedTime.inMinutes,
        date: DateTime.now(),
        toolId: currentSession!.toolId,
      ));
    }

    return _exposureService.calculateDailyHSEPoints(sessions: exposureSessions);
  }

  // Get safe time remaining for current tool
  Future<int> getSafeTimeRemaining() async {
    if (currentSession?.tool == null) return 0;
    
    return _exposureService.calculateSafeTimeRemaining(
      vibrationLevel: currentSession!.tool!.vibrationLevel,
      currentExposureMinutes: elapsedTime.inMinutes,
    );
  }

  // Get exposure forecast for planned usage
  Future<ExposureForecast> forecastExposure({
    required Tool tool,
    required int plannedMinutes,
  }) async {
    final todaySessions = await getTodaySessions();
    final exposureSessions = todaySessions
        .where((s) => s.isCompleted || s.isStopped)
        .map((s) => ExposureSession.fromTimerSession(s))
        .toList();

    return _exposureService.forecastExposure(
      tool: tool,
      plannedUsageMinutes: plannedMinutes,
      todaySessions: exposureSessions,
    );
  }

  // Get weekly exposure status
  Future<WeeklyExposureStatus> getWeeklyExposureStatus() async {
    final weekSessions = await getWeekSessions();
    final exposureSessions = weekSessions
        .where((s) => s.isCompleted || s.isStopped)
        .map((s) => ExposureSession.fromTimerSession(s))
        .toList();

    return _exposureService.calculateWeeklyExposureStatus(weekSessions: exposureSessions);
  }

  // Start background timer when app goes to background
  Future<void> enableBackgroundOperation() async {
    await _backgroundService.startBackgroundTimer();
  }

  // Stop background timer
  Future<void> disableBackgroundOperation() async {
    await _backgroundService.stopBackgroundTimer();
  }

  // Dispose service
  void dispose() {
    _stopTimer();
    _currentSession.value = null;
    _isRunning.value = false;
    _elapsedTime.value = Duration.zero;
    _remainingTime.value = Duration.zero;
    _exposureLevel.value = ExposureLevel.low;
    _backgroundService.dispose();
  }
}
