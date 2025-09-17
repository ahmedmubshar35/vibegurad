import 'dart:async';
import 'package:injectable/injectable.dart';
import 'package:stacked_services/stacked_services.dart';
import 'package:get_it/get_it.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/tool/tool.dart';
import '../../enums/exposure_level.dart';
import '../features/notification_service.dart';

@lazySingleton
class ToolMaintenanceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = GetIt.instance<NotificationService>();
  final SnackbarService _snackbarService = GetIt.instance<SnackbarService>();

  // Maintenance schedule constants
  static const int defaultMaintenanceIntervalHours = 100; // 100 hours of usage
  static const int criticalMaintenanceThresholdHours = 120; // Critical threshold
  static const int warningThresholdPercentage = 80; // 80% of maintenance interval

  ToolMaintenanceService();

  // Create maintenance record for a tool
  Future<void> createMaintenanceRecord({
    required String toolId,
    required int maintenanceIntervalHours,
    DateTime? lastMaintenanceDate,
    String? notes,
  }) async {
    try {
      final record = ToolMaintenanceRecord(
        id: '',
        toolId: toolId,
        maintenanceIntervalHours: maintenanceIntervalHours,
        lastMaintenanceDate: lastMaintenanceDate ?? DateTime.now(),
        totalUsageHours: 0,
        isOverdue: false,
        notes: notes ?? '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _firestore
          .collection('tool_maintenance')
          .add(record.toFirestore());
    } catch (e) {
      _snackbarService.showSnackbar(
        message: 'Failed to create maintenance record: $e',
      );
    }
  }

  // Update maintenance record after tool usage
  Future<void> updateToolUsage({
    required String toolId,
    required int additionalMinutes,
  }) async {
    try {
      final query = await _firestore
          .collection('tool_maintenance')
          .where('toolId', isEqualTo: toolId)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        final doc = query.docs.first;
        final record = ToolMaintenanceRecord.fromFirestore(doc);
        
        final updatedRecord = record.copyWith(
          totalUsageHours: record.totalUsageHours + (additionalMinutes / 60.0),
          updatedAt: DateTime.now(),
        );

        await doc.reference.update(updatedRecord.toFirestore());

        // Check if maintenance is due
        await _checkMaintenanceDue(updatedRecord);
      } else {
        // Create new maintenance record if none exists
        await createMaintenanceRecord(
          toolId: toolId,
          maintenanceIntervalHours: defaultMaintenanceIntervalHours,
        );
      }
    } catch (e) {
      _snackbarService.showSnackbar(
        message: 'Failed to update tool usage: $e',
      );
    }
  }

  // Check if maintenance is due and send notifications
  Future<void> _checkMaintenanceDue(ToolMaintenanceRecord record) async {
    final usagePercentage = (record.totalUsageHours / record.maintenanceIntervalHours) * 100;
    
    if (usagePercentage >= 100) {
      // Maintenance overdue
      await _sendMaintenanceDueNotification(record, MaintenanceUrgency.overdue);
      await _markMaintenanceOverdue(record.id);
    } else if (usagePercentage >= 95) {
      // Critical - maintenance due very soon
      await _sendMaintenanceDueNotification(record, MaintenanceUrgency.critical);
    } else if (usagePercentage >= warningThresholdPercentage) {
      // Warning - maintenance approaching
      await _sendMaintenanceDueNotification(record, MaintenanceUrgency.warning);
    }
  }

  // Send maintenance due notification
  Future<void> _sendMaintenanceDueNotification(
    ToolMaintenanceRecord record,
    MaintenanceUrgency urgency,
  ) async {
    try {
      final tool = await _getToolById(record.toolId);
      if (tool == null) return;

      final title = _getMaintenanceNotificationTitle(urgency);
      final body = _getMaintenanceNotificationBody(tool, record, urgency);

      await _notificationService.showSafetyWarning(
        title: title,
        body: body,
        level: _getExposureLevelFromUrgency(urgency),
        payload: {
          'type': 'maintenance_due',
          'toolId': record.toolId,
          'urgency': urgency.name,
        },
      );
    } catch (e) {
      _snackbarService.showSnackbar(
        message: 'Failed to send maintenance notification: $e',
      );
    }
  }

  // Get tool by ID
  Future<Tool?> _getToolById(String toolId) async {
    try {
      final doc = await _firestore.collection('tools').doc(toolId).get();
      if (doc.exists) {
        return Tool.fromFirestore(doc.data()!, doc.id);
      }
    } catch (e) {
      // Silent fail
    }
    return null;
  }

  // Mark maintenance as overdue
  Future<void> _markMaintenanceOverdue(String recordId) async {
    try {
      await _firestore
          .collection('tool_maintenance')
          .doc(recordId)
          .update({
        'isOverdue': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Silent fail
    }
  }

  // Record maintenance completion
  Future<void> recordMaintenanceCompleted({
    required String toolId,
    required String performedBy,
    required List<String> tasksCompleted,
    String? notes,
    List<String>? partsReplaced,
  }) async {
    try {
      // Get current maintenance record
      final query = await _firestore
          .collection('tool_maintenance')
          .where('toolId', isEqualTo: toolId)
          .limit(1)
          .get();

      if (query.docs.isEmpty) return;

      final doc = query.docs.first;
      final record = ToolMaintenanceRecord.fromFirestore(doc);

      // Create maintenance log entry
      final logEntry = MaintenanceLogEntry(
        id: '',
        toolId: toolId,
        performedBy: performedBy,
        performedAt: DateTime.now(),
        tasksCompleted: tasksCompleted,
        partsReplaced: partsReplaced ?? [],
        usageHoursAtMaintenance: record.totalUsageHours,
        notes: notes ?? '',
        cost: 0.0, // Could be added later
      );

      // Add to maintenance log
      await _firestore
          .collection('maintenance_log')
          .add(logEntry.toFirestore());

      // Reset maintenance record
      final updatedRecord = record.copyWith(
        lastMaintenanceDate: DateTime.now(),
        totalUsageHours: 0.0, // Reset usage counter
        isOverdue: false,
        notes: 'Last maintenance: ${DateTime.now().toString()}',
        updatedAt: DateTime.now(),
      );

      await doc.reference.update(updatedRecord.toFirestore());

      _snackbarService.showSnackbar(
        message: 'Maintenance record updated successfully',
      );
    } catch (e) {
      _snackbarService.showSnackbar(
        message: 'Failed to record maintenance completion: $e',
      );
    }
  }

  // Get maintenance records for all tools
  Stream<List<ToolMaintenanceRecord>> getMaintenanceRecords({String? companyId}) {
    Query query = _firestore.collection('tool_maintenance');
    
    if (companyId != null) {
      // In a full implementation, you'd filter by company
      // query = query.where('companyId', isEqualTo: companyId);
    }

    return query.snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => ToolMaintenanceRecord.fromFirestore(doc)).toList());
  }

  // Get overdue maintenance records
  Stream<List<ToolMaintenanceRecord>> getOverdueMaintenanceRecords({String? companyId}) {
    Query query = _firestore
        .collection('tool_maintenance')
        .where('isOverdue', isEqualTo: true);
    
    if (companyId != null) {
      // query = query.where('companyId', isEqualTo: companyId);
    }

    return query.snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => ToolMaintenanceRecord.fromFirestore(doc)).toList());
  }

  // Get maintenance log for a tool
  Stream<List<MaintenanceLogEntry>> getMaintenanceLog({required String toolId}) {
    return _firestore
        .collection('maintenance_log')
        .where('toolId', isEqualTo: toolId)
        .orderBy('performedAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => MaintenanceLogEntry.fromFirestore(doc)).toList());
  }

  // Schedule maintenance reminder
  Future<void> scheduleMaintenanceReminder({
    required String toolId,
    required DateTime reminderDate,
    String? notes,
  }) async {
    try {
      // In a full implementation, this would schedule a background job
      // For now, we'll create a reminder record
      final reminder = MaintenanceReminder(
        id: '',
        toolId: toolId,
        reminderDate: reminderDate,
        notes: notes ?? '',
        isCompleted: false,
        createdAt: DateTime.now(),
      );

      await _firestore
          .collection('maintenance_reminders')
          .add(reminder.toFirestore());
    } catch (e) {
      _snackbarService.showSnackbar(
        message: 'Failed to schedule maintenance reminder: $e',
      );
    }
  }

  // Helper methods
  String _getMaintenanceNotificationTitle(MaintenanceUrgency urgency) {
    switch (urgency) {
      case MaintenanceUrgency.warning:
        return '⚠️ Maintenance Due Soon';
      case MaintenanceUrgency.critical:
        return '🔴 Maintenance Critical';
      case MaintenanceUrgency.overdue:
        return '🚨 Maintenance OVERDUE';
    }
  }

  String _getMaintenanceNotificationBody(
    Tool tool,
    ToolMaintenanceRecord record,
    MaintenanceUrgency urgency,
  ) {
    final usagePercentage = ((record.totalUsageHours / record.maintenanceIntervalHours) * 100).round();
    
    switch (urgency) {
      case MaintenanceUrgency.warning:
        return '${tool.name} is at $usagePercentage% of maintenance interval (${record.totalUsageHours.toStringAsFixed(1)}/${record.maintenanceIntervalHours}h)';
      case MaintenanceUrgency.critical:
        return '${tool.name} requires maintenance soon: $usagePercentage% of interval reached';
      case MaintenanceUrgency.overdue:
        return '${tool.name} maintenance is OVERDUE! ${record.totalUsageHours.toStringAsFixed(1)}h used (limit: ${record.maintenanceIntervalHours}h)';
    }
  }

  ExposureLevel _getExposureLevelFromUrgency(MaintenanceUrgency urgency) {
    switch (urgency) {
      case MaintenanceUrgency.warning:
        return ExposureLevel.medium;
      case MaintenanceUrgency.critical:
        return ExposureLevel.high;
      case MaintenanceUrgency.overdue:
        return ExposureLevel.critical;
    }
  }
}

