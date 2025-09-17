import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';
import '../../../app/app.locator.dart';
import '../../../services/core/authentication_service.dart';
import '../../../services/features/session_service.dart';
import '../../../models/core/user.dart';
import '../../../models/timer/timer_session.dart';

class ProfileViewModel extends BaseViewModel {
  final _authService = locator<AuthenticationService>();
  final _sessionService = locator<SessionService>();
  final _snackbarService = locator<SnackbarService>();

  // Form controllers
  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final phoneController = TextEditingController();
  final companyNameController = TextEditingController();

  bool _isEditing = false;
  List<TimerSession> _recentSessions = [];
  Map<String, dynamic> _healthMetrics = {};

  bool get isEditing => _isEditing;
  List<TimerSession> get recentSessions => _recentSessions;
  Map<String, dynamic> get healthMetrics => _healthMetrics;
  User? get currentUser => _authService.currentUser;

  // Health metrics getters
  int get totalSessions => _recentSessions.length;
  int get totalExposureToday => _getTodayExposure();
  int get totalExposureWeek => _getWeekExposure();
  double get averageSessionLength => totalSessions > 0 ? _getAverageSessionLength() : 0.0;
  int get safetyScore => _calculateSafetyScore();
  String get riskLevel => _calculateRiskLevel();

  @override
  void onModelReady() {
    _initializeProfile();
    _loadHealthMetrics();
  }

  void _initializeProfile() {
    final user = currentUser;
    if (user != null) {
      firstNameController.text = user.firstName;
      lastNameController.text = user.lastName;
      phoneController.text = user.phoneNumber ?? '';
      companyNameController.text = user.companyName ?? '';
    }
  }

  Future<void> _loadHealthMetrics() async {
    setBusy(true);
    
    try {
      if (currentUser?.id != null) {
        // Load recent sessions for health metrics
        final sessionsStream = _sessionService.getRecentSessions(currentUser!.id!, limit: 50);
        _recentSessions = await sessionsStream.first;
        
        // Calculate health metrics
        _healthMetrics = {
          'dailyExposure': totalExposureToday,
          'weeklyExposure': totalExposureWeek,
          'averageSession': averageSessionLength,
          'safetyScore': safetyScore,
          'riskLevel': riskLevel,
          'totalSessions': totalSessions,
          'warningsCount': _recentSessions.where((s) => s.hasWarnings).length,
          'alertsCount': _recentSessions.where((s) => s.hasAlerts).length,
        };
      }
    } catch (e) {
      print('Error loading health metrics: $e');
    } finally {
      setBusy(false);
    }
  }

  void toggleEditing() {
    _isEditing = !_isEditing;
    if (!_isEditing) {
      // Reset controllers to original values if canceling
      _initializeProfile();
    }
    notifyListeners();
  }

  Future<void> saveProfile() async {
    setBusy(true);
    
    try {
      // Validate input
      if (firstNameController.text.trim().isEmpty) {
        _snackbarService.showSnackbar(message: 'First name is required');
        setBusy(false);
        return;
      }

      if (lastNameController.text.trim().isEmpty) {
        _snackbarService.showSnackbar(message: 'Last name is required');
        setBusy(false);
        return;
      }

      // In a real app, you would update the user profile in Firebase
      // For now, we'll simulate the update
      await Future.delayed(Duration(seconds: 1));
      
      _isEditing = false;
      _snackbarService.showSnackbar(message: 'Profile updated successfully');
    } catch (e) {
      _snackbarService.showSnackbar(message: 'Error updating profile: $e');
    } finally {
      setBusy(false);
      notifyListeners();
    }
  }

  Future<void> refreshProfile() async {
    await _loadHealthMetrics();
  }

  int _getTodayExposure() {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(Duration(days: 1));
    
    return _recentSessions
        .where((s) => s.startTime.isAfter(startOfDay) && s.startTime.isBefore(endOfDay))
        .fold(0, (sum, s) => sum + s.totalMinutes);
  }

  int _getWeekExposure() {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    
    return _recentSessions
        .where((s) => s.startTime.isAfter(startOfWeek))
        .fold(0, (sum, s) => sum + s.totalMinutes);
  }

  double _getAverageSessionLength() {
    if (_recentSessions.isEmpty) return 0.0;
    final totalMinutes = _recentSessions.fold(0, (sum, s) => sum + s.totalMinutes);
    return totalMinutes / _recentSessions.length;
  }

  int _calculateSafetyScore() {
    if (_recentSessions.isEmpty) return 100;
    
    final totalSessions = _recentSessions.length;
    final sessionsWithIssues = _recentSessions.where((s) => s.hasWarnings || s.hasAlerts).length;
    final overLimitSessions = _recentSessions.where((s) => s.totalMinutes > 360).length;
    
    // Calculate score based on issues
    double score = 100.0;
    score -= (sessionsWithIssues / totalSessions) * 30; // -30 for issues
    score -= (overLimitSessions / totalSessions) * 20; // -20 for over limit
    
    return score.clamp(0, 100).round();
  }

  String _calculateRiskLevel() {
    final score = safetyScore;
    final todayExposure = totalExposureToday;
    
    if (todayExposure > 360 || score < 60) return 'High Risk';
    if (todayExposure > 280 || score < 80) return 'Medium Risk';
    return 'Low Risk';
  }

  Color getRiskLevelColor() {
    switch (riskLevel) {
      case 'High Risk':
        return Colors.red;
      case 'Medium Risk':
        return Colors.orange;
      case 'Low Risk':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String getHealthRecommendation() {
    final todayExposure = totalExposureToday;
    final safetyScore = this.safetyScore;
    
    if (todayExposure > 360) {
      return 'You have exceeded the daily exposure limit. Take a break and avoid vibrating tools for the rest of the day.';
    } else if (todayExposure > 280) {
      return 'You are approaching the daily exposure limit. Consider taking longer breaks between tool use.';
    } else if (safetyScore < 70) {
      return 'Your safety score needs improvement. Review your tool usage patterns and follow break recommendations.';
    } else {
      return 'Great job maintaining safe exposure levels! Keep following safety guidelines.';
    }
  }

  List<String> getRecentAchievements() {
    List<String> achievements = [];
    
    if (totalSessions >= 10) achievements.add('10 Sessions Completed');
    if (safetyScore >= 90) achievements.add('Safety Champion');
    if (_recentSessions.where((s) => s.totalMinutes <= 60).length >= 5) {
      achievements.add('Short Session Specialist');
    }
    if (_getDaysWithoutAlerts() >= 7) achievements.add('7 Days Alert-Free');
    
    if (achievements.isEmpty) {
      achievements.add('Getting Started');
    }
    
    return achievements;
  }

  int _getDaysWithoutAlerts() {
    if (_recentSessions.isEmpty) return 0;
    
    final now = DateTime.now();
    int days = 0;
    
    for (int i = 0; i < 30; i++) {
      final checkDate = now.subtract(Duration(days: i));
      final dayStart = DateTime(checkDate.year, checkDate.month, checkDate.day);
      final dayEnd = dayStart.add(Duration(days: 1));
      
      final daySessions = _recentSessions.where((s) => 
        s.startTime.isAfter(dayStart) && s.startTime.isBefore(dayEnd)
      );
      
      if (daySessions.isEmpty) continue;
      
      if (daySessions.any((s) => s.hasAlerts)) {
        break;
      }
      
      days++;
    }
    
    return days;
  }

  @override
  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
    phoneController.dispose();
    companyNameController.dispose();
    super.dispose();
  }
}
