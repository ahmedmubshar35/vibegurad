import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';
import '../../../app/app.locator.dart';
import '../../../services/core/authentication_service.dart';
import '../../../services/features/session_service.dart';
import '../../../services/core/firebase_service.dart';
import '../../../models/timer/timer_session.dart';
import '../../../models/core/user.dart';
import '../../../config/firebase_config.dart';

class DashboardViewModel extends BaseViewModel {
  final _authService = locator<AuthenticationService>();
  final _sessionService = locator<SessionService>();
  final _firebaseService = locator<FirebaseService>();

  List<TimerSession> _allSessions = [];
  List<User> _companyWorkers = [];
  bool _hasData = false;

  List<TimerSession> get allSessions => _allSessions;
  List<User> get companyWorkers => _companyWorkers;
  bool get hasData => _hasData;

  // Overview metrics
  int get totalWorkers => _companyWorkers.length;
  int get activeWorkers => _allSessions.where((s) => s.isActive).length;
  int get totalExposureToday => _allSessions
      .where((s) => _isToday(s.startTime))
      .fold(0, (sum, s) => sum + s.totalMinutes);
  double get averageExposurePerWorker => totalWorkers > 0 ? totalExposureToday / totalWorkers : 0.0;

  // Safety metrics
  double get complianceRate {
    if (_companyWorkers.isEmpty) return 0.0;
    final compliantWorkers = _companyWorkers.where((worker) {
      final todayExposure = _getWorkerExposureToday(worker.id ?? '');
      return todayExposure <= 360; // 6 hours limit in minutes
    }).length;
    return (compliantWorkers / _companyWorkers.length * 100);
  }

  String get overallSafetyLevel {
    if (complianceRate >= 95) return 'Excellent';
    if (complianceRate >= 90) return 'Good';
    if (complianceRate >= 80) return 'Fair';
    return 'Needs Attention';
  }

  // Recent activity
  List<TimerSession> get recentActiveSessions => _allSessions
      .where((s) => s.isActive || s.isPaused)
      .take(10)
      .toList();

  List<TimerSession> get todayAlerts => _allSessions
      .where((s) => _isToday(s.startTime) && (s.hasWarnings || s.hasAlerts))
      .toList();

  void onModelReady() {
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setBusy(true);
    
    try {
      final currentUser = _authService.currentUser;
      if (currentUser?.hasCompany != true) {
        setBusy(false);
        return;
      }

      // Load company workers from Firestore
      final querySnapshot = await _firebaseService.getDocuments(
        FirebaseConfig.usersCollection,
        queryBuilder: (query) => query
            .where('companyId', isEqualTo: currentUser!.companyId)
            .where('role', isEqualTo: 'worker'),
      );
      
      _companyWorkers = querySnapshot.docs
          .map((doc) => User.fromFirestore(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
      
      // Load all sessions for company workers
      final allSessionsList = <TimerSession>[];
      for (final worker in _companyWorkers) {
        // Get recent sessions for each worker
        final recentSessionsStream = _sessionService.getRecentSessions(worker.id ?? '', limit: 50);
        final recentSessions = await recentSessionsStream.first;
        allSessionsList.addAll(recentSessions);
      }
      
      _allSessions = allSessionsList;
      _hasData = true;
      
    } catch (e) {
      print('Error loading dashboard data: $e');
      _hasData = false;
    } finally {
      setBusy(false);
      notifyListeners();
    }
  }

  Future<void> refreshData() async {
    await _loadDashboardData();
  }

  int _getWorkerExposureToday(String workerId) {
    return _allSessions
        .where((s) => s.workerId == workerId && _isToday(s.startTime))
        .fold(0, (sum, s) => sum + s.totalMinutes);
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && 
           date.month == now.month && 
           date.day == now.day;
  }

  List<User> getWorkersNeedingAttention() {
    return _companyWorkers.where((worker) {
      final todayExposure = _getWorkerExposureToday(worker.id ?? '');
      return todayExposure > 300; // 5+ hours needs attention
    }).toList();
  }

  List<TimerSession> getHighRiskSessions() {
    return _allSessions.where((s) => 
      s.totalMinutes > 360 || s.hasAlerts
    ).toList();
  }

  String getWorkerStatusText(String workerId) {
    final exposure = _getWorkerExposureToday(workerId);
    if (exposure == 0) return 'No activity';
    if (exposure <= 240) return 'Safe';
    if (exposure <= 300) return 'Caution';
    if (exposure <= 360) return 'Warning';
    return 'Over Limit';
  }

  Color getWorkerStatusColor(String workerId) {
    final exposure = _getWorkerExposureToday(workerId);
    if (exposure == 0) return Colors.grey;
    if (exposure <= 240) return Colors.green;
    if (exposure <= 300) return Colors.orange;
    if (exposure <= 360) return Colors.red;
    return Colors.red.shade800;
  }
}
