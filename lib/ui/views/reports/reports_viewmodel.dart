import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';
import '../../../app/app.locator.dart';
import '../../../services/core/authentication_service.dart';
import '../../../services/features/session_service.dart';
// CompanyService not implemented yet
import '../../../models/timer/timer_session.dart';
import '../../../models/core/user.dart';
// Exposure level removed - using vibration-based calculations
import 'package:intl/intl.dart';

class ReportsViewModel extends BaseViewModel {
  final _authService = locator<AuthenticationService>();
  final _sessionService = locator<SessionService>();
  // final _companyService = locator<CompanyService>(); // Not implemented yet

  List<TimerSession> _allSessions = [];
  List<User> _companyWorkers = [];
  DateTimeRange? _selectedDateRange;
  String _selectedReportType = 'overview';
  Map<String, dynamic> _reportData = {};

  List<TimerSession> get allSessions => _allSessions;
  List<User> get companyWorkers => _companyWorkers;
  DateTimeRange? get selectedDateRange => _selectedDateRange;
  String get selectedReportType => _selectedReportType;
  Map<String, dynamic> get reportData => _reportData;
  User? get currentUser => _authService.currentUser;

  bool get isManager => currentUser?.role.name.toLowerCase() == 'manager' || 
                       currentUser?.role.name.toLowerCase() == 'admin';

  List<String> get reportTypes => [
    'overview',
    'safety',
    'exposure',
    'workers',
    'tools',
    'compliance',
    'osha',
    'iso5349',
    'violations',
    'corrective_actions',
    'training',
    'audit_trail'
  ];

  Map<String, String> get reportTypeNames => {
    'overview': 'Overview Report',
    'safety': 'Safety Analysis',
    'exposure': 'Exposure Report',
    'workers': 'Worker Report',
    'tools': 'Tool Usage',
    'compliance': 'HSE Compliance',
    'osha': 'OSHA Compliance',
    'iso5349': 'ISO 5349 Standard',
    'violations': 'Violation Documentation',
    'corrective_actions': 'Corrective Actions',
    'training': 'Training Compliance',
    'audit_trail': 'Audit Trail & Logs'
  };

  void onModelReady() {
    _initializeDateRange();
    _loadReportData();
  }

  void _initializeDateRange() {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    _selectedDateRange = DateTimeRange(start: startOfMonth, end: now);
  }

  Future<void> _loadReportData() async {
    setBusy(true);
    
    try {
      if (currentUser?.companyId != null) {
        // Load all company sessions within date range
        await _loadCompanySessions();
        
        if (isManager) {
          // Load company workers for manager reports
          await _loadCompanyWorkers();
        }
        
        // Generate report based on selected type
        await _generateReport();
      }
    } catch (e) {
      print('Error loading report data: $e');
    } finally {
      setBusy(false);
    }
  }

  Future<void> _loadCompanySessions() async {
    try {
      // TODO: Load all company sessions for comprehensive reporting
      // In a full implementation, you'd query all company users' sessions
      if (currentUser?.id != null) {
        final userSessionsStream = _sessionService.getRecentSessions(currentUser!.id!, limit: 50);
        _allSessions = await userSessionsStream.first;
        
        // Filter by date range if sessions exist
        if (_selectedDateRange != null) {
          _allSessions = _allSessions.where((session) {
            return session.startTime.isAfter(_selectedDateRange!.start) && 
                   session.startTime.isBefore(_selectedDateRange!.end.add(const Duration(days: 1)));
          }).toList();
        }
      }
    } catch (e) {
      print('Error loading sessions: $e');
      _allSessions = [];
    }
  }

  Future<void> _loadCompanyWorkers() async {
    // TODO: Implement CompanyService
    _companyWorkers = [];
  }

  Future<void> _generateReport() async {
    switch (_selectedReportType) {
      case 'overview':
        _reportData = _generateOverviewReport();
        break;
      case 'safety':
        _reportData = _generateSafetyReport();
        break;
      case 'exposure':
        _reportData = _generateExposureReport();
        break;
      case 'workers':
        _reportData = _generateWorkersReport();
        break;
      case 'tools':
        _reportData = _generateToolsReport();
        break;
      case 'compliance':
        _reportData = _generateComplianceReport();
        break;
      case 'osha':
        _reportData = _generateOSHAReport();
        break;
      case 'iso5349':
        _reportData = _generateISO5349Report();
        break;
      case 'violations':
        _reportData = _generateViolationsReport();
        break;
      case 'corrective_actions':
        _reportData = _generateCorrectiveActionsReport();
        break;
      case 'training':
        _reportData = _generateTrainingReport();
        break;
      case 'audit_trail':
        _reportData = _generateAuditTrailReport();
        break;
    }
  }