// Data models
class ToolMaintenanceRecord {
  final String id;
  final String toolId;
  final int maintenanceIntervalHours;
  final DateTime lastMaintenanceDate;
  final double totalUsageHours;
  final bool isOverdue;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  ToolMaintenanceRecord({
    required this.id,
    required this.toolId,
    required this.maintenanceIntervalHours,
    required this.lastMaintenanceDate,
    required this.totalUsageHours,
    required this.isOverdue,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ToolMaintenanceRecord.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ToolMaintenanceRecord(
      id: doc.id,
      toolId: data['toolId'] ?? '',
      maintenanceIntervalHours: data['maintenanceIntervalHours'] ?? 100,
      lastMaintenanceDate: (data['lastMaintenanceDate'] as Timestamp).toDate(),
      totalUsageHours: (data['totalUsageHours'] ?? 0.0).toDouble(),
      isOverdue: data['isOverdue'] ?? false,
      notes: data['notes'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'toolId': toolId,
      'maintenanceIntervalHours': maintenanceIntervalHours,
      'lastMaintenanceDate': Timestamp.fromDate(lastMaintenanceDate),
      'totalUsageHours': totalUsageHours,
      'isOverdue': isOverdue,
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  ToolMaintenanceRecord copyWith({
    String? id,
    String? toolId,
    int? maintenanceIntervalHours,
    DateTime? lastMaintenanceDate,
    double? totalUsageHours,
    bool? isOverdue,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ToolMaintenanceRecord(
      id: id ?? this.id,
      toolId: toolId ?? this.toolId,
      maintenanceIntervalHours: maintenanceIntervalHours ?? this.maintenanceIntervalHours,
      lastMaintenanceDate: lastMaintenanceDate ?? this.lastMaintenanceDate,
      totalUsageHours: totalUsageHours ?? this.totalUsageHours,
      isOverdue: isOverdue ?? this.isOverdue,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class MaintenanceLogEntry {
  final String id;
  final String toolId;
  final String performedBy;
  final DateTime performedAt;
  final List<String> tasksCompleted;
  final List<String> partsReplaced;
  final double usageHoursAtMaintenance;
  final String notes;
  final double cost;

  MaintenanceLogEntry({
    required this.id,
    required this.toolId,
    required this.performedBy,
    required this.performedAt,
    required this.tasksCompleted,
    required this.partsReplaced,
    required this.usageHoursAtMaintenance,
    required this.notes,
    required this.cost,
  });

  factory MaintenanceLogEntry.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MaintenanceLogEntry(
      id: doc.id,
      toolId: data['toolId'] ?? '',
      performedBy: data['performedBy'] ?? '',
      performedAt: (data['performedAt'] as Timestamp).toDate(),
      tasksCompleted: List<String>.from(data['tasksCompleted'] ?? []),
      partsReplaced: List<String>.from(data['partsReplaced'] ?? []),
      usageHoursAtMaintenance: (data['usageHoursAtMaintenance'] ?? 0.0).toDouble(),
      notes: data['notes'] ?? '',
      cost: (data['cost'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'toolId': toolId,
      'performedBy': performedBy,
      'performedAt': Timestamp.fromDate(performedAt),
      'tasksCompleted': tasksCompleted,
      'partsReplaced': partsReplaced,
      'usageHoursAtMaintenance': usageHoursAtMaintenance,
      'notes': notes,
      'cost': cost,
    };
  }
}

class MaintenanceReminder {
  final String id;
  final String toolId;
  final DateTime reminderDate;
  final String notes;
  final bool isCompleted;
  final DateTime createdAt;

  MaintenanceReminder({
    required this.id,
    required this.toolId,
    required this.reminderDate,
    required this.notes,
    required this.isCompleted,
    required this.createdAt,
  });

  factory MaintenanceReminder.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MaintenanceReminder(
      id: doc.id,
      toolId: data['toolId'] ?? '',
      reminderDate: (data['reminderDate'] as Timestamp).toDate(),
      notes: data['notes'] ?? '',
      isCompleted: data['isCompleted'] ?? false,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'toolId': toolId,
      'reminderDate': Timestamp.fromDate(reminderDate),
      'notes': notes,
      'isCompleted': isCompleted,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

enum MaintenanceUrgency {
  warning,
  critical,
  overdue,
}