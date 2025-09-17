import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';
import '../../../app/app.locator.dart';
import '../../../services/core/authentication_service.dart';
import '../../../services/features/session_service.dart';
import '../../../models/timer/timer_session.dart';
import '../../../models/core/user.dart';

class HistoryViewModel extends BaseViewModel {
  final _authService = locator<AuthenticationService>();
  final _sessionService = locator<SessionService>();

  List<TimerSession> _allSessions = [];
  List<TimerSession> _filteredSessions = [];
  DateTime? _selectedStartDate;
  DateTime? _selectedEndDate;
  String _selectedFilter = 'All';

  List<TimerSession> get filteredSessions => _filteredSessions;
  DateTime? get selectedStartDate => _selectedStartDate;
  DateTime? get selectedEndDate => _selectedEndDate;
  String get selectedFilter => _selectedFilter;
  
  User? get currentUser => _authService.currentUser;

  // Statistics
  int get totalSessions => _filteredSessions.length;
  int get totalExposureMinutes => _filteredSessions.fold(0, (sum, s) => sum + s.totalMinutes);
  double get averageSessionLength => totalSessions > 0 ? totalExposureMinutes / totalSessions : 0.0;
  int get sessionsWithWarnings => _filteredSessions.where((s) => s.hasWarnings).length;
  int get sessionsWithAlerts => _filteredSessions.where((s) => s.hasAlerts).length;

  void onModelReady() {
    _loadSessionHistory();
  }

  Future<void> _loadSessionHistory() async {
    setBusy(true);
    
    try {
      if (currentUser?.id != null) {
        final sessionsStream = _sessionService.getRecentSessions(currentUser!.id!, limit: 100);
        final sessions = await sessionsStream.first;
        _allSessions = sessions..sort((a, b) => b.startTime.compareTo(a.startTime));
        _applyFilters();
      }
    } catch (e) {
      print('Error loading session history: $e');
    } finally {
      setBusy(false);
    }
  }

  Future<void> refreshHistory() async {
    await _loadSessionHistory();
  }

  void setDateFilter(DateTime? startDate, DateTime? endDate) {
    _selectedStartDate = startDate;
    _selectedEndDate = endDate;
    _applyFilters();
    notifyListeners();
  }

  void setFilter(String filter) {
    _selectedFilter = filter;
    _applyFilters();
    notifyListeners();
  }

  void _applyFilters() {
    _filteredSessions = List.from(_allSessions);

    // Apply date filter
    if (_selectedStartDate != null && _selectedEndDate != null) {
      _filteredSessions = _filteredSessions.where((session) {
        return session.startTime.isAfter(_selectedStartDate!) && 
               session.startTime.isBefore(_selectedEndDate!.add(Duration(days: 1)));
      }).toList();
    }

    // Apply type filter
    switch (_selectedFilter) {
      case 'Today':
        final today = DateTime.now();
        final startOfDay = DateTime(today.year, today.month, today.day);
        final endOfDay = startOfDay.add(Duration(days: 1));
        _filteredSessions = _filteredSessions.where((s) => 
          s.startTime.isAfter(startOfDay) && s.startTime.isBefore(endOfDay)
        ).toList();
        break;
      case 'This Week':
        final now = DateTime.now();
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        _filteredSessions = _filteredSessions.where((s) => 
          s.startTime.isAfter(startOfWeek)
        ).toList();
        break;
      case 'With Warnings':
        _filteredSessions = _filteredSessions.where((s) => s.hasWarnings).toList();
        break;
      case 'With Alerts':
        _filteredSessions = _filteredSessions.where((s) => s.hasAlerts).toList();
        break;
      case 'Completed':
        _filteredSessions = _filteredSessions.where((s) => s.isCompleted).toList();
        break;
    }
  }

  List<String> get availableFilters => [
    'All', 'Today', 'This Week', 'With Warnings', 'With Alerts', 'Completed'
  ];

  String getSessionStatusText(TimerSession session) {
    if (session.isEmergencyStopped) return 'Emergency Stop';
    if (session.hasAlerts) return 'Has Alerts';
    if (session.hasWarnings) return 'Has Warnings';
    if (session.isCompleted) return 'Completed';
    if (session.isActive) return 'Active';
    if (session.isPaused) return 'Paused';
    return 'Stopped';
  }

  Color getSessionStatusColor(TimerSession session) {
    if (session.isEmergencyStopped) return Colors.red.shade800;
    if (session.hasAlerts) return Colors.red;
    if (session.hasWarnings) return Colors.orange;
    if (session.isCompleted) return Colors.green;
    if (session.isActive) return Colors.blue;
    if (session.isPaused) return Colors.yellow.shade700;
    return Colors.grey;
  }

  Future<void> deleteSession(TimerSession session) async {
    setBusy(true);
    await Future.delayed(Duration(seconds: 1));
    setBusy(false);
  }
}