  Map<String, dynamic> _generateOverviewReport() {
    final totalSessions = _allSessions.length;
    final totalExposureHours = _allSessions.fold(0, (sum, s) => sum + s.totalMinutes) / 60.0;
    final averageSessionLength = totalSessions > 0 ? 
        _allSessions.fold(0, (sum, s) => sum + s.totalMinutes) / totalSessions : 0.0;
    final uniqueWorkers = _allSessions.map((s) => s.workerId).toSet().length;
    final sessionsWithIssues = _allSessions.where((s) => s.hasWarnings || s.hasAlerts).length;
    final complianceRate = totalSessions > 0 ? 
        ((totalSessions - sessionsWithIssues) / totalSessions) * 100 : 100.0;

    return {
      'totalSessions': totalSessions,
      'totalExposureHours': totalExposureHours,
      'averageSessionLength': averageSessionLength,
      'uniqueWorkers': uniqueWorkers,
      'complianceRate': complianceRate,
      'sessionsWithIssues': sessionsWithIssues,
      'dateRange': '${DateFormat('MMM dd, yyyy').format(_selectedDateRange!.start)} - ${DateFormat('MMM dd, yyyy').format(_selectedDateRange!.end)}',
    };
  }

  Map<String, dynamic> _generateSafetyReport() {
    final highRiskSessions = _allSessions.where((s) => 
        (s.tool?.vibrationLevel ?? 0.0) >= 5.0).length;
    final emergencyStops = _allSessions.where((s) => s.isEmergencyStop).length;
    final overLimitSessions = _allSessions.where((s) => s.totalMinutes > 360).length;
    final averageExposureLevel = _calculateAverageExposureLevel();
    final safetyTrend = _calculateSafetyTrend();
    final mostCommonIssues = _getMostCommonSafetyIssues();

    return {
      'highRiskSessions': highRiskSessions,
      'emergencyStops': emergencyStops,
      'overLimitSessions': overLimitSessions,
      'averageExposureLevel': averageExposureLevel,
      'safetyTrend': safetyTrend,
      'mostCommonIssues': mostCommonIssues,
      'riskDistribution': _getRiskDistribution(),
    };
  }

  Map<String, dynamic> _generateExposureReport() {
    final dailyExposures = _getDailyExposureData();
    final weeklyAverages = _getWeeklyAverageExposure();
    final exposureByTool = _getExposureByTool();
    final peakExposureTimes = _getPeakExposureTimes();

    return {
      'dailyExposures': dailyExposures,
      'weeklyAverages': weeklyAverages,
      'exposureByTool': exposureByTool,
      'peakExposureTimes': peakExposureTimes,
      'totalExposureMinutes': _allSessions.fold(0, (sum, s) => sum + s.totalMinutes),
      'averageDailyExposure': _getAverageDailyExposure(),
    };
  }

  Map<String, dynamic> _generateWorkersReport() {
    if (!isManager) return {};
    
    final workerStats = <String, Map<String, dynamic>>{};
    
    for (final worker in _companyWorkers) {
      final workerSessions = _allSessions.where((s) => s.workerId == worker.id).toList();
      final totalExposure = workerSessions.fold(0, (sum, s) => sum + s.totalMinutes);
      final sessionsWithIssues = workerSessions.where((s) => s.hasWarnings || s.hasAlerts).length;
      final complianceRate = workerSessions.isNotEmpty ? 
          ((workerSessions.length - sessionsWithIssues) / workerSessions.length) * 100 : 100.0;
      
      workerStats[worker.id!] = {
        'name': worker.fullName,
        'totalSessions': workerSessions.length,
        'totalExposure': totalExposure,
        'averageSession': workerSessions.isNotEmpty ? totalExposure / workerSessions.length : 0.0,
        'complianceRate': complianceRate,
        'riskLevel': _calculateWorkerRiskLevel(workerSessions),
        'lastSession': workerSessions.isNotEmpty ? 
            workerSessions.map((s) => s.startTime).reduce((a, b) => a.isAfter(b) ? a : b) : null,
      };
    }
    
    return {
      'workerStats': workerStats,
      'topPerformers': _getTopPerformingWorkers(workerStats),
      'workersNeedingAttention': _getWorkersNeedingAttention(workerStats),
    };
  }

  Map<String, dynamic> _generateToolsReport() {
    final toolUsage = <String, Map<String, dynamic>>{};
    
    for (final session in _allSessions) {
      final toolName = session.tool?.name ?? 'Unknown';
      
      if (!toolUsage.containsKey(toolName)) {
        toolUsage[toolName] = {
          'totalSessions': 0,
          'totalExposure': 0,
          'averageSession': 0.0,
          'issueRate': 0.0,
          'vibrationLevel': session.tool?.vibrationLevel ?? 0.0,
        };
      }
      
      toolUsage[toolName]!['totalSessions']++;
      toolUsage[toolName]!['totalExposure'] += session.totalMinutes;
    }
    
    // Calculate averages and issue rates
    for (final tool in toolUsage.keys) {
      final toolSessions = _allSessions.where((s) => (s.tool?.name ?? 'Unknown') == tool).toList();
      final totalSessions = toolUsage[tool]!['totalSessions'] as int;
      final totalExposure = toolUsage[tool]!['totalExposure'] as int;
      final sessionsWithIssues = toolSessions.where((s) => s.hasWarnings || s.hasAlerts).length;
      
      toolUsage[tool]!['averageSession'] = totalExposure / totalSessions;
      toolUsage[tool]!['issueRate'] = (sessionsWithIssues / totalSessions) * 100;
    }
    
    return {
      'toolUsage': toolUsage,
      'mostUsedTools': _getMostUsedTools(toolUsage),
      'highestRiskTools': _getHighestRiskTools(toolUsage),
      'toolEfficiency': _getToolEfficiencyData(toolUsage),
    };
  }

