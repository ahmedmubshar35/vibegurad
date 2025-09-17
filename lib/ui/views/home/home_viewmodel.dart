import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';
import 'package:get_it/get_it.dart';

import '../../../services/core/authentication_service.dart';
import '../../../services/features/camera_service.dart';
import '../../../services/features/timer_service.dart';
import '../../../services/features/session_service.dart';
import '../../../services/core/accessibility_service.dart';
import '../../../services/core/connectivity_service.dart';
import '../../../models/core/user.dart';
import '../../../models/tool/tool.dart';
import '../../../models/timer/timer_session.dart';
import '../../../app/app.router.dart';
import '../../../enums/timer_status.dart';
import '../../../enums/tool_type.dart';
import '../help/help_view.dart';
import '../feedback/feedback_view.dart';
import '../accessibility/accessibility_view.dart';
import '../offline/offline_mode_view.dart';
import '../performance/performance_view.dart';
import '../tool_management/tool_list/tool_list_view.dart';

class HomeViewModel extends ReactiveViewModel {
  final AuthenticationService _authService = GetIt.instance<AuthenticationService>();
  final CameraService _cameraService = GetIt.instance<CameraService>();
  final TimerService _timerService = GetIt.instance<TimerService>();
  final SessionService _sessionService = GetIt.instance<SessionService>();
  final NavigationService _navigationService = GetIt.instance<NavigationService>();
  final SnackbarService _snackbarService = GetIt.instance<SnackbarService>();
  final AccessibilityService _accessibilityService = GetIt.instance<AccessibilityService>();
  final ConnectivityService _connectivityService = GetIt.instance<ConnectivityService>();

  bool _isInitialized = false;
  List<TimerSession> _recentSessions = [];

  @override
  List<ListenableServiceMixin> get listenableServices => [
    _authService,
    _timerService,
    _accessibilityService,
    _connectivityService,
  ];

  // Initialize the view model when it's ready
  void initialize() {
    initializeIfNeeded();
  }

  // Getters for reactive properties
  User? get currentUser => _authService.currentUser;
  TimerSession? get activeSession => _timerService.activeSession;
  TimerStatus get timerStatus => _timerService.status;
  Duration get currentExposure => _timerService.currentSessionDuration;
  Tool? get currentTool => _timerService.currentTool;
  
  bool get hasActiveSession => activeSession != null;
  bool get isTimerRunning => timerStatus.isRunning;
  List<TimerSession> get recentSessions => _recentSessions;

  // Quick stats
  int get todayExposureMinutes => _timerService.todayTotalExposure.inMinutes;
  int get weeklyExposureMinutes => _timerService.weeklyTotalExposure.inMinutes;
  double get todayExposurePercentage => _timerService.getTodayExposurePercentage();
  
  // Status indicators
  bool get isOfflineMode => !_connectivityService.isConnected;
  bool get hasAccessibilityEnabled => _accessibilityService.textScaleFactor != 1.0 || 
                                     _accessibilityService.highContrastMode || 
                                     _accessibilityService.reduceAnimations;

  String get welcomeMessage {
    final user = currentUser;
    if (user == null) return 'Welcome to VibeGuard';
    
    final firstName = user.firstName;
    final hour = DateTime.now().hour;
    String greeting;
    
    if (hour < 12) {
      greeting = 'Good morning';
    } else if (hour < 17) {
      greeting = 'Good afternoon';
    } else {
      greeting = 'Good evening';
    }
    
    return '$greeting, $firstName!';
  }

  String get safetyStatusMessage {
    final percentage = todayExposurePercentage;
    
    if (percentage < 25) {
      return 'Great job! You\'re well within safe limits.';
    } else if (percentage < 50) {
      return 'Good progress. Monitor your exposure.';
    } else if (percentage < 75) {
      return 'Caution: Approaching daily limit.';
    } else if (percentage < 100) {
      return 'Warning: Near daily exposure limit!';
    } else {
      return 'ALERT: Daily limit exceeded! Take a break.';
    }
  }

