import 'dart:async';
import 'package:injectable/injectable.dart';
import 'package:stacked_services/stacked_services.dart';
import 'package:get_it/get_it.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/core/user.dart';
import '../../enums/user_role.dart';
import '../../enums/exposure_level.dart';
import '../features/notification_service.dart';
import '../core/authentication_service.dart';

@lazySingleton
class SupervisorAlertService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = GetIt.instance<NotificationService>();
  final AuthenticationService _authService = GetIt.instance<AuthenticationService>();
  final SnackbarService _snackbarService = GetIt.instance<SnackbarService>();

  // Alert thresholds
  static const double exposureWarningThreshold = 2.5; // A(8) warning level
  static const double exposureCriticalThreshold = 5.0; // A(8) critical level
  static const int maxDailyExposureMinutes = 360; // 6 hours
  static const int emergencyStopThreshold = 3; // 3 emergency stops trigger supervisor alert

  SupervisorAlertService();

  // Alert supervisors about worker exposure violations
  Future<void> alertExposureViolation({
    required String workerId,
    required String workerName,
    required ExposureLevel exposureLevel,
    required double currentA8,
    required int totalExposureMinutes,
    String? toolName,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final supervisors = await _getCompanySupervisors();
      if (supervisors.isEmpty) return;

      final alertData = SupervisorAlert(
        id: '',
        workerId: workerId,
        workerName: workerName,
        alertType: SupervisorAlertType.exposureViolation,
        severity: _getSeverityFromExposureLevel(exposureLevel),
        title: 'Exposure Violation Alert',
        message: _getExposureViolationMessage(
          workerName, exposureLevel, currentA8, totalExposureMinutes, toolName,
        ),
        data: {
          'exposureLevel': exposureLevel.name,
          'currentA8': currentA8,
          'totalExposureMinutes': totalExposureMinutes,
          'toolName': toolName,
          'timestamp': DateTime.now().toIso8601String(),
          ...?additionalData,
        },
        isResolved: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Store alert in database
      final alertId = await _storeAlert(alertData);

      // Send notifications to all supervisors
      for (final supervisor in supervisors) {
        await _sendSupervisorNotification(
          supervisor,
          alertData.copyWith(id: alertId),
        );
      }

    } catch (e) {
      _snackbarService.showSnackbar(
        message: 'Failed to send supervisor alert: $e',
      );
    }
  }

  // Alert supervisors about emergency stops
  Future<void> alertEmergencyStop({
    required String workerId,
    required String workerName,
    required String reason,
    required String toolName,
    Map<String, dynamic>? sessionData,
  }) async {
    try {
      final supervisors = await _getCompanySupervisors();
      if (supervisors.isEmpty) return;

      final alertData = SupervisorAlert(
        id: '',
        workerId: workerId,
        workerName: workerName,
        alertType: SupervisorAlertType.emergencyStop,
        severity: AlertSeverity.critical,
        title: 'Emergency Stop Alert',
        message: 'EMERGENCY STOP: $workerName triggered emergency stop for $toolName. Reason: $reason',
        data: {
          'reason': reason,
          'toolName': toolName,
          'timestamp': DateTime.now().toIso8601String(),
          ...?sessionData,
        },
        isResolved: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final alertId = await _storeAlert(alertData);

      // Send high-priority notifications to all supervisors
      for (final supervisor in supervisors) {
        await _sendSupervisorNotification(
          supervisor,
          alertData.copyWith(id: alertId),
          isUrgent: true,
        );
      }

      // Check for frequent emergency stops
      await _checkFrequentEmergencyStops(workerId, workerName);

    } catch (e) {
      _snackbarService.showSnackbar(
        message: 'Failed to send emergency stop alert: $e',
      );
    }
  }

  // Alert supervisors about compliance violations
  Future<void> alertComplianceViolation({
    required String workerId,
    required String workerName,
    required ComplianceViolationType violationType,
    required String description,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final supervisors = await _getCompanySupervisors();
      if (supervisors.isEmpty) return;

      final alertData = SupervisorAlert(
        id: '',
        workerId: workerId,
        workerName: workerName,
        alertType: SupervisorAlertType.complianceViolation,
        severity: _getSeverityFromViolationType(violationType),
        title: 'Compliance Violation',
        message: '$workerName: ${violationType.displayName} - $description',
        data: {
          'violationType': violationType.name,
          'description': description,
          'timestamp': DateTime.now().toIso8601String(),
          ...?additionalData,
        },
        isResolved: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final alertId = await _storeAlert(alertData);

      for (final supervisor in supervisors) {
        await _sendSupervisorNotification(
          supervisor,
          alertData.copyWith(id: alertId),
        );
      }

    } catch (e) {
      _snackbarService.showSnackbar(
        message: 'Failed to send compliance violation alert: $e',
      );
    }
  }

  // Alert supervisors about overdue safety briefings
  Future<void> alertOverdueSafetyBriefing({
    required String workerId,
    required String workerName,
    required String briefingTitle,
    required int daysPastDue,
  }) async {
    try {
      final supervisors = await _getCompanySupervisors();
      if (supervisors.isEmpty) return;

      final severity = daysPastDue >= 7 ? AlertSeverity.critical : 
                     daysPastDue >= 3 ? AlertSeverity.high : AlertSeverity.medium;

      final alertData = SupervisorAlert(
        id: '',
        workerId: workerId,
        workerName: workerName,
        alertType: SupervisorAlertType.overdueBriefing,
        severity: severity,
        title: 'Overdue Safety Briefing',
        message: '$workerName has an overdue safety briefing: $briefingTitle ($daysPastDue days past due)',
        data: {
          'briefingTitle': briefingTitle,
          'daysPastDue': daysPastDue,
          'timestamp': DateTime.now().toIso8601String(),
        },
        isResolved: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final alertId = await _storeAlert(alertData);

      for (final supervisor in supervisors) {
        await _sendSupervisorNotification(
          supervisor,
          alertData.copyWith(id: alertId),
        );
      }

    } catch (e) {
      _snackbarService.showSnackbar(
        message: 'Failed to send overdue briefing alert: $e',
      );
    }
  }

  // Alert supervisors about tool maintenance issues
  Future<void> alertToolMaintenanceViolation({
    required String workerId,
    required String workerName,
    required String toolId,
    required String toolName,
    required String violationDescription,
    required bool isOverdue,
  }) async {
    try {
      final supervisors = await _getCompanySupervisors();
      if (supervisors.isEmpty) return;

      final alertData = SupervisorAlert(
        id: '',
        workerId: workerId,
        workerName: workerName,
        alertType: SupervisorAlertType.maintenanceViolation,
        severity: isOverdue ? AlertSeverity.critical : AlertSeverity.high,
        title: 'Tool Maintenance Violation',
        message: '$workerName used $toolName with maintenance issues: $violationDescription',
        data: {
          'toolId': toolId,
          'toolName': toolName,
          'violationDescription': violationDescription,
          'isOverdue': isOverdue,
          'timestamp': DateTime.now().toIso8601String(),
        },
        isResolved: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final alertId = await _storeAlert(alertData);

      for (final supervisor in supervisors) {
        await _sendSupervisorNotification(
          supervisor,
          alertData.copyWith(id: alertId),
        );
      }

    } catch (e) {
      _snackbarService.showSnackbar(
        message: 'Failed to send maintenance violation alert: $e',
      );
    }
  }

  // Check for frequent emergency stops pattern
  Future<void> _checkFrequentEmergencyStops(String workerId, String workerName) async {
    try {
      final oneWeekAgo = DateTime.now().subtract(const Duration(days: 7));
      
      final recentAlerts = await _firestore
          .collection('supervisor_alerts')
          .where('workerId', isEqualTo: workerId)
          .where('alertType', isEqualTo: SupervisorAlertType.emergencyStop.name)
          .where('createdAt', isGreaterThan: Timestamp.fromDate(oneWeekAgo))
          .get();

      if (recentAlerts.docs.length >= emergencyStopThreshold) {
        await alertComplianceViolation(
          workerId: workerId,
          workerName: workerName,
          violationType: ComplianceViolationType.frequentEmergencyStops,
          description: '${recentAlerts.docs.length} emergency stops in the past week',
          additionalData: {
            'emergencyStopCount': recentAlerts.docs.length,
            'timeFrame': '7 days',
          },
        );
      }
    } catch (e) {
      // Silent fail for pattern checking
    }
  }

  // Send notification to supervisor
  Future<void> _sendSupervisorNotification(
    User supervisor,
    SupervisorAlert alert, {
    bool isUrgent = false,
  }) async {
    try {
      final exposureLevel = _getExposureLevelFromSeverity(alert.severity);
      
      await _notificationService.showSafetyWarning(
        title: '👷‍♂️ ${alert.title}',
        body: alert.message,
        level: exposureLevel,
        payload: {
          'type': 'supervisor_alert',
          'alertType': alert.alertType.name,
          'alertId': alert.id,
          'workerId': alert.workerId,
          'severity': alert.severity.name,
          'isUrgent': isUrgent.toString(),
        },
      );

      // If urgent, also trigger additional notifications
      if (isUrgent) {
        // Could trigger SMS, email, or push notification to supervisor's device
        // Implementation would depend on additional notification services
      }

    } catch (e) {
      _snackbarService.showSnackbar(
        message: 'Failed to send supervisor notification: $e',
      );
    }
  }

  // Store alert in database
  Future<String> _storeAlert(SupervisorAlert alert) async {
    final docRef = await _firestore
        .collection('supervisor_alerts')
        .add(alert.toFirestore());
    return docRef.id;
  }

  // Get company supervisors
  Future<List<User>> _getCompanySupervisors() async {
    try {
      final currentUser = _authService.currentUser;
      if (currentUser?.companyId == null) return [];

      final query = await _firestore
          .collection('users')
          .where('companyId', isEqualTo: currentUser!.companyId)
          .where('role', whereIn: [UserRole.manager.name, UserRole.admin.name])
          .get();

      return query.docs
          .map((doc) => User.fromFirestore(doc.data(), doc.id))
          .toList();
    } catch (e) {
      return [];
    }
  }

  // Mark alert as resolved
  Future<void> resolveAlert({
    required String alertId,
    required String resolvedBy,
    String? resolutionNotes,
  }) async {
    try {
      await _firestore
          .collection('supervisor_alerts')
          .doc(alertId)
          .update({
        'isResolved': true,
        'resolvedBy': resolvedBy,
        'resolvedAt': FieldValue.serverTimestamp(),
        'resolutionNotes': resolutionNotes ?? '',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _snackbarService.showSnackbar(
        message: 'Alert marked as resolved',
      );
    } catch (e) {
      _snackbarService.showSnackbar(
        message: 'Failed to resolve alert: $e',
      );
    }
  }

  // Get supervisor alerts stream
  Stream<List<SupervisorAlert>> getSupervisorAlerts({
    String? workerId,
    SupervisorAlertType? alertType,
    bool? isResolved,
    int limit = 50,
  }) {
    Query query = _firestore
        .collection('supervisor_alerts')
        .orderBy('createdAt', descending: true)
        .limit(limit);

    if (workerId != null) {
      query = query.where('workerId', isEqualTo: workerId);
    }
    if (alertType != null) {
      query = query.where('alertType', isEqualTo: alertType.name);
    }
    if (isResolved != null) {
      query = query.where('isResolved', isEqualTo: isResolved);
    }

    return query.snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => SupervisorAlert.fromFirestore(doc)).toList());
  }

  // Helper methods
  String _getExposureViolationMessage(
    String workerName,
    ExposureLevel level,
    double currentA8,
    int totalMinutes,
    String? toolName,
  ) {
    final toolInfo = toolName != null ? ' using $toolName' : '';
    
    switch (level) {
      case ExposureLevel.low:
        return '$workerName$toolInfo - Safe exposure level (${currentA8.toStringAsFixed(2)} m/s²)';
      case ExposureLevel.medium:
        return '$workerName$toolInfo - Approaching exposure limits (${currentA8.toStringAsFixed(2)} m/s², ${totalMinutes}min)';
      case ExposureLevel.high:
        return '$workerName$toolInfo - High exposure detected (${currentA8.toStringAsFixed(2)} m/s², ${totalMinutes}min)';
      case ExposureLevel.critical:
        return 'CRITICAL: $workerName$toolInfo exceeded daily exposure limit (${currentA8.toStringAsFixed(2)} m/s², ${totalMinutes}min)';
    }
  }

  AlertSeverity _getSeverityFromExposureLevel(ExposureLevel level) {
    switch (level) {
      case ExposureLevel.low:
        return AlertSeverity.low;
      case ExposureLevel.medium:
        return AlertSeverity.medium;
      case ExposureLevel.high:
        return AlertSeverity.high;
      case ExposureLevel.critical:
        return AlertSeverity.critical;
    }
  }

  AlertSeverity _getSeverityFromViolationType(ComplianceViolationType type) {
    switch (type) {
      case ComplianceViolationType.missedBreak:
        return AlertSeverity.medium;
      case ComplianceViolationType.exceededDailyLimit:
        return AlertSeverity.critical;
      case ComplianceViolationType.improperToolUse:
        return AlertSeverity.high;
      case ComplianceViolationType.frequentEmergencyStops:
        return AlertSeverity.high;
      case ComplianceViolationType.maintenanceViolation:
        return AlertSeverity.high;
      case ComplianceViolationType.safetyBriefingOverdue:
        return AlertSeverity.medium;
    }
  }

  ExposureLevel _getExposureLevelFromSeverity(AlertSeverity severity) {
    switch (severity) {
      case AlertSeverity.low:
        return ExposureLevel.low;
      case AlertSeverity.medium:
        return ExposureLevel.medium;
      case AlertSeverity.high:
        return ExposureLevel.high;
      case AlertSeverity.critical:
        return ExposureLevel.critical;
    }
  }
}

// Data models
class SupervisorAlert {
  final String id;
  final String workerId;
  final String workerName;
  final SupervisorAlertType alertType;
  final AlertSeverity severity;
  final String title;
  final String message;
  final Map<String, dynamic> data;
  final bool isResolved;
  final String? resolvedBy;
  final DateTime? resolvedAt;
  final String? resolutionNotes;
  final DateTime createdAt;
  final DateTime updatedAt;

  SupervisorAlert({
    required this.id,
    required this.workerId,
    required this.workerName,
    required this.alertType,
    required this.severity,
    required this.title,
    required this.message,
    required this.data,
    required this.isResolved,
    this.resolvedBy,
    this.resolvedAt,
    this.resolutionNotes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SupervisorAlert.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SupervisorAlert(
      id: doc.id,
      workerId: data['workerId'] ?? '',
      workerName: data['workerName'] ?? '',
      alertType: SupervisorAlertType.fromString(data['alertType'] ?? 'general'),
      severity: AlertSeverity.fromString(data['severity'] ?? 'low'),
      title: data['title'] ?? '',
      message: data['message'] ?? '',
      data: Map<String, dynamic>.from(data['data'] ?? {}),
      isResolved: data['isResolved'] ?? false,
      resolvedBy: data['resolvedBy'],
      resolvedAt: data['resolvedAt'] != null ? (data['resolvedAt'] as Timestamp).toDate() : null,
      resolutionNotes: data['resolutionNotes'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'workerId': workerId,
      'workerName': workerName,
      'alertType': alertType.name,
      'severity': severity.name,
      'title': title,
      'message': message,
      'data': data,
      'isResolved': isResolved,
      'resolvedBy': resolvedBy,
      'resolvedAt': resolvedAt != null ? Timestamp.fromDate(resolvedAt!) : null,
      'resolutionNotes': resolutionNotes,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  SupervisorAlert copyWith({
    String? id,
    String? workerId,
    String? workerName,
    SupervisorAlertType? alertType,
    AlertSeverity? severity,
    String? title,
    String? message,
    Map<String, dynamic>? data,
    bool? isResolved,
    String? resolvedBy,
    DateTime? resolvedAt,
    String? resolutionNotes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SupervisorAlert(
      id: id ?? this.id,
      workerId: workerId ?? this.workerId,
      workerName: workerName ?? this.workerName,
      alertType: alertType ?? this.alertType,
      severity: severity ?? this.severity,
      title: title ?? this.title,
      message: message ?? this.message,
      data: data ?? this.data,
      isResolved: isResolved ?? this.isResolved,
      resolvedBy: resolvedBy ?? this.resolvedBy,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      resolutionNotes: resolutionNotes ?? this.resolutionNotes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

enum SupervisorAlertType {
  exposureViolation,
  emergencyStop,
  complianceViolation,
  overdueBriefing,
  maintenanceViolation,
  general;

  static SupervisorAlertType fromString(String value) {
    return SupervisorAlertType.values.firstWhere(
      (type) => type.name == value.toLowerCase(),
      orElse: () => SupervisorAlertType.general,
    );
  }

  String get displayName {
    switch (this) {
      case SupervisorAlertType.exposureViolation:
        return 'Exposure Violation';
      case SupervisorAlertType.emergencyStop:
        return 'Emergency Stop';
      case SupervisorAlertType.complianceViolation:
        return 'Compliance Violation';
      case SupervisorAlertType.overdueBriefing:
        return 'Overdue Briefing';
      case SupervisorAlertType.maintenanceViolation:
        return 'Maintenance Violation';
      case SupervisorAlertType.general:
        return 'General Alert';
    }
  }
}

enum AlertSeverity {
  low,
  medium,
  high,
  critical;

  static AlertSeverity fromString(String value) {
    return AlertSeverity.values.firstWhere(
      (severity) => severity.name == value.toLowerCase(),
      orElse: () => AlertSeverity.low,
    );
  }

  String get displayName {
    switch (this) {
      case AlertSeverity.low:
        return 'Low';
      case AlertSeverity.medium:
        return 'Medium';
      case AlertSeverity.high:
        return 'High';
      case AlertSeverity.critical:
        return 'Critical';
    }
  }
}

enum ComplianceViolationType {
  missedBreak,
  exceededDailyLimit,
  improperToolUse,
  frequentEmergencyStops,
  maintenanceViolation,
  safetyBriefingOverdue;

  static ComplianceViolationType fromString(String value) {
    return ComplianceViolationType.values.firstWhere(
      (type) => type.name == value.toLowerCase(),
      orElse: () => ComplianceViolationType.improperToolUse,
    );
  }

  String get displayName {
    switch (this) {
      case ComplianceViolationType.missedBreak:
        return 'Missed Break';
      case ComplianceViolationType.exceededDailyLimit:
        return 'Exceeded Daily Limit';
      case ComplianceViolationType.improperToolUse:
        return 'Improper Tool Use';
      case ComplianceViolationType.frequentEmergencyStops:
        return 'Frequent Emergency Stops';
      case ComplianceViolationType.maintenanceViolation:
        return 'Maintenance Violation';
      case ComplianceViolationType.safetyBriefingOverdue:
        return 'Safety Briefing Overdue';
    }
  }
}