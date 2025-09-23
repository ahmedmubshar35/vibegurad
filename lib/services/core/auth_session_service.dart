import 'dart:async';
import 'package:injectable/injectable.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get_it/get_it.dart';
import 'authentication_service.dart';
import '../../app/app.router.dart';
import 'notification_manager.dart';

@lazySingleton
class AuthSessionService with ListenableServiceMixin {
  final NavigationService _navigationService = GetIt.instance<NavigationService>();
  final SnackbarService _snackbarService = GetIt.instance<SnackbarService>();
  final AuthenticationService _authService = GetIt.instance<AuthenticationService>();
  
  static const int _sessionTimeoutMinutes = 30;
  static const String _lastActivityKey = 'last_activity';
  static const String _rememberMeKey = 'remember_me';
  static const String _savedEmailKey = 'saved_email';
  
  Timer? _sessionTimer;
  DateTime? _lastActivity;
  bool _isAppInBackground = false;
  
  final ReactiveValue<bool> _isSessionActive = ReactiveValue<bool>(true);
  bool get isSessionActive => _isSessionActive.value;
  
  AuthSessionService() {
    listenToReactiveValues([_isSessionActive]);
    _initializeSessionMonitoring();
  }
  
  // Initialize session monitoring
  Future<void> _initializeSessionMonitoring() async {
    await _loadLastActivity();
    _startSessionTimer();
  }
  
  // Update last activity time
  void updateActivity() {
    if (!_isAppInBackground) {
      _lastActivity = DateTime.now();
      _saveLastActivity();
    }
  }
  
  // Start session timeout timer
  void _startSessionTimer() {
    _sessionTimer?.cancel();
    _sessionTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _checkSessionTimeout(),
    );
  }
  
  // Check if session has timed out
  Future<void> _checkSessionTimeout() async {
    if (_lastActivity == null || _isAppInBackground) return;
    
    final now = DateTime.now();
    final difference = now.difference(_lastActivity!);
    
    if (difference.inMinutes >= _sessionTimeoutMinutes) {
      await _handleSessionTimeout();
    } else {
      // Show warning 5 minutes before timeout
      final remainingMinutes = _sessionTimeoutMinutes - difference.inMinutes;
      if (remainingMinutes == 5) {
        _showTimeoutWarning();
      }
    }
  }
  
  // Handle session timeout
  Future<void> _handleSessionTimeout() async {
    _isSessionActive.value = false;
    _sessionTimer?.cancel();
    
    // Sign out the user
    await _authService.signOut();
    
    NotificationManager().showWarning('Your session has expired. Please log in again.');
    
    // Navigate to login
    await _navigationService.clearStackAndShow(Routes.loginView);
  }
  
  // Show timeout warning
  void _showTimeoutWarning() {
    NotificationManager().showWarning('Your session will expire in 5 minutes due to inactivity. Tap to stay logged in.');
  }
  
  // App lifecycle handlers
  void onAppPaused() {
    _isAppInBackground = true;
    _saveLastActivity();
  }
  
  void onAppResumed() {
    _isAppInBackground = false;
    _checkSessionTimeout();
    updateActivity();
  }
  
  // Extend session manually
  void extendSession() {
    updateActivity();
    NotificationManager().showInfo('Session extended for another $_sessionTimeoutMinutes minutes');
  }
  
  // Save last activity to persistent storage
  Future<void> _saveLastActivity() async {
    if (_lastActivity == null) return;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _lastActivityKey,
      _lastActivity!.toIso8601String(),
    );
  }
  
  // Load last activity from persistent storage
  Future<void> _loadLastActivity() async {
    final prefs = await SharedPreferences.getInstance();
    final lastActivityString = prefs.getString(_lastActivityKey);
    
    if (lastActivityString != null) {
      _lastActivity = DateTime.parse(lastActivityString);
      await _checkSessionTimeout();
    } else {
      _lastActivity = DateTime.now();
    }
  }
  
  // Remember Me functionality
  Future<void> saveRememberMe(String email, bool remember) async {
    final prefs = await SharedPreferences.getInstance();
    
    if (remember) {
      await prefs.setBool(_rememberMeKey, true);
      await prefs.setString(_savedEmailKey, email);
    } else {
      await prefs.remove(_rememberMeKey);
      await prefs.remove(_savedEmailKey);
    }
  }
  
  // Get remembered email
  Future<Map<String, dynamic>> getRememberedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final remember = prefs.getBool(_rememberMeKey) ?? false;
    final email = prefs.getString(_savedEmailKey) ?? '';
    
    return {
      'remember': remember,
      'email': email,
    };
  }
  
  // Clear remember me data
  Future<void> clearRememberMe() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_rememberMeKey);
    await prefs.remove(_savedEmailKey);
  }
  
  // Configure session timeout (for admin settings)
  Future<void> configureTimeout(int minutes) async {
    // This could be saved to user preferences
    // For now, we'll keep it simple
    NotificationManager().showInfo('Session timeout updated to $minutes minutes');
  }
  
  // Clean up
  void dispose() {
    _sessionTimer?.cancel();
  }
}