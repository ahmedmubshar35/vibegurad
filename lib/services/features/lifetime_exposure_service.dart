import 'dart:async';
import 'dart:math' as math;
import 'package:injectable/injectable.dart';
import 'package:stacked_services/stacked_services.dart';
import 'package:get_it/get_it.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/health/lifetime_exposure.dart';
import '../../models/timer/timer_session.dart';
import '../../models/health/health_profile.dart';
import '../features/exposure_calculation_service.dart';
import '../features/health_analytics_service.dart';

@lazySingleton
class LifetimeExposureService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ExposureCalculationService _exposureService = GetIt.instance<ExposureCalculationService>();
  final HealthAnalyticsService _healthAnalytics = GetIt.instance<HealthAnalyticsService>();
  final SnackbarService _snackbarService = GetIt.instance<SnackbarService>();

  /// Update lifetime exposure after a timer session
  Future<void> updateLifetimeExposure({
    required String workerId,
    required TimerSession session,
  }) async {
    try {
      // Get existing lifetime exposure or create new
      LifetimeExposure lifetimeExposure = await getLifetimeExposure(workerId) ??
          await _createInitialLifetimeExposure(workerId);

      // Calculate session contribution
      final sessionA8 = _exposureService.calculateSingleToolA8(
        vibrationLevel: session.tool?.vibrationLevel ?? 0.0,
        exposureTimeMinutes: session.totalMinutes,
      );

      final sessionHours = session.totalMinutes / 60.0;
      final sessionPoints = _exposureService.calculateHSEPoints(
        vibrationLevel: session.tool?.vibrationLevel ?? 0.0,
        exposureTimeMinutes: session.totalMinutes,
      );

      // Update cumulative totals
      final updatedExposure = lifetimeExposure.copyWith(
        totalLifetimeA8: lifetimeExposure.totalLifetimeA8 + sessionA8,
        totalLifetimeHours: lifetimeExposure.totalLifetimeHours + sessionHours,
        totalLifetimePoints: lifetimeExposure.totalLifetimePoints + sessionPoints,
        lastUpdated: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Update yearly breakdown
      final sessionYear = session.startTime.year;
      final updatedYearlyBreakdown = Map<int, YearlyExposure>.from(lifetimeExposure.yearlyBreakdown);
      
      if (updatedYearlyBreakdown.containsKey(sessionYear)) {
        final yearlyExposure = updatedYearlyBreakdown[sessionYear]!;
        updatedYearlyBreakdown[sessionYear] = YearlyExposure(
          year: sessionYear,
          totalA8: yearlyExposure.totalA8 + sessionA8,
          totalHours: yearlyExposure.totalHours + sessionHours,
          totalPoints: yearlyExposure.totalPoints + sessionPoints,
          daysWorked: yearlyExposure.daysWorked + (session.startTime.day != yearlyExposure.daysWorked ? 1 : 0),
          averageDailyA8: (yearlyExposure.totalA8 + sessionA8) / 
                         math.max(1, yearlyExposure.daysWorked + 1),
          monthlyBreakdown: _updateMonthlyBreakdown(yearlyExposure.monthlyBreakdown, session, sessionA8),
        );
      } else {
        updatedYearlyBreakdown[sessionYear] = YearlyExposure(
          year: sessionYear,
          totalA8: sessionA8,
          totalHours: sessionHours,
          totalPoints: sessionPoints,
          daysWorked: 1,
          averageDailyA8: sessionA8,
          monthlyBreakdown: {session.startTime.month.toString(): sessionA8},
        );
      }

      // Update tool-specific breakdown
      final updatedToolBreakdown = Map<String, ToolLifetimeExposure>.from(lifetimeExposure.toolExposureBreakdown);
      final toolId = session.tool?.id ?? 'unknown';
      
      if (updatedToolBreakdown.containsKey(toolId)) {
        final toolExposure = updatedToolBreakdown[toolId]!;
        updatedToolBreakdown[toolId] = ToolLifetimeExposure(
          toolId: toolId,
          toolName: session.tool?.name ?? 'Unknown Tool',
          totalA8: toolExposure.totalA8 + sessionA8,
          totalHours: toolExposure.totalHours + sessionHours,
          totalPoints: toolExposure.totalPoints + sessionPoints,
          totalSessions: toolExposure.totalSessions + 1,
          firstUsed: toolExposure.firstUsed,
          lastUsed: session.startTime,
          averageVibrationLevel: ((toolExposure.averageVibrationLevel * toolExposure.totalSessions) + 
                                 (session.tool?.vibrationLevel ?? 0.0)) / (toolExposure.totalSessions + 1),
          maintenanceIssues: toolExposure.maintenanceIssues, // Would be updated based on maintenance status
        );
      } else {
        updatedToolBreakdown[toolId] = ToolLifetimeExposure(
          toolId: toolId,
          toolName: session.tool?.name ?? 'Unknown Tool',
          totalA8: sessionA8,
          totalHours: sessionHours,
          totalPoints: sessionPoints,
          totalSessions: 1,
          firstUsed: session.startTime,
          lastUsed: session.startTime,
          averageVibrationLevel: session.tool?.vibrationLevel ?? 0.0,
          maintenanceIssues: [],
        );
      }

      // Add new risk progression point (weekly or when significant change)
      final updatedRiskHistory = List<ExposureRiskPoint>.from(lifetimeExposure.riskProgressionHistory);
      if (_shouldAddRiskProgressionPoint(lifetimeExposure, updatedExposure)) {
        final healthProfile = await _getHealthProfile(workerId);
        final riskScore = healthProfile != null ? 
            await _healthAnalytics.calculateHealthRiskScore(
              healthProfile: healthProfile,
              lifetimeExposure: updatedExposure,
              recentSymptoms: [], // Would be provided in real implementation
              recentSessions: [session],
            ) : 0.0;

        updatedRiskHistory.insert(0, ExposureRiskPoint(
          recordedAt: DateTime.now(),
          cumulativeA8: updatedExposure.totalLifetimeA8,
          cumulativeHours: updatedExposure.totalLifetimeHours,
          cumulativePoints: updatedExposure.totalLifetimePoints,
          healthRiskScore: riskScore,
          riskLevel: _healthAnalytics.getRiskLevelFromScore(riskScore),
          havsStage: healthProfile?.havsStage.index ?? 0,
          hadSymptoms: healthProfile?.hasHAVSSymptoms ?? false,
          triggerEvent: 'session_update',
        ));
      }

      // Calculate current risk trend and level
      final currentRiskTrend = _calculateCurrentRiskTrend(updatedRiskHistory);
      final currentRiskLevel = updatedRiskHistory.isNotEmpty ? 
          updatedRiskHistory.first.riskLevel : ExposureRiskLevel.low;

      // Calculate projected HAVS onset if applicable
      final projectedOnset = await _calculateProjectedHAVSOnset(updatedExposure, workerId);

      // Create final updated exposure record
      final finalUpdatedExposure = updatedExposure.copyWith(
        yearlyBreakdown: updatedYearlyBreakdown,
        toolExposureBreakdown: updatedToolBreakdown,
        riskProgressionHistory: updatedRiskHistory,
        currentRiskTrend: currentRiskTrend,
        currentRiskLevel: currentRiskLevel,
        projectedHAVSOnset: projectedOnset,
      );

      // Save to Firestore
      await _saveLifetimeExposure(finalUpdatedExposure);

      // Check for risk level changes and alert if necessary
      await _checkForRiskLevelChanges(lifetimeExposure, finalUpdatedExposure, workerId);

    } catch (e) {
      _snackbarService.showSnackbar(
        message: 'Error updating lifetime exposure: $e',
      );
    }
  }

  /// Get lifetime exposure record for worker
  Future<LifetimeExposure?> getLifetimeExposure(String workerId) async {
    try {
      final querySnapshot = await _firestore
          .collection('lifetime_exposures')
          .where('workerId', isEqualTo: workerId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return LifetimeExposure.fromFirestore(
          querySnapshot.docs.first.data(), 
          querySnapshot.docs.first.id,
        );
      }
      return null;
    } catch (e) {
      _snackbarService.showSnackbar(
        message: 'Error retrieving lifetime exposure: $e',
      );
      return null;
    }
  }

  /// Get lifetime exposures for multiple workers (for comparative analysis)
  Future<List<LifetimeExposure>> getLifetimeExposures(List<String> workerIds) async {
    try {
      if (workerIds.isEmpty) return [];

      final querySnapshot = await _firestore
          .collection('lifetime_exposures')
          .where('workerId', whereIn: workerIds)
          .get();

      return querySnapshot.docs
          .map((doc) => LifetimeExposure.fromFirestore(doc.data(), doc.id))
          .toList();
    } catch (e) {
      _snackbarService.showSnackbar(
        message: 'Error retrieving lifetime exposures: $e',
      );
      return [];
    }
  }

  /// Get exposure trend analysis for worker
  Future<ExposureTrendAnalysis> getExposureTrendAnalysis(String workerId, int months) async {
    try {
      final lifetimeExposure = await getLifetimeExposure(workerId);
      if (lifetimeExposure == null) {
        return ExposureTrendAnalysis.empty();
      }

      final relevantHistory = lifetimeExposure.riskProgressionHistory
          .where((point) => point.recordedAt.isAfter(
              DateTime.now().subtract(Duration(days: months * 30))))
          .toList();

      return ExposureTrendAnalysis(
        workerId: workerId,
        analysisStartDate: DateTime.now().subtract(Duration(days: months * 30)),
        analysisEndDate: DateTime.now(),
        dataPoints: relevantHistory,
        overallTrend: lifetimeExposure.getExposureTrend(months),
        averageA8: relevantHistory.isNotEmpty ? 
            relevantHistory.fold<double>(0.0, (sum, point) => sum + point.cumulativeA8) / relevantHistory.length : 0.0,
        peakA8: relevantHistory.isNotEmpty ?
            relevantHistory.map((point) => point.cumulativeA8).reduce(math.max) : 0.0,
        exposureVelocity: lifetimeExposure.exposureVelocity,
        exposureAcceleration: lifetimeExposure.exposureAcceleration,
        riskLevelChanges: _calculateRiskLevelChanges(relevantHistory),
      );
    } catch (e) {
      _snackbarService.showSnackbar(
        message: 'Error analyzing exposure trends: $e',
      );
      return ExposureTrendAnalysis.empty();
    }
  }

  /// Get comparative exposure analysis
  Future<ComparativeExposureAnalysis> getComparativeAnalysis({
    required String workerId,
    required List<String> comparisonWorkerIds,
    int months = 12,
  }) async {
    try {
      final allWorkerIds = [workerId, ...comparisonWorkerIds];
      final exposures = await getLifetimeExposures(allWorkerIds);
      
      final workerExposure = exposures.firstWhere(
        (e) => e.workerId == workerId,
        orElse: () => throw Exception('Worker exposure not found'),
      );

      final comparisonExposures = exposures.where((e) => e.workerId != workerId).toList();

      // Calculate comparative metrics
      final workerA8 = workerExposure.totalLifetimeA8;
      final averageA8 = comparisonExposures.isNotEmpty ?
          comparisonExposures.fold<double>(0.0, (sum, e) => sum + e.totalLifetimeA8) / comparisonExposures.length : 0.0;

      final workerVelocity = workerExposure.exposureVelocity;
      final averageVelocity = comparisonExposures.isNotEmpty ?
          comparisonExposures.fold<double>(0.0, (sum, e) => sum + e.exposureVelocity) / comparisonExposures.length : 0.0;

      // Calculate percentile ranking
      final allA8Values = exposures.map((e) => e.totalLifetimeA8).toList()..sort();
      final percentileRank = _calculatePercentileRank(workerA8, allA8Values);

      return ComparativeExposureAnalysis(
        workerId: workerId,
        workerTotalA8: workerA8,
        comparisonGroupAverageA8: averageA8,
        workerPercentileRank: percentileRank,
        workerExposureVelocity: workerVelocity,
        comparisonGroupAverageVelocity: averageVelocity,
        comparisonGroupSize: comparisonExposures.length,
        workerRiskLevel: workerExposure.currentRiskLevel,
        comparisonDate: DateTime.now(),
      );
    } catch (e) {
      _snackbarService.showSnackbar(
        message: 'Error performing comparative analysis: $e',
      );
      rethrow;
    }
  }

  /// Recalculate lifetime exposure from scratch (for data corrections)
  Future<void> recalculateLifetimeExposure(String workerId) async {
    try {
      // This would query all historical sessions and rebuild the lifetime exposure
      // For now, we'll create a placeholder implementation
      
      _snackbarService.showSnackbar(
        message: 'Lifetime exposure recalculation started for worker $workerId',
      );

      // In a real implementation, this would:
      // 1. Query all TimerSession records for the worker
      // 2. Clear existing lifetime exposure
      // 3. Process each session chronologically
      // 4. Rebuild the complete exposure history
      
    } catch (e) {
      _snackbarService.showSnackbar(
        message: 'Error recalculating lifetime exposure: $e',
      );
    }
  }

  // Private helper methods

  Future<LifetimeExposure> _createInitialLifetimeExposure(String workerId) async {
    return LifetimeExposure(
      workerId: workerId,
      totalLifetimeA8: 0.0,
      totalLifetimeHours: 0.0,
      totalLifetimePoints: 0.0,
      yearlyBreakdown: {},
      toolExposureBreakdown: {},
      riskProgressionHistory: [],
      lastUpdated: DateTime.now(),
      currentRiskTrend: 0.0,
      currentRiskLevel: ExposureRiskLevel.low,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  Map<String, double> _updateMonthlyBreakdown(
    Map<String, double> existing, 
    TimerSession session, 
    double sessionA8,
  ) {
    final updated = Map<String, double>.from(existing);
    final monthKey = session.startTime.month.toString();
    updated[monthKey] = (updated[monthKey] ?? 0.0) + sessionA8;
    return updated;
  }

  bool _shouldAddRiskProgressionPoint(
    LifetimeExposure existing, 
    LifetimeExposure updated,
  ) {
    if (existing.riskProgressionHistory.isEmpty) return true;
    
    final lastPoint = existing.riskProgressionHistory.first;
    final daysSinceLastPoint = DateTime.now().difference(lastPoint.recordedAt).inDays;
    
    // Add point weekly, or if significant change in A(8)
    return daysSinceLastPoint >= 7 || 
           (updated.totalLifetimeA8 - lastPoint.cumulativeA8).abs() >= 0.5;
  }

  Future<HealthProfile?> _getHealthProfile(String workerId) async {
    try {
      final querySnapshot = await _firestore
          .collection('health_profiles')
          .where('workerId', isEqualTo: workerId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return HealthProfile.fromFirestore(
          querySnapshot.docs.first.data(), 
          querySnapshot.docs.first.id,
        );
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  double _calculateCurrentRiskTrend(List<ExposureRiskPoint> history) {
    if (history.length < 2) return 0.0;
    
    final recent = history.take(math.min(6, history.length)).toList();
    if (recent.length < 2) return 0.0;
    
    final newest = recent.first;
    final oldest = recent.last;
    final monthsDiff = newest.recordedAt.difference(oldest.recordedAt).inDays / 30.0;
    
    if (monthsDiff <= 0) return 0.0;
    return (newest.healthRiskScore - oldest.healthRiskScore) / monthsDiff;
  }

  Future<DateTime?> _calculateProjectedHAVSOnset(LifetimeExposure exposure, String workerId) async {
    if (exposure.exposureVelocity <= 0) return null;
    
    // This would use more sophisticated epidemiological models
    // Simplified calculation based on current trajectory
    const criticalA8Threshold = 15.0; // Rough threshold for HAVS onset
    
    if (exposure.totalLifetimeA8 >= criticalA8Threshold) return DateTime.now();
    
    final a8Remaining = criticalA8Threshold - exposure.totalLifetimeA8;
    final monthsToOnset = a8Remaining / exposure.exposureVelocity;
    
    if (monthsToOnset > 0 && monthsToOnset < 600) { // Within 50 years
      return DateTime.now().add(Duration(days: (monthsToOnset * 30).round()));
    }
    
    return null;
  }

  Future<void> _saveLifetimeExposure(LifetimeExposure exposure) async {
    if (exposure.id?.isNotEmpty == true) {
      await _firestore
          .collection('lifetime_exposures')
          .doc(exposure.id)
          .update(exposure.toFirestore());
    } else {
      await _firestore
          .collection('lifetime_exposures')
          .add(exposure.toFirestore());
    }
  }

  Future<void> _checkForRiskLevelChanges(
    LifetimeExposure oldExposure,
    LifetimeExposure newExposure,
    String workerId,
  ) async {
    if (oldExposure.currentRiskLevel != newExposure.currentRiskLevel) {
      // Risk level changed - could trigger notifications
      // This would integrate with notification service
    }
  }

  List<RiskLevelChange> _calculateRiskLevelChanges(List<ExposureRiskPoint> history) {
    final changes = <RiskLevelChange>[];
    
    for (int i = 0; i < history.length - 1; i++) {
      final current = history[i];
      final previous = history[i + 1];
      
      if (current.riskLevel != previous.riskLevel) {
        changes.add(RiskLevelChange(
          date: current.recordedAt,
          fromLevel: previous.riskLevel,
          toLevel: current.riskLevel,
          triggerA8: current.cumulativeA8,
        ));
      }
    }
    
    return changes;
  }

  double _calculatePercentileRank(double value, List<double> sortedValues) {
    if (sortedValues.isEmpty) return 50.0;
    
    int rank = sortedValues.where((v) => v < value).length;
    return (rank / sortedValues.length) * 100.0;
  }
}

/// Exposure trend analysis result
class ExposureTrendAnalysis {
  final String workerId;
  final DateTime analysisStartDate;
  final DateTime analysisEndDate;
  final List<ExposureRiskPoint> dataPoints;
  final ExposureTrend overallTrend;
  final double averageA8;
  final double peakA8;
  final double exposureVelocity;
  final double exposureAcceleration;
  final List<RiskLevelChange> riskLevelChanges;

  ExposureTrendAnalysis({
    required this.workerId,
    required this.analysisStartDate,
    required this.analysisEndDate,
    required this.dataPoints,
    required this.overallTrend,
    required this.averageA8,
    required this.peakA8,
    required this.exposureVelocity,
    required this.exposureAcceleration,
    required this.riskLevelChanges,
  });

  factory ExposureTrendAnalysis.empty() {
    final now = DateTime.now();
    return ExposureTrendAnalysis(
      workerId: '',
      analysisStartDate: now,
      analysisEndDate: now,
      dataPoints: [],
      overallTrend: ExposureTrend.stable,
      averageA8: 0.0,
      peakA8: 0.0,
      exposureVelocity: 0.0,
      exposureAcceleration: 0.0,
      riskLevelChanges: [],
    );
  }
}

/// Comparative exposure analysis
class ComparativeExposureAnalysis {
  final String workerId;
  final double workerTotalA8;
  final double comparisonGroupAverageA8;
  final double workerPercentileRank;
  final double workerExposureVelocity;
  final double comparisonGroupAverageVelocity;
  final int comparisonGroupSize;
  final ExposureRiskLevel workerRiskLevel;
  final DateTime comparisonDate;

  ComparativeExposureAnalysis({
    required this.workerId,
    required this.workerTotalA8,
    required this.comparisonGroupAverageA8,
    required this.workerPercentileRank,
    required this.workerExposureVelocity,
    required this.comparisonGroupAverageVelocity,
    required this.comparisonGroupSize,
    required this.workerRiskLevel,
    required this.comparisonDate,
  });

  bool get workerAboveAverage => workerTotalA8 > comparisonGroupAverageA8;
  bool get workerHighRisk => workerPercentileRank > 75.0;
  String get riskComparison {
    if (workerPercentileRank >= 90) return 'Top 10% highest exposure';
    if (workerPercentileRank >= 75) return 'Top 25% highest exposure';
    if (workerPercentileRank >= 50) return 'Above average exposure';
    if (workerPercentileRank >= 25) return 'Below average exposure';
    return 'Bottom 25% lowest exposure';
  }
}

/// Risk level change record
class RiskLevelChange {
  final DateTime date;
  final ExposureRiskLevel fromLevel;
  final ExposureRiskLevel toLevel;
  final double triggerA8;

  RiskLevelChange({
    required this.date,
    required this.fromLevel,
    required this.toLevel,
    required this.triggerA8,
  });

  bool get isIncrease => toLevel.numericValue > fromLevel.numericValue;
  bool get isDecrease => toLevel.numericValue < fromLevel.numericValue;
}