  // Navigate to camera screen for tool recognition
  Future<void> startToolRecognition() async {
    setBusy(true);
    
    try {
      // Check camera permissions
      final hasPermission = await _cameraService.requestCameraPermission();
      
      if (!hasPermission) {
        _snackbarService.showSnackbar(
          message: 'Camera permission is required for tool recognition',
        );
        return;
      }
      
      // Navigate to camera view
      await _navigationService.navigateTo(Routes.cameraView);
      
    } catch (e) {
      _snackbarService.showSnackbar(
        message: 'Error starting camera: ${e.toString()}',
      );
    } finally {
      setBusy(false);
    }
  }

  // Quick start with manual tool selection
  Future<void> quickStartManualTool() async {
    try {
      print('🔧 Manual Start button pressed');
      
      // Show dialog to select tool type
      final selectedTool = await _showToolSelectionDialog();
      
      if (selectedTool != null) {
        print('✅ Tool selected: ${selectedTool.displayName}');
        // Create tool instance and start timer
        await _startTimerWithTool(selectedTool);
      } else {
        print('❌ No tool selected - user cancelled');
      }
    } catch (e) {
      print('❌ Error in quickStartManualTool: $e');
      _snackbarService.showSnackbar(
        message: 'Error starting session: ${e.toString()}',
      );
    }
  }

  Future<Tool?> _showToolSelectionDialog() async {
    final dialogService = GetIt.instance<DialogService>();
    
    // Show a more comprehensive tool selection dialog
    final response = await dialogService.showConfirmationDialog(
      title: 'Manual Tool Selection',
      description: 'Select a tool type to start manual tracking:\n\n• Drill - Standard drilling operations\n• Grinder - Surface grinding and cutting\n• Hammer - Demolition and chiseling\n• Saw - Cutting operations\n• Sander - Surface finishing',
      confirmationTitle: 'Select Drill (Default)',
      cancelTitle: 'Cancel',
    );
    
    if (response?.confirmed == true) {
      // For now, default to drill, but this could be expanded to show a list
      const toolType = ToolType.drill;
      
      // Create a tool instance with proper defaults
      return Tool(
        name: toolType.displayName,
        brand: 'Manual Selection',
        model: 'Standard ${toolType.displayName}',
        type: toolType,
        category: toolType.displayName,
        companyId: currentUser?.companyId ?? 'default',
        vibrationLevel: toolType.defaultVibrationLevel,
        frequency: toolType.defaultFrequency,
        dailyExposureLimit: toolType.defaultDailyLimit,
        weeklyExposureLimit: toolType.defaultDailyLimit * 5,
        isToolActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }
    
    return null;
  }

  Future<void> _startTimerWithTool(Tool tool) async {
    setBusy(true);
    
    try {
      print('🚀 Starting timer session with tool: ${tool.displayName}');
      print('🔧 Tool details: ${tool.brand} ${tool.model}, Vibration: ${tool.vibrationLevel} m/s²');
      
      // Start timer session with the selected tool
      final success = await _timerService.startSession(tool);
      
      if (success) {
        print('✅ Timer session started successfully');
        _snackbarService.showSnackbar(
          message: 'Started tracking ${tool.name} usage',
          duration: const Duration(seconds: 2),
        );
        
        // Navigate to timer view
        print('🧭 Navigating to timer view');
        await _navigationService.navigateTo(Routes.timerView);
      } else {
        print('❌ Failed to start timer session');
        _snackbarService.showSnackbar(
          message: 'Failed to start timer session',
        );
      }
    } catch (e) {
      print('❌ Error in _startTimerWithTool: $e');
      _snackbarService.showSnackbar(
        message: 'Error starting session: ${e.toString()}',
      );
    } finally {
      setBusy(false);
    }
  }

  // Stop current timer session
  Future<void> stopCurrentSession() async {
    if (!hasActiveSession) return;
    
    setBusy(true);
    
    try {
      await _timerService.stopSession();
      _snackbarService.showSnackbar(
        message: 'Session stopped and saved',
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      _snackbarService.showSnackbar(
        message: 'Error stopping session: ${e.toString()}',
      );
    } finally {
      setBusy(false);
    }
  }

  // Pause/resume current session
  Future<void> toggleSessionPause() async {
    if (!hasActiveSession) return;
    
    setBusy(true);
    
    try {
      if (isTimerRunning) {
        await _timerService.pauseSession();
        _snackbarService.showSnackbar(
          message: 'Session paused',
        );
      } else {
        await _timerService.resumeSession();
        _snackbarService.showSnackbar(
          message: 'Session resumed',
        );
      }
    } catch (e) {
      _snackbarService.showSnackbar(
        message: 'Error toggling session: ${e.toString()}',
      );
    } finally {
      setBusy(false);
    }
  }

  // Navigation methods
  void navigateToTimer() {
    _navigationService.navigateTo(Routes.timerView);
  }

  void navigateToHistory() {
    _navigationService.navigateTo(Routes.historyView);
  }

  void navigateToProfile() {
    _navigationService.navigateTo(Routes.profileView);
  }

  void navigateToDashboard() {
    // Only for managers/admins
    if (currentUser?.role.name == 'worker') {
      _snackbarService.showSnackbar(
        message: 'Dashboard access is for managers and admins only',
      );
      return;
    }
    _navigationService.navigateTo(Routes.dashboardView);
  }

  // Navigation methods for Tools & Support section
  void navigateToHelp(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const HelpView(),
      ),
    );
  }