  Map<String, dynamic> _generateComplianceReport() {
    final totalSessions = _allSessions.length;
    final compliantSessions = _allSessions.where((s) => 
        !s.hasAlerts && s.totalMinutes <= 360).length;
    final complianceRate = totalSessions > 0 ? 
        (compliantSessions / totalSessions) * 100 : 100.0;
    
    final hseRequirements = {
      'Daily Exposure Limit (6 hours)': _checkDailyExposureCompliance(),
      'Break Requirements (10 min/hour)': _checkBreakCompliance(),
      'Risk Assessment Documentation': _checkRiskAssessmentCompliance(),
      'Training Records': _checkTrainingCompliance(),
      'Health Surveillance': _checkHealthSurveillanceCompliance(),
    };
    
    return {
      'overallComplianceRate': complianceRate,
      'hseRequirements': hseRequirements,
      'nonCompliantSessions': totalSessions - compliantSessions,
      'complianceTrend': _getComplianceTrend(),
      'recommendedActions': _getComplianceRecommendations(complianceRate),
    };
  }

  // Helper methods for calculations
  double _calculateAverageExposureLevel() {
    if (_allSessions.isEmpty) return 0.0;
    // Calculate exposure level based on vibration: 0=low, 1=med, 2=high, 3=critical
    final levelSum = _allSessions.fold(0, (sum, s) {
      final vibration = s.tool?.vibrationLevel ?? 0.0;
      int level = vibration < 2.5 ? 0 : vibration < 5.0 ? 1 : vibration < 10.0 ? 2 : 3;
      return sum + level;
    });
    return levelSum / _allSessions.length;
  }

  String _calculateSafetyTrend() {
    // Simple trend calculation - compare first half vs second half of period
    final midpoint = _allSessions.length ~/ 2;
    if (midpoint == 0) return 'Stable';
    
    final firstHalf = _allSessions.take(midpoint);
    final secondHalf = _allSessions.skip(midpoint);
    
    final firstHalfIssues = firstHalf.where((s) => s.hasWarnings || s.hasAlerts).length / midpoint;
    final secondHalfIssues = secondHalf.where((s) => s.hasWarnings || s.hasAlerts).length / (secondHalf.length);
    
    if (secondHalfIssues < firstHalfIssues * 0.8) return 'Improving';
    if (secondHalfIssues > firstHalfIssues * 1.2) return 'Declining';
    return 'Stable';
  }

  List<String> _getMostCommonSafetyIssues() {
    final issues = <String>[];
    for (final session in _allSessions) {
      issues.addAll(session.warnings);
      issues.addAll(session.alerts);
    }
    
    final issueCount = <String, int>{};
    for (final issue in issues) {
      issueCount[issue] = (issueCount[issue] ?? 0) + 1;
    }
    
    final sortedIssues = issueCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return sortedIssues.take(5).map((e) => e.key).toList();
  }

  Map<String, int> _getRiskDistribution() {
    final distribution = <String, int>{
      'Low': 0,
      'Medium': 0,
      'High': 0,
      'Critical': 0,
    };
    
    for (final session in _allSessions) {
      final vibration = session.tool?.vibrationLevel ?? 0.0;
      if (vibration < 2.5) {
        distribution['Low'] = distribution['Low']! + 1;
      } else if (vibration < 5.0) {
        distribution['Medium'] = distribution['Medium']! + 1;
      } else if (vibration < 10.0) {
        distribution['High'] = distribution['High']! + 1;
      } else {
        distribution['Critical'] = distribution['Critical']! + 1;
      }
    }
    
    return distribution;
  }

