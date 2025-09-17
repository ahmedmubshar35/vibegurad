import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/admin/dashboard_models.dart';
import '../../models/timer/timer_session.dart';

/// Safety violation detection and reporting service
class SafetyViolationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // Notification service would be injected in production

  // Stream controller for real-time violation alerts
  final _violationStreamController = StreamController<SafetyViolation>.broadcast();
  Stream<SafetyViolation> get violationStream => _violationStreamController.stream;

  // Timer for periodic violation checks
  Timer? _violationCheckTimer;

  /// Initialize violation monitoring
  Future<void> initialize() async {
    await _startViolationMonitoring();
    _startPeriodicViolationChecks();
  }

  /// Start real-time violation monitoring
  Future<void> _startViolationMonitoring() async {
    // Monitor active timer sessions for exposure violations
    _firestore
        .collection('timer_sessions')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .listen((snapshot) {
      for (final doc in snapshot.docs) {
        _checkSessionForViolations(doc);
      }
    });

    // Monitor health profiles for medical exam compliance
    _firestore
        .collection('health_profiles')
        .snapshots()
        .listen((snapshot) {
      for (final doc in snapshot.docs) {
        _checkMedicalExamCompliance(doc);
      }
    });
  }

  /// Check timer session for violations
  Future<void> _checkSessionForViolations(DocumentSnapshot sessionDoc) async {
    try {
      final sessionData = sessionDoc.data() as Map<String, dynamic>;
      final workerId = sessionData['workerId'] as String;
      
      // Get worker details
      final workerDoc = await _firestore.collection('users').doc(workerId).get();
      if (!workerDoc.exists) return;
      
      final workerData = workerDoc.data()!;
      final workerName = '${workerData['firstName']} ${workerData['lastName']}';

      // Check daily exposure limit violation
      final dailyExposure = await _calculateDailyExposure(workerId);
      if (dailyExposure > 5.0) {
        await _recordViolation(
          workerId: workerId,
          workerName: workerName,
          violationType: 'daily_exposure_limit',
          severity: dailyExposure > 10.0 ? 'critical' : 'high',
          description: 'Daily exposure limit exceeded: ${dailyExposure.toStringAsFixed(2)} m/s² (Limit: 5.0 m/s²)',
          exposureValue: dailyExposure,
          toolId: sessionData['toolId'],
        );
      }

      // Check continuous session duration violation
      final sessionDuration = sessionData['totalMinutes'] as int? ?? 0;
      if (sessionDuration > 240) { // 4 hours continuous
        await _recordViolation(
          workerId: workerId,
          workerName: workerName,
          violationType: 'excessive_continuous_exposure',
          severity: 'medium',
          description: 'Excessive continuous exposure: ${sessionDuration} minutes without break',
          toolId: sessionData['toolId'],
        );
      }

      // Check high vibration tool usage without PPE
      final vibrationLevel = sessionData['vibrationLevel'] as double? ?? 0.0;
      if (vibrationLevel > 8.0) {
        final hasPPE = await _checkPPEUsage(workerId);
        if (!hasPPE) {
          await _recordViolation(
            workerId: workerId,
            workerName: workerName,
            violationType: 'high_vibration_without_ppe',
            severity: 'high',
            description: 'High vibration tool (${vibrationLevel.toStringAsFixed(1)} m/s²) used without proper PPE',
            exposureValue: vibrationLevel,
            toolId: sessionData['toolId'],
          );
        }
      }

      // Check tool maintenance status
      final toolId = sessionData['toolId'] as String?;
      if (toolId != null) {
        final isMaintenanceOverdue = await _isToolMaintenanceOverdue(toolId);
        if (isMaintenanceOverdue) {
          await _recordViolation(
            workerId: workerId,
            workerName: workerName,
            violationType: 'maintenance_overdue_usage',
            severity: 'medium',
            description: 'Using tool with overdue maintenance',
            toolId: toolId,
          );
        }
      }
    } catch (e) {
      print('Error checking session for violations: $e');
    }
  }

  /// Check medical examination compliance
  Future<void> _checkMedicalExamCompliance(DocumentSnapshot profileDoc) async {
    try {
      final profileData = profileDoc.data() as Map<String, dynamic>;
      final workerId = profileDoc.id;
      
      // Get worker details
      final workerDoc = await _firestore.collection('users').doc(workerId).get();
      if (!workerDoc.exists) return;
      
      final workerData = workerDoc.data()!;
      final workerName = '${workerData['firstName']} ${workerData['lastName']}';

      // Check medical exam due date
      final nextExamDue = profileData['nextMedicalExamDue'] as Timestamp?;
      if (nextExamDue != null && nextExamDue.toDate().isBefore(DateTime.now())) {
        final daysOverdue = DateTime.now().difference(nextExamDue.toDate()).inDays;
        
        await _recordViolation(
          workerId: workerId,
          workerName: workerName,
          violationType: 'medical_exam_overdue',
          severity: daysOverdue > 90 ? 'critical' : 'medium',
          description: 'Medical examination overdue by $daysOverdue days',
        );
      }

      // Check HAVS stage progression without medical review
      final havsStage = profileData['havsStage'] as int? ?? 0;
      final lastExam = profileData['lastHealthAssessment'] as Timestamp?;
      
      if (havsStage >= 2 && lastExam != null) {
        final daysSinceExam = DateTime.now().difference(lastExam.toDate()).inDays;
        if (daysSinceExam > 180) { // 6 months
          await _recordViolation(
            workerId: workerId,
            workerName: workerName,
            violationType: 'havs_progression_no_review',
            severity: 'high',
            description: 'HAVS Stage $havsStage with no medical review for $daysSinceExam days',
          );
        }
      }
    } catch (e) {
      print('Error checking medical exam compliance: $e');
    }
  }

  /// Record a safety violation
  Future<void> _recordViolation({
    required String workerId,
    required String workerName,
    required String violationType,
    required String severity,
    required String description,
    double? exposureValue,
    String? toolId,
    String? locationId,
  }) async {
    try {
      // Check if similar violation already exists recently
      final recentViolation = await _checkRecentSimilarViolation(
        workerId, 
        violationType,
      );
      
      if (recentViolation) return; // Avoid duplicate violations

      final violation = SafetyViolation(
        violationId: '',
        workerId: workerId,
        workerName: workerName,
        occurredAt: DateTime.now(),
        violationType: violationType,
        severity: severity,
        description: description,
        exposureValue: exposureValue,
        toolId: toolId,
        locationId: locationId,
        correctionsTaken: [],
        isResolved: false,
        resolvedBy: null,
        resolvedAt: null,
      );

      // Save to Firestore
      final docRef = await _firestore
          .collection('safety_violations')
          .add(_violationToFirestore(violation));

      final savedViolation = SafetyViolation(
        violationId: docRef.id,
        workerId: violation.workerId,
        workerName: violation.workerName,
        occurredAt: violation.occurredAt,
        violationType: violation.violationType,
        severity: violation.severity,
        description: violation.description,
        exposureValue: violation.exposureValue,
        toolId: violation.toolId,
        locationId: violation.locationId,
        correctionsTaken: violation.correctionsTaken,
        isResolved: violation.isResolved,
        resolvedBy: violation.resolvedBy,
        resolvedAt: violation.resolvedAt,
      );

      // Broadcast violation
      _violationStreamController.add(savedViolation);

      // Send notifications
      await _sendViolationNotifications(savedViolation);

      // Take automatic corrective actions
      await _takeAutomaticCorrectiveActions(savedViolation);

    } catch (e) {
      print('Error recording violation: $e');
    }
  }

  /// Send violation notifications
  Future<void> _sendViolationNotifications(SafetyViolation violation) async {
    try {
      // Notify worker
      print('Notifying worker ${violation.workerId} of violation: ${violation.description}');

      // Notify supervisors/admin for high severity violations
      if (violation.severity == 'critical' || violation.severity == 'high') {
        await _notifySupervisors(violation);
      }
    } catch (e) {
      print('Error sending violation notifications: $e');
    }
  }

  /// Take automatic corrective actions
  Future<void> _takeAutomaticCorrectiveActions(SafetyViolation violation) async {
    try {
      final corrections = <String>[];

      switch (violation.violationType) {
        case 'daily_exposure_limit':
          // Suggest break or end session
          corrections.add('Mandatory break period initiated');
          corrections.add('Exposure monitoring increased');
          break;

        case 'excessive_continuous_exposure':
          // Force break period
          corrections.add('Break period enforced');
          corrections.add('Job rotation suggested');
          break;

        case 'high_vibration_without_ppe':
          // PPE reminder
          corrections.add('PPE compliance reminder sent');
          corrections.add('Safety briefing scheduled');
          break;

        case 'maintenance_overdue_usage':
          // Tool restriction
          corrections.add('Tool usage restricted pending maintenance');
          corrections.add('Maintenance team notified');
          break;

        case 'medical_exam_overdue':
          // Schedule medical exam
          corrections.add('Medical examination scheduled');
          corrections.add('Work restrictions considered');
          break;
      }

      // Update violation with corrections
      if (corrections.isNotEmpty) {
        await _firestore
            .collection('safety_violations')
            .doc(violation.violationId)
            .update({
          'correctionsTaken': corrections,
        });
      }
    } catch (e) {
      print('Error taking corrective actions: $e');
    }
  }

  /// Resolve safety violation
  Future<void> resolveViolation({
    required String violationId,
    required String resolvedBy,
    List<String>? additionalCorrections,
  }) async {
    try {
      final corrections = additionalCorrections ?? [];
      
      await _firestore
          .collection('safety_violations')
          .doc(violationId)
          .update({
        'isResolved': true,
        'resolvedBy': resolvedBy,
        'resolvedAt': Timestamp.now(),
        'correctionsTaken': FieldValue.arrayUnion(corrections),
      });
    } catch (e) {
      print('Error resolving violation: $e');
    }
  }

  /// Get safety violations for worker
  Future<List<SafetyViolation>> getWorkerViolations({
    required String workerId,
    DateTime? startDate,
    DateTime? endDate,
    bool includeResolved = true,
  }) async {
    try {
      Query query = _firestore
          .collection('safety_violations')
          .where('workerId', isEqualTo: workerId);

      if (!includeResolved) {
        query = query.where('isResolved', isEqualTo: false);
      }

      if (startDate != null) {
        query = query.where('occurredAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }

      if (endDate != null) {
        query = query.where('occurredAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
      }

      final result = await query.orderBy('occurredAt', descending: true).get();
      
      return result.docs
          .map((doc) => _violationFromFirestore(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    } catch (e) {
      print('Error getting worker violations: $e');
      return [];
    }
  }

  /// Get department violations summary
  Future<Map<String, int>> getDepartmentViolationsSummary({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      startDate ??= DateTime.now().subtract(const Duration(days: 30));
      endDate ??= DateTime.now();

      final violations = await _firestore
          .collection('safety_violations')
          .where('occurredAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('occurredAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .get();

      final departmentCounts = <String, int>{};

      for (final doc in violations.docs) {
        final workerId = doc.data()['workerId'] as String;
        
        // Get worker's department
        final workerDoc = await _firestore.collection('users').doc(workerId).get();
        if (workerDoc.exists) {
          final department = workerDoc.data()!['department'] as String? ?? 'Unknown';
          departmentCounts[department] = (departmentCounts[department] ?? 0) + 1;
        }
      }

      return departmentCounts;
    } catch (e) {
      print('Error getting department violations summary: $e');
      return {};
    }
  }

  /// Get violation trends
  Future<List<ViolationTrend>> getViolationTrends({
    DateTime? startDate,
    DateTime? endDate,
    String groupBy = 'day', // 'day', 'week', 'month'
  }) async {
    try {
      startDate ??= DateTime.now().subtract(const Duration(days: 30));
      endDate ??= DateTime.now();

      final violations = await _firestore
          .collection('safety_violations')
          .where('occurredAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('occurredAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .orderBy('occurredAt')
          .get();

      final trends = <ViolationTrend>[];
      final groupedData = <DateTime, Map<String, int>>{};

      for (final doc in violations.docs) {
        final data = doc.data();
        final occurredAt = (data['occurredAt'] as Timestamp).toDate();
        final violationType = data['violationType'] as String;
        
        // Group by specified period
        final groupKey = _groupByPeriod(occurredAt, groupBy);
        
        groupedData[groupKey] ??= {};
        groupedData[groupKey]![violationType] = 
            (groupedData[groupKey]![violationType] ?? 0) + 1;
      }

      // Convert to trend objects
      for (final entry in groupedData.entries) {
        final totalCount = entry.value.values.fold<int>(0, (sum, count) => sum + count);
        
        trends.add(ViolationTrend(
          date: entry.key,
          totalCount: totalCount,
          violationsByType: entry.value,
        ));
      }

      return trends..sort((a, b) => a.date.compareTo(b.date));
    } catch (e) {
      print('Error getting violation trends: $e');
      return [];
    }
  }

  /// Start periodic violation checks
  void _startPeriodicViolationChecks() {
    _violationCheckTimer?.cancel();
    _violationCheckTimer = Timer.periodic(
      const Duration(minutes: 5), 
      (_) => _performPeriodicChecks(),
    );
  }

  /// Perform periodic violation checks
  Future<void> _performPeriodicChecks() async {
    try {
      // Check for inactive workers with active sessions
      await _checkInactiveWorkerSessions();
      
      // Check for location-based violations
      await _checkLocationViolations();
      
      // Check training compliance
      await _checkTrainingCompliance();
    } catch (e) {
      print('Error in periodic violation checks: $e');
    }
  }

  // Helper methods

  Future<double> _calculateDailyExposure(String workerId) async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);

    final sessions = await _firestore
        .collection('timer_sessions')
        .where('workerId', isEqualTo: workerId)
        .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .get();

    double totalA8 = 0.0;
    for (final doc in sessions.docs) {
      totalA8 += (doc.data()['dailyExposure'] ?? 0.0) as double;
    }

    return totalA8;
  }

  Future<bool> _checkPPEUsage(String workerId) async {
    // Check PPE compliance from latest session or profile
    final profileDoc = await _firestore
        .collection('health_profiles')
        .doc(workerId)
        .get();
    
    if (profileDoc.exists) {
      return profileDoc.data()!['usesPPE'] as bool? ?? false;
    }
    
    return false;
  }

  Future<bool> _isToolMaintenanceOverdue(String toolId) async {
    final toolDoc = await _firestore.collection('tools').doc(toolId).get();
    
    if (toolDoc.exists) {
      final data = toolDoc.data()!;
      final nextMaintenance = data['nextMaintenanceDate'] as Timestamp?;
      
      if (nextMaintenance != null) {
        return nextMaintenance.toDate().isBefore(DateTime.now());
      }
    }
    
    return false;
  }

  Future<bool> _checkRecentSimilarViolation(String workerId, String violationType) async {
    final recent = await _firestore
        .collection('safety_violations')
        .where('workerId', isEqualTo: workerId)
        .where('violationType', isEqualTo: violationType)
        .where('occurredAt', isGreaterThan: Timestamp.fromDate(
          DateTime.now().subtract(const Duration(hours: 1))
        ))
        .limit(1)
        .get();

    return recent.docs.isNotEmpty;
  }

  Future<void> _notifySupervisors(SafetyViolation violation) async {
    // Get supervisors for the worker's department
    final workerDoc = await _firestore.collection('users').doc(violation.workerId).get();
    if (!workerDoc.exists) return;

    final department = workerDoc.data()!['department'] as String?;
    if (department == null) return;

    final supervisors = await _firestore
        .collection('users')
        .where('role', isEqualTo: 'supervisor')
        .where('department', isEqualTo: department)
        .get();

    for (final supervisorDoc in supervisors.docs) {
      // Send notification to supervisor
      print('Notifying supervisor ${supervisorDoc.id} of violation: ${violation.description}');
    }
  }

  Future<void> _checkInactiveWorkerSessions() async {
    // Check for sessions that should be active but worker is inactive
    final activeSessions = await _firestore
        .collection('timer_sessions')
        .where('isActive', isEqualTo: true)
        .where('startTime', isLessThan: Timestamp.fromDate(
          DateTime.now().subtract(const Duration(hours: 2))
        ))
        .get();

    for (final sessionDoc in activeSessions.docs) {
      final workerId = sessionDoc.data()['workerId'] as String;
      
      // Check if worker has been active recently
      final recentActivity = await _firestore
          .collection('worker_locations')
          .doc(workerId)
          .get();

      if (!recentActivity.exists || 
          !(recentActivity.data()!['isActive'] as bool? ?? false)) {
        // Worker appears inactive with active session - potential issue
        print('Warning: Inactive worker with active session: $workerId');
      }
    }
  }

  Future<void> _checkLocationViolations() async {
    // Check for workers in restricted areas
    // Implementation would depend on location tracking system
  }

  Future<void> _checkTrainingCompliance() async {
    // Check for workers operating without required training
    // Implementation would depend on training management system
  }

  DateTime _groupByPeriod(DateTime date, String period) {
    switch (period) {
      case 'week':
        final weekday = date.weekday;
        return date.subtract(Duration(days: weekday - 1));
      case 'month':
        return DateTime(date.year, date.month, 1);
      case 'day':
      default:
        return DateTime(date.year, date.month, date.day);
    }
  }

  Map<String, dynamic> _violationToFirestore(SafetyViolation violation) {
    return {
      'workerId': violation.workerId,
      'workerName': violation.workerName,
      'occurredAt': Timestamp.fromDate(violation.occurredAt),
      'violationType': violation.violationType,
      'severity': violation.severity,
      'description': violation.description,
      'exposureValue': violation.exposureValue,
      'toolId': violation.toolId,
      'locationId': violation.locationId,
      'correctionsTaken': violation.correctionsTaken,
      'isResolved': violation.isResolved,
      'resolvedBy': violation.resolvedBy,
      'resolvedAt': violation.resolvedAt != null 
          ? Timestamp.fromDate(violation.resolvedAt!)
          : null,
    };
  }

  SafetyViolation _violationFromFirestore(Map<String, dynamic> data, String id) {
    return SafetyViolation(
      violationId: id,
      workerId: data['workerId'] ?? '',
      workerName: data['workerName'] ?? '',
      occurredAt: (data['occurredAt'] as Timestamp).toDate(),
      violationType: data['violationType'] ?? '',
      severity: data['severity'] ?? 'low',
      description: data['description'] ?? '',
      exposureValue: data['exposureValue']?.toDouble(),
      toolId: data['toolId'],
      locationId: data['locationId'],
      correctionsTaken: List<String>.from(data['correctionsTaken'] ?? []),
      isResolved: data['isResolved'] ?? false,
      resolvedBy: data['resolvedBy'],
      resolvedAt: data['resolvedAt'] != null
          ? (data['resolvedAt'] as Timestamp).toDate()
          : null,
    );
  }

  /// Clean up resources
  void dispose() {
    _violationCheckTimer?.cancel();
    _violationStreamController.close();
  }
}

/// Violation trend data
class ViolationTrend {
  final DateTime date;
  final int totalCount;
  final Map<String, int> violationsByType;

  ViolationTrend({
    required this.date,
    required this.totalCount,
    required this.violationsByType,
  });
}