  void navigateToFeedback(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const FeedbackView(),
      ),
    );
  }

  void navigateToAccessibility(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AccessibilityView(),
      ),
    );
  }

  void navigateToOfflineMode(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const OfflineModeView(),
      ),
    );
  }

  void navigateToPerformance(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PerformanceView(),
      ),
    );
  }

  void navigateToBatteryData() {
    // Navigate to a combined view or show dialog with options
    _navigationService.navigateTo(Routes.settingsView);
  }

  void navigateToToolManagement(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ToolListView(),
      ),
    );
  }

  void navigateToMaintenance(BuildContext context) {
    // Navigate to tool management with maintenance filter
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ToolListView(),
      ),
    );
  }

  void navigateToReports(BuildContext context) {
    _navigationService.navigateTo(Routes.dashboardView);
  }

  void navigateToMore() {
    _navigationService.navigateTo(Routes.settingsView);
  }

  // Initialize home data (seed tools if needed)
  Future<void> initializeIfNeeded() async {
    if (_isInitialized) return;
    
    final user = currentUser;
    if (user != null) {
      try {
        // Initialize TimerService with current user
        _timerService.setCurrentUser(user);
        print('✅ TimerService initialized with user: ${user.email}');
        
        // TODO: Initialize company data if needed
        
        // Load recent sessions
        await _loadRecentSessions();
      } catch (e) {
        print('Error initializing data: $e');
      }
    }
    
    _isInitialized = true;
  }

  // Load recent sessions from database
  Future<void> _loadRecentSessions() async {
    final user = currentUser;
    if (user?.id == null) return;

    try {
      _sessionService.getRecentSessions(user!.id!, limit: 3).listen((sessions) {
        _recentSessions = sessions;
        notifyListeners();
      });
    } catch (e) {
      print('Error loading recent sessions: $e');
      _recentSessions = [];
    }
  }

  // Sign out
  Future<void> signOut() async {
    setBusy(true);
    
    try {
      // Stop any active session first
      if (hasActiveSession) {
        await _timerService.stopSession();
      }
      
      await _authService.signOut();
      
      // Navigate to login
      await _navigationService.clearStackAndShow(Routes.loginView);
      
    } catch (e) {
      _snackbarService.showSnackbar(
        message: 'Error signing out: ${e.toString()}',
      );
    } finally {
      setBusy(false);
    }
  }

  // Format duration for display
  String formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  // Get exposure level color
  Color getExposureColor() {
    final percentage = todayExposurePercentage;
    
    if (percentage < 25) {
      return const Color(0xFF4CAF50); // Green
    } else if (percentage < 50) {
      return const Color(0xFF2196F3); // Blue
    } else if (percentage < 75) {
      return const Color(0xFFFF9800); // Orange
    } else {
      return const Color(0xFFF44336); // Red
    }
  }
}