import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';
import 'package:stacked_services/stacked_services.dart';
import 'package:get_it/get_it.dart';
import 'dart:io';

import '../../models/tool/advanced_tool_models.dart';
import '../../config/firebase_config.dart';

@lazySingleton
class ToolConditionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  SnackbarService get _snackbarService => GetIt.instance<SnackbarService>();

  static const String _collection = 'tool_condition_reports';
  static const String _photoCollection = 'tool_photos';

  // Get all condition reports for a company
  Stream<List<ToolConditionReport>> getCompanyReports(String companyId) {
    return _firestore
        .collection(_collection)
        .where('companyId', isEqualTo: companyId)
        .orderBy('reportDate', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ToolConditionReport.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  // Get condition reports by tool
  Stream<List<ToolConditionReport>> getToolReports(String toolId) {
    return _firestore
        .collection(_collection)
        .where('toolId', isEqualTo: toolId)
        .orderBy('reportDate', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ToolConditionReport.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  // Get reports by condition
  Stream<List<ToolConditionReport>> getReportsByCondition(String companyId, ToolCondition condition) {
    return _firestore
        .collection(_collection)
        .where('companyId', isEqualTo: companyId)
        .where('condition', isEqualTo: condition.name)
        .orderBy('reportDate', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ToolConditionReport.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  // Get reports requiring action
  Stream<List<ToolConditionReport>> getReportsRequiringAction(String companyId) {
    return _firestore
        .collection(_collection)
        .where('companyId', isEqualTo: companyId)
        .where('requiresImmediate', isEqualTo: true)
        .orderBy('reportDate', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ToolConditionReport.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  // Get reports by inspector
  Stream<List<ToolConditionReport>> getInspectorReports(String inspectorId) {
    return _firestore
        .collection(_collection)
        .where('reportedByWorkerId', isEqualTo: inspectorId)
        .orderBy('reportDate', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ToolConditionReport.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  // Get specific condition report
  Future<ToolConditionReport?> getConditionReport(String reportId) async {
    try {
      final doc = await _firestore
          .collection(_collection)
          .doc(reportId)
          .get();

      if (doc.exists && doc.data() != null) {
        return ToolConditionReport.fromFirestore(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      print('Error getting condition report: $e');
      return null;
    }
  }

  // Get latest condition report for a tool
  Future<ToolConditionReport?> getLatestToolReport(String toolId) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('toolId', isEqualTo: toolId)
          .orderBy('reportDate', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return ToolConditionReport.fromFirestore(
          snapshot.docs.first.data(),
          snapshot.docs.first.id,
        );
      }
      return null;
    } catch (e) {
      print('Error getting latest tool report: $e');
      return null;
    }
  }

  // Create condition report
  Future<bool> createConditionReport({
    required String companyId,
    required String toolId,
    required String reportedByWorkerId,
    required String reportedByWorkerName,
    required ToolCondition condition,
    List<String> issues = const [],
    String? description,
    ReportSeverity severity = ReportSeverity.low,
    bool requiresImmediate = false,
    List<String> photos = const [],
    String? actionTaken,
    String? actionTakenBy,
    DateTime? actionTakenDate,
    double? estimatedRepairCost,
  }) async {
    try {
      final report = ToolConditionReport(
        reportId: _generateReportId(),
        toolId: toolId,
        reportedByWorkerId: reportedByWorkerId,
        reportedByWorkerName: reportedByWorkerName,
        reportDate: DateTime.now(),
        condition: condition,
        issues: issues,
        description: description ?? '',
        photos: photos,
        severity: severity,
        requiresImmediate: requiresImmediate,
        actionTaken: actionTaken,
        actionTakenBy: actionTakenBy,
        actionTakenDate: actionTakenDate,
        estimatedRepairCost: estimatedRepairCost,
        metadata: {'companyId': companyId},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isActive: true,
      );

      await _firestore
          .collection(_collection)
          .add(report.toJson());

      // Update tool inventory condition
      await _updateToolInventoryCondition(toolId, condition);

      _snackbarService.showSnackbar(
        message: 'Condition report created successfully!',
      );
      
      print('✅ Condition report created: ${report.reportId}');
      return true;
    } catch (e) {
      print('❌ Error creating condition report: $e');
      _snackbarService.showSnackbar(
        message: 'Failed to create condition report: ${e.toString()}',
      );
      return false;
    }
  }

  // Update condition report
  Future<bool> updateConditionReport(String reportId, ToolConditionReport report) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(reportId)
          .update(report.toJson());

      _snackbarService.showSnackbar(
        message: 'Condition report updated successfully!',
      );
      
      print('✅ Condition report updated: $reportId');
      return true;
    } catch (e) {
      print('❌ Error updating condition report: $e');
      _snackbarService.showSnackbar(
        message: 'Failed to update condition report: ${e.toString()}',
      );
      return false;
    }
  }

  // Mark action as taken
  Future<bool> markActionTaken({
    required String reportId,
    required String actionDescription,
    required String actionTakenBy,
  }) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(reportId)
          .update({
        'actionTaken': actionDescription,
        'actionTakenBy': actionTakenBy,
        'actionTakenDate': Timestamp.fromDate(DateTime.now()),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      _snackbarService.showSnackbar(
        message: 'Action marked as completed!',
      );
      
      print('✅ Action marked as taken for report: $reportId');
      return true;
    } catch (e) {
      print('❌ Error marking action as taken: $e');
      _snackbarService.showSnackbar(
        message: 'Failed to mark action as taken: ${e.toString()}',
      );
      return false;
    }
  }

  // Schedule follow-up inspection
  Future<bool> scheduleFollowUp(String reportId, DateTime followUpDate) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(reportId)
          .update({
        'followUpDate': Timestamp.fromDate(followUpDate),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      _snackbarService.showSnackbar(
        message: 'Follow-up inspection scheduled!',
      );
      
      print('✅ Follow-up scheduled for report: $reportId');
      return true;
    } catch (e) {
      print('❌ Error scheduling follow-up: $e');
      _snackbarService.showSnackbar(
        message: 'Failed to schedule follow-up: ${e.toString()}',
      );
      return false;
    }
  }

  // Upload photo documentation
  Future<String?> uploadPhoto({
    required File photoFile,
    required String toolId,
    required String reportId,
    String? description,
  }) async {
    try {
      // In a real implementation, this would upload to Firebase Storage
      // For now, we'll simulate with a placeholder URL
      final fileName = 'tool_${toolId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final photoUrl = 'https://storage.firebase.com/tools/photos/$fileName';

      // Store photo metadata
      final photoDoc = {
        'photoId': _generatePhotoId(),
        'toolId': toolId,
        'reportId': reportId,
        'photoUrl': photoUrl,
        'fileName': fileName,
        'description': description ?? '',
        'uploadedAt': Timestamp.fromDate(DateTime.now()),
        'fileSize': await photoFile.length(),
        'isActive': true,
      };

      await _firestore
          .collection(_photoCollection)
          .add(photoDoc);

      print('✅ Photo uploaded: $fileName');
      return photoUrl;
    } catch (e) {
      print('❌ Error uploading photo: $e');
      return null;
    }
  }

  // Get photos for a tool
  Future<List<Map<String, dynamic>>> getToolPhotos(String toolId) async {
    try {
      final snapshot = await _firestore
          .collection(_photoCollection)
          .where('toolId', isEqualTo: toolId)
          .where('isActive', isEqualTo: true)
          .orderBy('uploadedAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data(),
              })
          .toList();
    } catch (e) {
      print('❌ Error getting tool photos: $e');
      return [];
    }
  }

  // Get photos for a report
  Future<List<Map<String, dynamic>>> getReportPhotos(String reportId) async {
    try {
      final snapshot = await _firestore
          .collection(_photoCollection)
          .where('reportId', isEqualTo: reportId)
          .where('isActive', isEqualTo: true)
          .orderBy('uploadedAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data(),
              })
          .toList();
    } catch (e) {
      print('❌ Error getting report photos: $e');
      return [];
    }
  }

  // Delete photo
  Future<bool> deletePhoto(String photoId) async {
    try {
      await _firestore
          .collection(_photoCollection)
          .doc(photoId)
          .update({
        'isActive': false,
        'deletedAt': Timestamp.fromDate(DateTime.now()),
      });

      _snackbarService.showSnackbar(
        message: 'Photo deleted successfully!',
      );
      
      print('✅ Photo deleted: $photoId');
      return true;
    } catch (e) {
      print('❌ Error deleting photo: $e');
      _snackbarService.showSnackbar(
        message: 'Failed to delete photo: ${e.toString()}',
      );
      return false;
    }
  }

  // Get condition statistics
  Future<Map<String, dynamic>> getConditionStats(String companyId) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('companyId', isEqualTo: companyId)
          .get();

      final reports = snapshot.docs
          .map((doc) => ToolConditionReport.fromFirestore(doc.data(), doc.id))
          .toList();

      final conditionCounts = <String, int>{};
      final damageTypeCounts = <String, int>{};
      int requiresActionCount = 0;
      int actionTakenCount = 0;

      for (final report in reports) {
        conditionCounts[report.condition.name] = 
            (conditionCounts[report.condition.name] ?? 0) + 1;

        for (final issue in report.issues) {
          damageTypeCounts[issue] = (damageTypeCounts[issue] ?? 0) + 1;
        }

        if (report.requiresImmediate) {
          requiresActionCount++;
          if (report.actionTaken != null) {
            actionTakenCount++;
          }
        }
      }

      // Get trends (last 30 days vs previous 30 days)
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      final sixtyDaysAgo = DateTime.now().subtract(const Duration(days: 60));

      final recentReports = reports.where((r) => r.reportDate.isAfter(thirtyDaysAgo)).length;
      final previousReports = reports.where((r) => 
          r.reportDate.isAfter(sixtyDaysAgo) && r.reportDate.isBefore(thirtyDaysAgo)
      ).length;

      final reportTrend = previousReports > 0 
          ? ((recentReports - previousReports) / previousReports * 100)
          : 0.0;

      return {
        'totalReports': reports.length,
        'conditionBreakdown': conditionCounts,
        'damageTypeBreakdown': damageTypeCounts,
        'requiresActionCount': requiresActionCount,
        'actionTakenCount': actionTakenCount,
        'actionCompletionRate': requiresActionCount > 0 
            ? (actionTakenCount / requiresActionCount * 100) 
            : 0.0,
        'recentReports': recentReports,
        'reportTrend': reportTrend,
      };
    } catch (e) {
      print('❌ Error getting condition stats: $e');
      return {};
    }
  }

  // Search condition reports
  Future<List<ToolConditionReport>> searchReports(String companyId, String query) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('companyId', isEqualTo: companyId)
          .get();

      final reports = snapshot.docs
          .map((doc) => ToolConditionReport.fromFirestore(doc.data(), doc.id))
          .where((report) =>
              report.reportedByWorkerName.toLowerCase().contains(query.toLowerCase()) ||
              report.reportId.toLowerCase().contains(query.toLowerCase()) ||
              report.description.toLowerCase().contains(query.toLowerCase()) ||
              (report.actionTaken?.toLowerCase().contains(query.toLowerCase()) ?? false))
          .toList();

      return reports;
    } catch (e) {
      print('❌ Error searching condition reports: $e');
      return [];
    }
  }

  // Get overdue follow-ups
  Future<List<ToolConditionReport>> getOverdueFollowUps(String companyId) async {
    try {
      final now = DateTime.now();
      final snapshot = await _firestore
          .collection(_collection)
          .where('companyId', isEqualTo: companyId)
          .where('requiresImmediate', isEqualTo: true)
          .get();

      return snapshot.docs
          .map((doc) => ToolConditionReport.fromFirestore(doc.data(), doc.id))
          .toList();
    } catch (e) {
      print('❌ Error getting overdue follow-ups: $e');
      return [];
    }
  }

  // Generate inspection checklist template
  Map<String, dynamic> generateInspectionChecklist() {
    return {
      'visual_inspection': {
        'cracks_visible': false,
        'rust_corrosion': false,
        'wear_tear': false,
        'missing_parts': false,
        'notes': '',
      },
      'functional_test': {
        'powers_on': false,
        'operates_smoothly': false,
        'all_functions_work': false,
        'vibration_normal': false,
        'noise_level_normal': false,
        'notes': '',
      },
      'safety_check': {
        'guards_in_place': false,
        'emergency_stops_work': false,
        'cables_undamaged': false,
        'labels_legible': false,
        'notes': '',
      },
      'calibration': {
        'within_tolerance': false,
        'last_calibrated': '',
        'next_calibration': '',
        'notes': '',
      },
    };
  }

  // Generate report ID
  String _generateReportId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'CR${timestamp.toString().substring(6)}';
  }

  // Generate photo ID
  String _generatePhotoId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'PH${timestamp.toString().substring(6)}';
  }

  // Update tool inventory condition
  Future<bool> _updateToolInventoryCondition(String toolId, ToolCondition condition) async {
    try {
      final inventorySnapshot = await _firestore
          .collection('tool_inventory')
          .where('toolId', isEqualTo: toolId)
          .limit(1)
          .get();

      if (inventorySnapshot.docs.isNotEmpty) {
        await inventorySnapshot.docs.first.reference.update({
          'condition': condition.name,
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        });
      }

      return true;
    } catch (e) {
      print('Error updating tool inventory condition: $e');
      return false;
    }
  }
}