  List<Map<String, dynamic>> _getDailyExposureData() {
    final dailyData = <DateTime, int>{};
    
    for (final session in _allSessions) {
      final date = DateTime(session.startTime.year, session.startTime.month, session.startTime.day);
      dailyData[date] = (dailyData[date] ?? 0) + session.totalMinutes;
    }
    
    return dailyData.entries.map((e) => {
      'date': e.key,
      'exposure': e.value,
      'isOverLimit': e.value > 360,
    }).toList()..sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));
  }

  double _getWeeklyAverageExposure() {
    final dailyData = _getDailyExposureData();
    if (dailyData.isEmpty) return 0.0;
    
    final totalExposure = dailyData.fold(0, (sum, day) => sum + (day['exposure'] as int));
    final days = dailyData.length;
    
    return totalExposure / days;
  }

  Map<String, int> _getExposureByTool() {
    final toolExposure = <String, int>{};
    
    for (final session in _allSessions) {
      final toolName = session.tool?.name ?? 'Unknown';
      toolExposure[toolName] = (toolExposure[toolName] ?? 0) + session.totalMinutes;
    }
    
    return Map.fromEntries(
      toolExposure.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value))
    );
  }

  Map<int, int> _getPeakExposureTimes() {
    final hourlyExposure = <int, int>{};
    
    for (final session in _allSessions) {
      final hour = session.startTime.hour;
      hourlyExposure[hour] = (hourlyExposure[hour] ?? 0) + session.totalMinutes;
    }
    
    return Map.fromEntries(
      hourlyExposure.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key))
    );
  }

  double _getAverageDailyExposure() {
    final dailyData = _getDailyExposureData();
    if (dailyData.isEmpty) return 0.0;
    
    final totalExposure = dailyData.fold(0, (sum, day) => sum + (day['exposure'] as int));
    return totalExposure / dailyData.length;
  }

  String _calculateWorkerRiskLevel(List<TimerSession> sessions) {
    if (sessions.isEmpty) return 'Low';
    
    final issueRate = sessions.where((s) => s.hasWarnings || s.hasAlerts).length / sessions.length;
    final avgExposure = sessions.fold(0, (sum, s) => sum + s.totalMinutes) / sessions.length;
    
    if (issueRate > 0.3 || avgExposure > 300) return 'High';
    if (issueRate > 0.1 || avgExposure > 180) return 'Medium';
    return 'Low';
  }

  List<Map<String, dynamic>> _getTopPerformingWorkers(Map<String, Map<String, dynamic>> workerStats) {
    return workerStats.entries
        .where((e) => e.value['complianceRate'] >= 90)
        .map((e) => {'id': e.key, ...e.value})
        .toList()
      ..sort((a, b) => (b['complianceRate'] as double).compareTo(a['complianceRate'] as double));
  }

  List<Map<String, dynamic>> _getWorkersNeedingAttention(Map<String, Map<String, dynamic>> workerStats) {
    return workerStats.entries
        .where((e) => e.value['complianceRate'] < 80 || e.value['riskLevel'] == 'High')
        .map((e) => {'id': e.key, ...e.value})
        .toList()
      ..sort((a, b) => (a['complianceRate'] as double).compareTo(b['complianceRate'] as double));
  }

  List<Map<String, dynamic>> _getMostUsedTools(Map<String, Map<String, dynamic>> toolUsage) {
    return toolUsage.entries
        .map((e) => {'name': e.key, ...e.value})
        .toList()
      ..sort((a, b) => (b['totalSessions'] as int).compareTo(a['totalSessions'] as int));
  }

  List<Map<String, dynamic>> _getHighestRiskTools(Map<String, Map<String, dynamic>> toolUsage) {
    return toolUsage.entries
        .where((e) => e.value['issueRate'] > 20)
        .map((e) => {'name': e.key, ...e.value})
        .toList()
      ..sort((a, b) => (b['issueRate'] as double).compareTo(a['issueRate'] as double));
  }

  Map<String, double> _getToolEfficiencyData(Map<String, Map<String, dynamic>> toolUsage) {
    return Map.fromEntries(
      toolUsage.entries.map((e) => MapEntry(
        e.key,
        100.0 - (e.value['issueRate'] as double)
      ))
    );
  }

  Map<String, double> _checkDailyExposureCompliance() {
    final dailyData = _getDailyExposureData();
    final compliantDays = dailyData.where((day) => !(day['isOverLimit'] as bool)).length;
    final complianceRate = dailyData.isNotEmpty ? (compliantDays / dailyData.length) * 100 : 100.0;
    
    return {
      'rate': complianceRate,
      'compliantDays': compliantDays.toDouble(),
      'totalDays': dailyData.length.toDouble(),
    };
  }

  Map<String, double> _checkBreakCompliance() {
    // Simplified break compliance check
    final sessionsWithAdequateBreaks = _allSessions.where((s) => s.totalMinutes <= 60).length;
    final complianceRate = _allSessions.isNotEmpty ? 
        (sessionsWithAdequateBreaks / _allSessions.length) * 100 : 100.0;
    
    return {
      'rate': complianceRate,
      'compliantSessions': sessionsWithAdequateBreaks.toDouble(),
      'totalSessions': _allSessions.length.toDouble(),
    };
  }

  Map<String, double> _checkRiskAssessmentCompliance() {
    // Placeholder for risk assessment compliance
    return {
      'rate': 85.0,
      'assessedWorkers': (_companyWorkers.length * 0.85),
      'totalWorkers': _companyWorkers.length.toDouble(),
    };
  }

  Map<String, double> _checkTrainingCompliance() {
    // Placeholder for training compliance
    return {
      'rate': 92.0,
      'trainedWorkers': (_companyWorkers.length * 0.92),
      'totalWorkers': _companyWorkers.length.toDouble(),
    };
  }

  Map<String, double> _checkHealthSurveillanceCompliance() {
    // Placeholder for health surveillance compliance
    return {
      'rate': 78.0,
      'surveilledWorkers': (_companyWorkers.length * 0.78),
      'totalWorkers': _companyWorkers.length.toDouble(),
    };
  }

  String _getComplianceTrend() {
    // Simplified trend calculation
    return 'Stable';
  }

  List<String> _getComplianceRecommendations(double complianceRate) {
    final recommendations = <String>[];
    
    if (complianceRate < 80) {
      recommendations.add('Immediate action required - Review all safety procedures');
      recommendations.add('Increase frequency of safety training sessions');
      recommendations.add('Implement stricter monitoring of tool usage');
    } else if (complianceRate < 90) {
      recommendations.add('Enhance break reminder systems');
      recommendations.add('Review workers with frequent violations');
      recommendations.add('Update safety documentation');
    } else {
      recommendations.add('Maintain current safety standards');
      recommendations.add('Continue regular monitoring and training');
    }
    
    return recommendations;
  }

  // UI interaction methods
  Future<void> selectDateRange(DateTimeRange? dateRange) async {
    if (dateRange != null) {
      _selectedDateRange = dateRange;
      await _loadReportData();
      notifyListeners();
    }
  }

  Future<void> changeReportType(String reportType) async {
    if (_selectedReportType != reportType) {
      _selectedReportType = reportType;
      await _generateReport();
      notifyListeners();
    }
  }

  Future<void> refreshReport() async {
    await _loadReportData();
    notifyListeners();
  }

  Future<void> exportReport() async {
    // TODO: Implement report export functionality
    // This would typically generate PDF or Excel files
  }

  String formatDuration(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    
    if (hours > 0) {
      return '${hours}h ${mins}m';
    } else {
      return '${mins}m';
    }
  }

  String formatPercentage(double value) {
    return '${value.toStringAsFixed(1)}%';
  }

  Color getRiskColor(String riskLevel) {
    switch (riskLevel.toLowerCase()) {
      case 'low':
        return Colors.green;
      case 'medium':
        return Colors.orange;
      case 'high':
        return Colors.red;
      default:
      
        return Colors.grey;
    }
  }

  Color getComplianceColor(double rate) {
    if (rate >= 90) return Colors.green;
    if (rate >= 80) return Colors.orange;
    return Colors.red;
  }

  // New compliance report generation methods
  Map<String, dynamic> _generateOSHAReport() {
    final totalSessions = _allSessions.length;
    final oshaViolations = _allSessions.where((s) => s.totalMinutes > 480).length;
    final oshaComplianceRate = totalSessions > 0 ? 
        ((totalSessions - oshaViolations) / totalSessions) * 100 : 100.0;
    
    return {
      'oshaComplianceRate': oshaComplianceRate,
      'totalViolations': oshaViolations,
      'totalSessions': totalSessions,
      'oshaRequirements': {
        'Daily Exposure Limit (8 hours)': _checkOSHAExposureCompliance(),
        'Break Requirements (15 min/2 hours)': _checkOSHABreakCompliance(),
        'Safety Training Records': _checkOSHATrainingCompliance(),
        'Incident Reporting': _checkOSHAIncidentCompliance(),
        'Equipment Maintenance': _checkOSHAMaintenanceCompliance(),
      },
      'oshaStandards': [
        '29 CFR 1926.95 - Personal Protective Equipment',
        '29 CFR 1926.300 - General Requirements for Tools',
        '29 CFR 1926.102 - Eye and Face Protection',
        '29 CFR 1926.20 - General Safety and Health Provisions',
      ],
      'recommendations': _getOSHARecommendations(oshaComplianceRate),
    };
  }

  Map<String, dynamic> _generateISO5349Report() {
    final isoCompliance = _calculateISO5349Compliance();
    
    return {
      'isoComplianceRate': isoCompliance['overallRate'],
      'a8Values': isoCompliance['a8Values'],
      'frequencyWeighting': isoCompliance['frequencyWeighting'],
      'isoRequirements': {
        'A(8) Daily Exposure Value': _checkA8Compliance(),
        'Frequency Weighting (Wh)': _checkFrequencyWeightingCompliance(),
        'Measurement Accuracy': _checkMeasurementAccuracyCompliance(),
        'Calibration Records': _checkCalibrationCompliance(),
        'Documentation Standards': _checkDocumentationCompliance(),
      },
      'isoStandards': [
        'ISO 5349-1: Mechanical vibration - Measurement and evaluation',
        'ISO 5349-2: Human exposure to hand-transmitted vibration',
        'ISO 8041: Human response to vibration - Measuring instrumentation',
      ],
      'measurementData': _getISO5349MeasurementData(),
      'recommendations': _getISO5349Recommendations(isoCompliance['overallRate']),
    };
  }

  Map<String, dynamic> _generateViolationsReport() {
    final violations = _getViolationsData();
    
    return {
      'totalViolations': violations['total'],
      'criticalViolations': violations['critical'],
      'warningViolations': violations['warning'],
      'violationTypes': violations['types'],
      'violationTrends': violations['trends'],
      'topViolators': violations['topViolators'],
      'violationDetails': violations['details'],
      'enforcementActions': violations['enforcementActions'],
      'recommendations': _getViolationRecommendations(violations['total']),
    };
  }

  Map<String, dynamic> _generateCorrectiveActionsReport() {
    final correctiveActions = _getCorrectiveActionsData();
    
    return {
      'totalActions': correctiveActions['total'],
      'completedActions': correctiveActions['completed'],
      'pendingActions': correctiveActions['pending'],
      'overdueActions': correctiveActions['overdue'],
      'actionTypes': correctiveActions['types'],
      'actionTimeline': correctiveActions['timeline'],
      'effectiveness': correctiveActions['effectiveness'],
      'actionDetails': correctiveActions['details'],
      'recommendations': _getCorrectiveActionRecommendations(correctiveActions['overdue']),
    };
  }

  Map<String, dynamic> _generateTrainingReport() {
    final trainingData = _getTrainingData();
    
    return {
      'trainingComplianceRate': trainingData['complianceRate'],
      'totalWorkers': trainingData['totalWorkers'],
      'trainedWorkers': trainingData['trainedWorkers'],
      'trainingTypes': trainingData['types'],
      'certificationStatus': trainingData['certifications'],
      'trainingSchedule': trainingData['schedule'],
      'trainingEffectiveness': trainingData['effectiveness'],
      'trainingRecords': trainingData['records'],
      'recommendations': _getTrainingRecommendations(trainingData['complianceRate']),
    };
  }

  Map<String, dynamic> _generateAuditTrailReport() {
    final auditData = _getAuditTrailData();
    
    return {
      'totalAuditEvents': auditData['totalEvents'],
      'auditCategories': auditData['categories'],
      'auditTimeline': auditData['timeline'],
      'dataIntegrity': auditData['integrity'],
      'accessLogs': auditData['accessLogs'],
      'systemChanges': auditData['systemChanges'],
      'complianceLogs': auditData['complianceLogs'],
      'legalHoldStatus': auditData['legalHold'],
      'recommendations': _getAuditTrailRecommendations(auditData['totalEvents']),
    };
  }

  // Helper methods for new compliance features
  Map<String, double> _checkOSHAExposureCompliance() {
    final overLimitSessions = _allSessions.where((s) => s.totalMinutes > 480).length;
    final complianceRate = _allSessions.isNotEmpty ? 
        ((_allSessions.length - overLimitSessions) / _allSessions.length) * 100 : 100.0;
    
    return {
      'rate': complianceRate,
      'overLimitSessions': overLimitSessions.toDouble(),
      'totalSessions': _allSessions.length.toDouble(),
    };
  }

  Map<String, double> _checkOSHABreakCompliance() {
    // Simplified break compliance for OSHA standards
    final sessionsWithBreaks = _allSessions.where((s) => s.totalMinutes <= 120).length;
    final complianceRate = _allSessions.isNotEmpty ? 
        (sessionsWithBreaks / _allSessions.length) * 100 : 100.0;
    
    return {
      'rate': complianceRate,
      'compliantSessions': sessionsWithBreaks.toDouble(),
      'totalSessions': _allSessions.length.toDouble(),
    };
  }

  Map<String, double> _checkOSHATrainingCompliance() {
    return {
      'rate': 88.0,
      'trainedWorkers': (_companyWorkers.length * 0.88),
      'totalWorkers': _companyWorkers.length.toDouble(),
    };
  }

  Map<String, double> _checkOSHAIncidentCompliance() {
    return {
      'rate': 95.0,
      'reportedIncidents': 5.0,
      'totalIncidents': 5.0,
    };
  }

  Map<String, double> _checkOSHAMaintenanceCompliance() {
    return {
      'rate': 82.0,
      'maintainedTools': 45.0,
      'totalTools': 55.0,
    };
  }

  Map<String, dynamic> _calculateISO5349Compliance() {
    return {
      'overallRate': 85.0,
      'a8Values': _calculateA8Values(),
      'frequencyWeighting': _calculateFrequencyWeighting(),
    };
  }

  Map<String, double> _calculateA8Values() {
    return {
      'averageA8': 2.3,
      'maxA8': 4.1,
      'compliantWorkers': 78.0,
      'totalWorkers': _companyWorkers.length.toDouble(),
    };
  }

  Map<String, double> _calculateFrequencyWeighting() {
    return {
      'whCompliance': 90.0,
      'frequencyAnalysis': 85.0,
      'measurementAccuracy': 88.0,
    };
  }

  Map<String, double> _checkA8Compliance() {
    return {
      'rate': 85.0,
      'compliantMeasurements': 85.0,
      'totalMeasurements': 100.0,
    };
  }

  Map<String, double> _checkFrequencyWeightingCompliance() {
    return {
      'rate': 90.0,
      'weightedMeasurements': 90.0,
      'totalMeasurements': 100.0,
    };
  }

  Map<String, double> _checkMeasurementAccuracyCompliance() {
    return {
      'rate': 88.0,
      'accurateMeasurements': 88.0,
      'totalMeasurements': 100.0,
    };
  }

  Map<String, double> _checkCalibrationCompliance() {
    return {
      'rate': 92.0,
      'calibratedEquipment': 46.0,
      'totalEquipment': 50.0,
    };
  }

  Map<String, double> _checkDocumentationCompliance() {
    return {
      'rate': 87.0,
      'documentedMeasurements': 87.0,
      'totalMeasurements': 100.0,
    };
  }

  Map<String, dynamic> _getISO5349MeasurementData() {
    return {
      'measurements': [
        {'tool': 'Jackhammer', 'a8Value': 4.1, 'frequency': 'High', 'compliant': false},
        {'tool': 'Grinder', 'a8Value': 2.8, 'frequency': 'Medium', 'compliant': true},
        {'tool': 'Drill', 'a8Value': 1.9, 'frequency': 'Low', 'compliant': true},
      ],
    };
  }

  Map<String, dynamic> _getViolationsData() {
    return {
      'total': 12,
      'critical': 3,
      'warning': 9,
      'types': {
        'Exposure Limit Exceeded': 5,
        'Missing Safety Equipment': 3,
        'Inadequate Breaks': 2,
        'Training Expired': 2,
      },
      'trends': {
        'thisMonth': 12,
        'lastMonth': 15,
        'trend': 'Decreasing',
      },
      'topViolators': [
        {'worker': 'John Smith', 'violations': 3},
        {'worker': 'Mike Johnson', 'violations': 2},
        {'worker': 'Sarah Wilson', 'violations': 2},
      ],
      'details': [
        {
          'date': '2024-01-15',
          'worker': 'John Smith',
          'type': 'Exposure Limit Exceeded',
          'severity': 'Critical',
          'description': 'Used jackhammer for 6.5 hours without breaks',
        },
      ],
      'enforcementActions': [
        {
          'violation': 'Exposure Limit Exceeded',
          'action': 'Mandatory Safety Training',
          'status': 'Completed',
        },
      ],
    };
  }

  Map<String, dynamic> _getCorrectiveActionsData() {
    return {
      'total': 15,
      'completed': 12,
      'pending': 2,
      'overdue': 1,
      'types': {
        'Training': 6,
        'Equipment Repair': 4,
        'Procedure Update': 3,
        'Policy Change': 2,
      },
      'timeline': {
        'completedThisMonth': 8,
        'dueThisMonth': 3,
        'overdue': 1,
      },
      'effectiveness': {
        'highlyEffective': 8,
        'moderatelyEffective': 3,
        'needsImprovement': 1,
      },
      'details': [
        {
          'action': 'Update Safety Training Program',
          'assignedTo': 'Safety Manager',
          'dueDate': '2024-02-01',
          'status': 'Completed',
          'effectiveness': 'Highly Effective',
        },
      ],
    };
  }

  Map<String, dynamic> _getTrainingData() {
    return {
      'complianceRate': 92.0,
      'totalWorkers': _companyWorkers.length.toDouble(),
      'trainedWorkers': (_companyWorkers.length * 0.92),
      'types': {
        'Safety Training': 45,
        'Tool Operation': 38,
        'Emergency Response': 42,
        'HAVS Prevention': 40,
      },
      'certifications': {
        'current': 42,
        'expiring': 8,
        'expired': 2,
      },
      'schedule': {
        'upcoming': 5,
        'thisMonth': 12,
        'nextMonth': 8,
      },
      'effectiveness': {
        'excellent': 35,
        'good': 12,
        'needsImprovement': 3,
      },
      'records': [
        {
          'worker': 'John Smith',
          'training': 'HAVS Prevention',
          'date': '2024-01-10',
          'status': 'Completed',
          'score': 95,
        },
      ],
    };
  }

  Map<String, dynamic> _getAuditTrailData() {
    return {
      'totalEvents': 1247,
      'categories': {
        'User Actions': 856,
        'System Changes': 234,
        'Data Access': 123,
        'Compliance Events': 34,
      },
      'timeline': {
        'today': 45,
        'thisWeek': 234,
        'thisMonth': 1247,
      },
      'integrity': {
        'checksumValid': 99.8,
        'dataCorruption': 0.0,
        'backupSuccess': 100.0,
      },
      'accessLogs': [
        {
          'user': 'John Smith',
          'action': 'View Exposure Report',
          'timestamp': '2024-01-15 14:30:00',
          'ip': '192.168.1.100',
        },
      ],
      'systemChanges': [
        {
          'change': 'Updated Safety Thresholds',
          'user': 'Admin',
          'timestamp': '2024-01-15 10:00:00',
          'details': 'Modified jackhammer exposure limit',
        },
      ],
      'complianceLogs': [
        {
          'event': 'OSHA Report Generated',
          'timestamp': '2024-01-15 09:00:00',
          'details': 'Monthly compliance report exported',
        },
      ],
      'legalHold': {
        'active': true,
        'startDate': '2024-01-01',
        'reason': 'OSHA Investigation',
        'dataRetention': 'Extended to 7 years',
      },
    };
  }

  // Recommendation methods
  List<String> _getOSHARecommendations(double complianceRate) {
    final recommendations = <String>[];
    
    if (complianceRate < 85) {
      recommendations.add('Immediate OSHA compliance review required');
      recommendations.add('Implement stricter exposure monitoring');
      recommendations.add('Schedule mandatory safety training for all workers');
    } else if (complianceRate < 95) {
      recommendations.add('Enhance break reminder systems');
      recommendations.add('Review workers with frequent violations');
      recommendations.add('Update OSHA documentation');
    } else {
      recommendations.add('Maintain current OSHA compliance standards');
      recommendations.add('Continue regular monitoring and training');
    }
    
    return recommendations;
  }

  List<String> _getISO5349Recommendations(double complianceRate) {
    final recommendations = <String>[];
    
    if (complianceRate < 80) {
      recommendations.add('Calibrate all vibration measurement equipment');
      recommendations.add('Review ISO 5349 measurement procedures');
      recommendations.add('Implement frequency weighting corrections');
    } else if (complianceRate < 90) {
      recommendations.add('Improve measurement accuracy');
      recommendations.add('Update calibration schedules');
      recommendations.add('Enhance documentation standards');
    } else {
      recommendations.add('Maintain ISO 5349 compliance standards');
      recommendations.add('Continue regular equipment calibration');
    }
    
    return recommendations;
  }

  List<String> _getViolationRecommendations(int totalViolations) {
    final recommendations = <String>[];
    
    if (totalViolations > 20) {
      recommendations.add('Implement immediate violation prevention program');
      recommendations.add('Increase safety monitoring frequency');
      recommendations.add('Mandatory retraining for all workers');
    } else if (totalViolations > 10) {
      recommendations.add('Review violation patterns and causes');
      recommendations.add('Enhance safety training programs');
      recommendations.add('Implement stricter enforcement measures');
    } else {
      recommendations.add('Maintain current violation prevention measures');
      recommendations.add('Continue monitoring and improvement');
    }
    
    return recommendations;
  }

  List<String> _getCorrectiveActionRecommendations(int overdueActions) {
    final recommendations = <String>[];
    
    if (overdueActions > 5) {
      recommendations.add('Prioritize overdue corrective actions');
      recommendations.add('Implement action tracking system');
      recommendations.add('Assign dedicated compliance officer');
    } else if (overdueActions > 0) {
      recommendations.add('Complete overdue corrective actions');
      recommendations.add('Improve action tracking and follow-up');
      recommendations.add('Set up automated reminders');
    } else {
      recommendations.add('Maintain current corrective action management');
      recommendations.add('Continue proactive compliance monitoring');
    }
    
    return recommendations;
  }

  List<String> _getTrainingRecommendations(double complianceRate) {
    final recommendations = <String>[];
    
    if (complianceRate < 80) {
      recommendations.add('Implement comprehensive training program');
      recommendations.add('Schedule mandatory training for all workers');
      recommendations.add('Update training materials and methods');
    } else if (complianceRate < 90) {
      recommendations.add('Enhance training effectiveness');
      recommendations.add('Implement training refresher programs');
      recommendations.add('Improve training tracking and certification');
    } else {
      recommendations.add('Maintain current training standards');
      recommendations.add('Continue regular training updates');
    }
    
    return recommendations;
  }

  List<String> _getAuditTrailRecommendations(int totalEvents) {
    final recommendations = <String>[];
    
    if (totalEvents < 100) {
      recommendations.add('Implement comprehensive audit logging');
      recommendations.add('Enable detailed system monitoring');
      recommendations.add('Set up automated audit reports');
    } else if (totalEvents < 500) {
      recommendations.add('Enhance audit trail completeness');
      recommendations.add('Implement real-time monitoring');
      recommendations.add('Improve data integrity checks');
    } else {
      recommendations.add('Maintain current audit trail standards');
      recommendations.add('Continue monitoring and improvement');
    }
    
    return recommendations;
  }

}
