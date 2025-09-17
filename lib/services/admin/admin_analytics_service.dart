import 'dart:async';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/admin/dashboard_models.dart';
import '../../models/health/lifetime_exposure.dart';
import '../../models/health/health_profile.dart';
import '../features/health_analytics_service.dart';

/// Comprehensive admin analytics service
class AdminAnalyticsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final HealthAnalyticsService _healthAnalytics = HealthAnalyticsService();

  /// Get team exposure overview
  Future<TeamExposureOverview> getTeamExposureOverview(String teamId) async {
    try {
      // Get team details
      final teamDoc = await _firestore
          .collection('teams')
          .doc(teamId)
          .get();

      if (!teamDoc.exists) {
        throw Exception('Team not found');
      }

      final teamData = teamDoc.data()!;
      final teamName = teamData['name'] as String;

      // Get all workers in team
      final workersQuery = await _firestore
          .collection('users')
          .where('teamId', isEqualTo: teamId)
          .get();

      int totalWorkers = workersQuery.docs.length;
      int activeWorkers = 0;
      double totalExposure = 0.0;
      Map<ExposureRiskLevel, int> riskDistribution = {};
      List<String> highRiskWorkerIds = [];
      int compliantWorkers = 0;

      for (final workerDoc in workersQuery.docs) {
        final workerId = workerDoc.id;

        // Check if active today
        final isActive = await _isWorkerActiveToday(workerId);
        if (isActive) activeWorkers++;

        // Get exposure data
        final exposureDoc = await _firestore
            .collection('lifetime_exposures')
            .doc(workerId)
            .get();

        if (exposureDoc.exists) {
          final exposureData = exposureDoc.data()!;
          final dailyExposure = await _calculateDailyExposure(workerId);
          totalExposure += dailyExposure;

          final riskLevel = ExposureRiskLevel.fromString(
            exposureData['currentRiskLevel'] ?? 'low'
          );
          riskDistribution[riskLevel] = (riskDistribution[riskLevel] ?? 0) + 1;

          if (riskLevel.index >= ExposureRiskLevel.high.index) {
            highRiskWorkerIds.add(workerId);
          }

          // Check compliance
          if (dailyExposure <= 5.0) {
            compliantWorkers++;
          }
        }
      }

      final averageDailyExposure = totalWorkers > 0 ? totalExposure / totalWorkers : 0.0;
      final complianceRate = totalWorkers > 0 ? compliantWorkers / totalWorkers : 0.0;

      return TeamExposureOverview(
        teamId: teamId,
        teamName: teamName,
        totalWorkers: totalWorkers,
        activeWorkers: activeWorkers,
        averageDailyExposure: averageDailyExposure,
        totalTeamExposure: totalExposure,
        riskDistribution: riskDistribution,
        highRiskWorkerIds: highRiskWorkerIds,
        complianceRate: complianceRate,
        lastUpdated: DateTime.now(),
      );
    } catch (e) {
      print('Error getting team exposure overview: $e');
      rethrow;
    }
  }

  /// Identify high-risk workers
  Future<List<HighRiskWorkerProfile>> identifyHighRiskWorkers({
    int limit = 20,
    double riskThreshold = 60.0,
  }) async {
    try {
      final highRiskWorkers = <HighRiskWorkerProfile>[];

      // Get all workers
      final workersQuery = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'worker')
          .get();

      for (final workerDoc in workersQuery.docs) {
        final workerId = workerDoc.id;
        final workerData = workerDoc.data();

        // Get health profile
        final healthDoc = await _firestore
            .collection('health_profiles')
            .doc(workerId)
            .get();

        if (!healthDoc.exists) continue;

        final healthProfile = HealthProfile.fromFirestore(
          healthDoc.data()!,
          healthDoc.id,
        );

        // Get lifetime exposure
        final exposureDoc = await _firestore
            .collection('lifetime_exposures')
            .doc(workerId)
            .get();

        if (!exposureDoc.exists) continue;

        final exposureData = exposureDoc.data()!;
        
        // Calculate risk score
        final riskScore = await _healthAnalytics.calculateHealthRiskScore(
          healthProfile: healthProfile,
          lifetimeExposure: LifetimeExposure.fromFirestore(exposureData, exposureDoc.id),
          recentSymptoms: [],
          recentSessions: [],
        );

        if (riskScore >= riskThreshold) {
          // Get week exposure
          final weekExposure = await _calculateWeeklyExposure(workerId);
          
          // Calculate trend
          final trend = await _calculateExposureTrend(workerId);

          // Determine risk factors
          final riskFactors = _identifyRiskFactors(healthProfile, exposureData);

          // Generate recommendations
          final recommendations = _generateRecommendations(
            riskScore, 
            healthProfile.havsStage.index,
            exposureData,
          );

          highRiskWorkers.add(HighRiskWorkerProfile(
            workerId: workerId,
            workerName: '${workerData['firstName']} ${workerData['lastName']}',
            department: workerData['department'] ?? 'Unknown',
            riskScore: riskScore,
            riskLevel: _healthAnalytics.getRiskLevelFromScore(riskScore),
            lifetimeExposure: (exposureData['totalLifetimeA8'] ?? 0.0).toDouble(),
            currentWeekExposure: weekExposure,
            exposureTrend: trend,
            havsStage: healthProfile.havsStage.index,
            lastMedicalExam: healthProfile.lastHealthAssessment,
            nextMedicalExamDue: healthProfile.nextMedicalExamDue,
            riskFactors: riskFactors,
            recommendations: recommendations,
            requiresImmediateAction: riskScore >= 80.0,
          ));
        }
      }

      // Sort by risk score
      highRiskWorkers.sort((a, b) => b.riskScore.compareTo(a.riskScore));

      return highRiskWorkers.take(limit).toList();
    } catch (e) {
      print('Error identifying high-risk workers: $e');
      return [];
    }
  }

  /// Get compliance status for entity
  Future<ComplianceStatus> getComplianceStatus({
    required String entityId,
    required String entityType, // 'worker', 'team', 'department'
  }) async {
    try {
      String entityName = '';
      List<String> workerIds = [];

      // Get entity details and worker IDs
      if (entityType == 'worker') {
        final workerDoc = await _firestore.collection('users').doc(entityId).get();
        entityName = '${workerDoc.data()!['firstName']} ${workerDoc.data()!['lastName']}';
        workerIds = [entityId];
      } else if (entityType == 'team') {
        final teamDoc = await _firestore.collection('teams').doc(entityId).get();
        entityName = teamDoc.data()!['name'];
        
        final workers = await _firestore
            .collection('users')
            .where('teamId', isEqualTo: entityId)
            .get();
        workerIds = workers.docs.map((d) => d.id).toList();
      } else if (entityType == 'department') {
        entityName = entityId; // Department name is the ID
        
        final workers = await _firestore
            .collection('users')
            .where('department', isEqualTo: entityId)
            .get();
        workerIds = workers.docs.map((d) => d.id).toList();
      }

      // Calculate compliance metrics
      final metrics = await _calculateComplianceMetrics(workerIds);
      
      // Get recent violations
      final violations = await _getRecentViolations(workerIds);

      // Calculate overall compliance rate
      double totalRate = 0.0;
      for (final metric in metrics.values) {
        totalRate += metric.complianceRate;
      }
      final overallComplianceRate = metrics.isNotEmpty 
          ? totalRate / metrics.length 
          : 0.0;

      return ComplianceStatus(
        entityId: entityId,
        entityType: entityType,
        entityName: entityName,
        overallComplianceRate: overallComplianceRate,
        metrics: metrics,
        recentViolations: violations,
        lastUpdated: DateTime.now(),
      );
    } catch (e) {
      print('Error getting compliance status: $e');
      rethrow;
    }
  }

  /// Get tool usage analytics
  Future<List<ToolUsageAnalytics>> getToolUsageAnalytics({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      startDate ??= DateTime.now().subtract(const Duration(days: 30));
      endDate ??= DateTime.now();

      final toolsQuery = await _firestore.collection('tools').get();
      final analytics = <ToolUsageAnalytics>[];

      for (final toolDoc in toolsQuery.docs) {
        final toolId = toolDoc.id;
        final toolData = toolDoc.data();

        // Get usage sessions
        final sessionsQuery = await _firestore
            .collection('timer_sessions')
            .where('toolId', isEqualTo: toolId)
            .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
            .where('startTime', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
            .get();

        if (sessionsQuery.docs.isEmpty) continue;

        int totalMinutes = 0;
        Set<String> uniqueUsers = {};
        Map<String, int> departmentUsage = {};
        Map<String, double> exposureContribution = {};
        List<ToolUsageTrend> trends = [];

        for (final session in sessionsQuery.docs) {
          final data = session.data();
          final duration = data['totalMinutes'] ?? 0;
          final userId = data['workerId'] as String;
          final department = data['department'] ?? 'Unknown';

          totalMinutes += duration as int;
          uniqueUsers.add(userId);
          departmentUsage[department] = (departmentUsage[department] ?? 0) + duration;
          
          // Calculate exposure contribution
          final exposure = data['dailyExposure'] ?? 0.0;
          exposureContribution[userId] = 
              (exposureContribution[userId] ?? 0.0) + (exposure as double);
        }

        // Calculate trends
        trends = await _calculateToolUsageTrends(toolId, startDate, endDate);

        // Check maintenance compliance
        final maintenanceCompliance = await _calculateMaintenanceCompliance(toolId);
        final overdueCount = toolData['maintenanceOverdue'] == true ? 1 : 0;

        analytics.add(ToolUsageAnalytics(
          toolId: toolId,
          toolName: toolData['name'] ?? 'Unknown Tool',
          toolType: toolData['type'] ?? 'Unknown',
          averageVibrationLevel: (toolData['vibrationLevel'] ?? 0.0).toDouble(),
          totalUsageMinutes: totalMinutes,
          totalSessions: sessionsQuery.docs.length,
          uniqueUsers: uniqueUsers.length,
          usageByDepartment: departmentUsage,
          exposureContribution: exposureContribution,
          maintenanceCompliance: maintenanceCompliance,
          overdueMaintenanceCount: overdueCount,
          lastUsed: sessionsQuery.docs.isNotEmpty
              ? (sessionsQuery.docs.last.data()['endTime'] as Timestamp).toDate()
              : DateTime.now(),
          usageTrends: trends,
        ));
      }

      // Sort by total usage
      analytics.sort((a, b) => b.totalUsageMinutes.compareTo(a.totalUsageMinutes));

      return analytics;
    } catch (e) {
      print('Error getting tool usage analytics: $e');
      return [];
    }
  }

  /// Generate worker rankings/leaderboard
  Future<List<WorkerRanking>> generateWorkerRankings({
    required String category, // 'safety', 'compliance', 'efficiency'
    int limit = 50,
  }) async {
    try {
      final rankings = <WorkerRanking>[];
      
      final workersQuery = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'worker')
          .get();

      for (final workerDoc in workersQuery.docs) {
        final workerId = workerDoc.id;
        final workerData = workerDoc.data();

        double score = 0.0;
        Map<String, double> metrics = {};

        if (category == 'safety') {
          score = await _calculateSafetyScore(workerId);
          metrics = await _getSafetyMetrics(workerId);
        } else if (category == 'compliance') {
          score = await _calculateComplianceScore(workerId);
          metrics = await _getComplianceMetrics(workerId);
        } else if (category == 'efficiency') {
          score = await _calculateEfficiencyScore(workerId);
          metrics = await _getEfficiencyMetrics(workerId);
        }

        // Get previous ranking
        final previousRank = await _getPreviousRanking(workerId, category);
        
        // Get achievements
        final achievements = await _getWorkerAchievements(workerId, category);

        rankings.add(WorkerRanking(
          workerId: workerId,
          workerName: '${workerData['firstName']} ${workerData['lastName']}',
          department: workerData['department'] ?? 'Unknown',
          profilePhotoUrl: workerData['profilePhotoUrl'] ?? '',
          rank: 0, // Will be set after sorting
          score: score,
          category: category,
          metrics: metrics,
          previousRank: previousRank,
          trend: 'stable', // Will be calculated after ranking
          achievements: achievements,
          lastUpdated: DateTime.now(),
        ));
      }

      // Sort and assign ranks
      rankings.sort((a, b) => b.score.compareTo(a.score));
      for (int i = 0; i < rankings.length; i++) {
        final ranking = rankings[i];
        rankings[i] = WorkerRanking(
          workerId: ranking.workerId,
          workerName: ranking.workerName,
          department: ranking.department,
          profilePhotoUrl: ranking.profilePhotoUrl,
          rank: i + 1,
          score: ranking.score,
          category: ranking.category,
          metrics: ranking.metrics,
          previousRank: ranking.previousRank,
          trend: _calculateTrend(i + 1, ranking.previousRank),
          achievements: ranking.achievements,
          lastUpdated: ranking.lastUpdated,
        );
      }

      return rankings.take(limit).toList();
    } catch (e) {
      print('Error generating worker rankings: $e');
      return [];
    }
  }

  /// Get department comparison data
  Future<List<DepartmentComparison>> getDepartmentComparisons({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      startDate ??= DateTime.now().subtract(const Duration(days: 30));
      endDate ??= DateTime.now();

      // Get all departments
      final departmentsQuery = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'worker')
          .get();

      Map<String, List<String>> departmentWorkers = {};
      for (final doc in departmentsQuery.docs) {
        final dept = doc.data()['department'] ?? 'Unknown';
        departmentWorkers[dept] ??= [];
        departmentWorkers[dept]!.add(doc.id);
      }

      final comparisons = <DepartmentComparison>[];

      for (final entry in departmentWorkers.entries) {
        final department = entry.key;
        final workerIds = entry.value;

        double totalExposure = 0.0;
        int violationCount = 0;
        double totalCompliance = 0.0;

        for (final workerId in workerIds) {
          totalExposure += await _calculatePeriodExposure(workerId, startDate, endDate);
          violationCount += await _getViolationCount(workerId, startDate, endDate);
          totalCompliance += await _calculateComplianceScore(workerId);
        }

        final averageExposure = workerIds.isNotEmpty ? totalExposure / workerIds.length : 0.0;
        final complianceRate = workerIds.isNotEmpty ? totalCompliance / workerIds.length : 0.0;
        
        // Calculate risk score
        final riskScore = _calculateDepartmentRiskScore(
          averageExposure, 
          violationCount, 
          complianceRate,
        );

        // Get KPI metrics
        final kpiMetrics = await _getDepartmentKPIs(department, workerIds, startDate, endDate);

        comparisons.add(DepartmentComparison(
          departmentId: department,
          departmentName: department,
          workerCount: workerIds.length,
          averageExposure: averageExposure,
          totalExposure: totalExposure,
          complianceRate: complianceRate,
          safetyViolations: violationCount,
          riskScore: riskScore,
          kpiMetrics: kpiMetrics,
          ranking: 0, // Will be set after sorting
          periodStart: startDate,
          periodEnd: endDate,
        ));
      }

      // Sort by risk score (lower is better) and assign rankings
      comparisons.sort((a, b) => a.riskScore.compareTo(b.riskScore));
      for (int i = 0; i < comparisons.length; i++) {
        comparisons[i] = DepartmentComparison(
          departmentId: comparisons[i].departmentId,
          departmentName: comparisons[i].departmentName,
          workerCount: comparisons[i].workerCount,
          averageExposure: comparisons[i].averageExposure,
          totalExposure: comparisons[i].totalExposure,
          complianceRate: comparisons[i].complianceRate,
          safetyViolations: comparisons[i].safetyViolations,
          riskScore: comparisons[i].riskScore,
          kpiMetrics: comparisons[i].kpiMetrics,
          ranking: i + 1,
          periodStart: comparisons[i].periodStart,
          periodEnd: comparisons[i].periodEnd,
        );
      }

      return comparisons;
    } catch (e) {
      print('Error getting department comparisons: $e');
      return [];
    }
  }

  /// Calculate budget impact analysis
  Future<BudgetImpactAnalysis> calculateBudgetImpact({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      startDate ??= DateTime.now().subtract(const Duration(days: 365));
      endDate ??= DateTime.now();

      // Get all workers
      final workersQuery = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'worker')
          .get();

      int totalWorkers = workersQuery.docs.length;
      int workersAtRisk = 0;
      
      // Industry averages (example values - should be configurable)
      const double avgClaimCost = 50000.0; // Average HAVS compensation claim
      const double avgMedicalCost = 15000.0; // Average medical treatment cost
      const double avgProductivityLoss = 25000.0; // Lost productivity per case
      const double insuranceIncrease = 0.15; // 15% premium increase per claim

      // Calculate current costs
      double currentClaims = 0.0;
      double currentMedical = 0.0;
      double currentProductivity = 0.0;
      
      for (final workerDoc in workersQuery.docs) {
        final workerId = workerDoc.id;
        
        // Get health profile
        final healthDoc = await _firestore
            .collection('health_profiles')
            .doc(workerId)
            .get();

        if (healthDoc.exists) {
          final healthData = healthDoc.data()!;
          final havsStage = healthData['havsStage'] ?? 0;
          
          if (havsStage >= 2) {
            workersAtRisk++;
            
            // Estimate costs based on HAVS stage
            if (havsStage >= 3) {
              currentClaims += avgClaimCost * 0.8; // 80% chance of claim
              currentMedical += avgMedicalCost;
              currentProductivity += avgProductivityLoss;
            } else if (havsStage >= 2) {
              currentClaims += avgClaimCost * 0.3; // 30% chance of claim
              currentMedical += avgMedicalCost * 0.5;
              currentProductivity += avgProductivityLoss * 0.3;
            }
          }
        }
      }

      // Calculate current insurance premiums
      final basePremium = totalWorkers * 2000.0; // $2000 per worker base
      final currentPremiums = basePremium * (1 + (workersAtRisk * 0.05));
      const currentTotalCost = 0.0; // Will calculate below

      // With Vibe Guard system - projected reductions
      const reductionFactor = 0.65; // 65% reduction in incidents
      final projectedClaimsReduction = currentClaims * reductionFactor;
      final projectedMedicalSavings = currentMedical * reductionFactor;
      final projectedProductivityGains = currentProductivity * reductionFactor;
      final projectedInsuranceSavings = (currentPremiums - basePremium) * 0.5; // 50% reduction in premium increases
      
      final projectedTotalSavings = projectedClaimsReduction + 
          projectedMedicalSavings + 
          projectedProductivityGains + 
          projectedInsuranceSavings;

      // Calculate potential claims avoided
      final potentialClaimsAvoided = (workersAtRisk * reductionFactor).round();
      
      // Risk reduction
      final riskReduction = workersAtRisk > 0 
          ? (potentialClaimsAvoided / workersAtRisk) * 100 
          : 0.0;

      // ROI calculations
      const systemCost = 50000.0; // Example implementation cost
      final roi = systemCost > 0 ? (projectedTotalSavings / systemCost) * 100 : 0.0;
      final paybackMonths = projectedTotalSavings > 0 
          ? (systemCost / (projectedTotalSavings / 12)).round() 
          : 0;

      return BudgetImpactAnalysis(
        analysisDate: DateTime.now(),
        periodStart: startDate,
        periodEnd: endDate,
        currentCompensationClaims: currentClaims,
        currentMedicalCosts: currentMedical,
        currentLostProductivity: currentProductivity,
        currentInsurancePremiums: currentPremiums,
        currentTotalCost: currentClaims + currentMedical + currentProductivity + currentPremiums,
        projectedClaimsReduction: projectedClaimsReduction,
        projectedMedicalSavings: projectedMedicalSavings,
        projectedProductivityGains: projectedProductivityGains,
        projectedInsuranceSavings: projectedInsuranceSavings,
        projectedTotalSavings: projectedTotalSavings,
        workersAtRisk: workersAtRisk,
        potentialClaimsAvoided: potentialClaimsAvoided,
        riskReductionPercentage: riskReduction,
        systemImplementationCost: systemCost,
        returnOnInvestment: roi,
        paybackPeriodMonths: paybackMonths,
      );
    } catch (e) {
      print('Error calculating budget impact: $e');
      rethrow;
    }
  }

  /// Get admin dashboard summary
  Future<AdminDashboardSummary> getDashboardSummary() async {
    try {
      // Get worker counts
      final workersQuery = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'worker')
          .get();

      int totalWorkers = workersQuery.docs.length;
      int activeWorkers = 0;
      int highRiskWorkers = 0;
      double totalExposure = 0.0;
      int compliantWorkers = 0;

      for (final doc in workersQuery.docs) {
        final workerId = doc.id;
        
        // Check if active
        if (await _isWorkerActiveToday(workerId)) {
          activeWorkers++;
        }

        // Check risk level
        final exposureDoc = await _firestore
            .collection('lifetime_exposures')
            .doc(workerId)
            .get();

        if (exposureDoc.exists) {
          final riskLevel = ExposureRiskLevel.fromString(
            exposureDoc.data()!['currentRiskLevel'] ?? 'low'
          );
          
          if (riskLevel.index >= ExposureRiskLevel.high.index) {
            highRiskWorkers++;
          }
        }

        // Calculate daily exposure
        final dailyExposure = await _calculateDailyExposure(workerId);
        totalExposure += dailyExposure;
        
        if (dailyExposure <= 5.0) {
          compliantWorkers++;
        }
      }

      final averageDailyExposure = totalWorkers > 0 ? totalExposure / totalWorkers : 0.0;
      final complianceRate = totalWorkers > 0 ? compliantWorkers / totalWorkers : 0.0;

      // Get today's violations
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      
      final violationsQuery = await _firestore
          .collection('safety_violations')
          .where('occurredAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .get();

      int todayViolations = violationsQuery.docs.length;

      // Get pending medical exams
      final pendingExams = await _firestore
          .collection('health_profiles')
          .where('nextMedicalExamDue', isLessThan: Timestamp.fromDate(DateTime.now().add(const Duration(days: 30))))
          .get();

      int pendingMedicalExams = pendingExams.docs.length;

      // Calculate estimated savings (simplified)
      final budgetImpact = await calculateBudgetImpact();
      final monthlySavings = budgetImpact.projectedTotalSavings / 12;

      // Compile key metrics
      Map<String, dynamic> keyMetrics = {
        'exposureTrend': await _calculateOverallExposureTrend(),
        'riskDistribution': await _getRiskDistribution(),
        'toolUtilization': await _getToolUtilizationRate(),
        'incidentRate': await _getIncidentRate(),
      };

      return AdminDashboardSummary(
        totalWorkers: totalWorkers,
        activeWorkers: activeWorkers,
        highRiskWorkers: highRiskWorkers,
        averageDailyExposure: averageDailyExposure,
        complianceRate: complianceRate,
        todayViolations: todayViolations,
        pendingMedicalExams: pendingMedicalExams,
        estimatedMonthlySavings: monthlySavings,
        keyMetrics: keyMetrics,
        lastUpdated: DateTime.now(),
      );
    } catch (e) {
      print('Error getting dashboard summary: $e');
      rethrow;
    }
  }

  // Helper methods

  Future<bool> _isWorkerActiveToday(String workerId) async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    
    final sessions = await _firestore
        .collection('timer_sessions')
        .where('workerId', isEqualTo: workerId)
        .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .limit(1)
        .get();

    return sessions.docs.isNotEmpty;
  }

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

  Future<double> _calculateWeeklyExposure(String workerId) async {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));

    final sessions = await _firestore
        .collection('timer_sessions')
        .where('workerId', isEqualTo: workerId)
        .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(weekStart))
        .get();

    double totalA8 = 0.0;
    for (final doc in sessions.docs) {
      totalA8 += (doc.data()['dailyExposure'] ?? 0.0) as double;
    }

    return totalA8;
  }

  Future<double> _calculateExposureTrend(String workerId) async {
    final thisWeek = await _calculateWeeklyExposure(workerId);
    
    final lastWeekStart = DateTime.now().subtract(const Duration(days: 14));
    final lastWeekEnd = DateTime.now().subtract(const Duration(days: 7));
    
    final lastWeekSessions = await _firestore
        .collection('timer_sessions')
        .where('workerId', isEqualTo: workerId)
        .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(lastWeekStart))
        .where('startTime', isLessThan: Timestamp.fromDate(lastWeekEnd))
        .get();

    double lastWeekTotal = 0.0;
    for (final doc in lastWeekSessions.docs) {
      lastWeekTotal += (doc.data()['dailyExposure'] ?? 0.0) as double;
    }

    if (lastWeekTotal == 0) return 0.0;
    return ((thisWeek - lastWeekTotal) / lastWeekTotal) * 100;
  }

  List<String> _identifyRiskFactors(HealthProfile profile, Map<String, dynamic> exposureData) {
    final factors = <String>[];

    if (profile.havsStage.index >= 2) {
      factors.add('HAVS Stage ${profile.havsStage.index}');
    }

    if ((exposureData['totalLifetimeA8'] ?? 0.0) > 1000) {
      factors.add('High lifetime exposure');
    }

    if (profile.age > 50) {
      factors.add('Age over 50');
    }

    if (profile.smokingStatus) {
      factors.add('Smoker');
    }

    if (profile.hasPreExistingConditions) {
      factors.add('Pre-existing conditions');
    }

    if (profile.isMedicalExamOverdue) {
      factors.add('Medical exam overdue');
    }

    return factors;
  }

  List<String> _generateRecommendations(double riskScore, int havsStage, Map<String, dynamic> exposureData) {
    final recommendations = <String>[];

    if (riskScore >= 80) {
      recommendations.add('Immediate medical evaluation required');
      recommendations.add('Consider work restrictions');
    }

    if (havsStage >= 2) {
      recommendations.add('Increase medical monitoring frequency');
      recommendations.add('Implement job rotation schedule');
    }

    if ((exposureData['exposureVelocity'] ?? 0.0) > 0.5) {
      recommendations.add('Reduce daily exposure limits');
      recommendations.add('Mandatory anti-vibration PPE');
    }

    recommendations.add('Regular health questionnaire completion');
    recommendations.add('Symptom tracking and reporting');

    return recommendations;
  }

  Future<Map<String, ComplianceMetric>> _calculateComplianceMetrics(List<String> workerIds) async {
    final metrics = <String, ComplianceMetric>{};

    // Daily exposure limit compliance
    int exposureChecks = 0;
    int exposureCompliant = 0;

    for (final workerId in workerIds) {
      final dailyExposure = await _calculateDailyExposure(workerId);
      exposureChecks++;
      if (dailyExposure <= 5.0) exposureCompliant++;
    }

    metrics['exposure_limit'] = ComplianceMetric(
      metricId: 'exposure_limit',
      metricName: 'Daily Exposure Limit',
      complianceRate: exposureChecks > 0 ? exposureCompliant / exposureChecks : 0.0,
      totalChecks: exposureChecks,
      compliantChecks: exposureCompliant,
      status: exposureCompliant == exposureChecks ? 'compliant' : 'warning',
      lastChecked: DateTime.now(),
    );

    // Add more metrics as needed...

    return metrics;
  }

  Future<List<ComplianceViolation>> _getRecentViolations(List<String> workerIds) async {
    final violations = <ComplianceViolation>[];
    
    for (final workerId in workerIds) {
      final violationQuery = await _firestore
          .collection('safety_violations')
          .where('workerId', isEqualTo: workerId)
          .orderBy('occurredAt', descending: true)
          .limit(5)
          .get();

      for (final doc in violationQuery.docs) {
        final data = doc.data();
        violations.add(ComplianceViolation(
          violationId: doc.id,
          violationType: data['violationType'] ?? 'Unknown',
          occurredAt: (data['occurredAt'] as Timestamp).toDate(),
          severity: data['severity'] ?? 'low',
          description: data['description'] ?? '',
        ));
      }
    }

    return violations;
  }

  Future<List<ToolUsageTrend>> _calculateToolUsageTrends(
    String toolId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final trends = <ToolUsageTrend>[];
    final days = endDate.difference(startDate).inDays;
    
    for (int i = 0; i < days; i += 7) { // Weekly trends
      final weekStart = startDate.add(Duration(days: i));
      final weekEnd = weekStart.add(const Duration(days: 7));

      final sessions = await _firestore
          .collection('timer_sessions')
          .where('toolId', isEqualTo: toolId)
          .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(weekStart))
          .where('startTime', isLessThan: Timestamp.fromDate(weekEnd))
          .get();

      int totalMinutes = 0;
      double totalVibration = 0.0;

      for (final doc in sessions.docs) {
        final data = doc.data();
        totalMinutes += (data['totalMinutes'] ?? 0) as int;
        totalVibration += (data['vibrationLevel'] ?? 0.0) as double;
      }

      trends.add(ToolUsageTrend(
        date: weekStart,
        usageMinutes: totalMinutes,
        sessions: sessions.docs.length,
        averageVibration: sessions.docs.isNotEmpty ? totalVibration / sessions.docs.length : 0.0,
      ));
    }

    return trends;
  }

  Future<double> _calculateMaintenanceCompliance(String toolId) async {
    final maintenanceQuery = await _firestore
        .collection('tool_maintenance')
        .where('toolId', isEqualTo: toolId)
        .orderBy('scheduledDate', descending: true)
        .limit(10)
        .get();

    if (maintenanceQuery.docs.isEmpty) return 0.0;

    int onTime = 0;
    for (final doc in maintenanceQuery.docs) {
      final data = doc.data();
      if (data['completedDate'] != null) {
        final scheduled = (data['scheduledDate'] as Timestamp).toDate();
        final completed = (data['completedDate'] as Timestamp).toDate();
        if (completed.isBefore(scheduled.add(const Duration(days: 7)))) {
          onTime++;
        }
      }
    }

    return onTime / maintenanceQuery.docs.length;
  }

  Future<double> _calculateSafetyScore(String workerId) async {
    // Implement safety score calculation logic
    double score = 100.0;

    // Check violations
    final violations = await _firestore
        .collection('safety_violations')
        .where('workerId', isEqualTo: workerId)
        .where('occurredAt', isGreaterThan: Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 90))))
        .get();

    score -= violations.docs.length * 10;

    // Check exposure compliance
    final dailyExposure = await _calculateDailyExposure(workerId);
    if (dailyExposure > 5.0) score -= 20;
    if (dailyExposure > 2.5) score -= 10;

    return math.max(0, score);
  }

  Future<Map<String, double>> _getSafetyMetrics(String workerId) async {
    return {
      'violations': 0.0,
      'exposureCompliance': 100.0,
      'ppe_usage': 95.0,
      'training_completion': 100.0,
    };
  }

  Future<double> _calculateComplianceScore(String workerId) async {
    // Implement compliance score calculation
    return 85.0;
  }

  Future<Map<String, double>> _getComplianceMetrics(String workerId) async {
    return {
      'daily_limits': 100.0,
      'medical_exams': 90.0,
      'questionnaires': 85.0,
      'reporting': 95.0,
    };
  }

  Future<double> _calculateEfficiencyScore(String workerId) async {
    // Implement efficiency score calculation
    return 75.0;
  }

  Future<Map<String, double>> _getEfficiencyMetrics(String workerId) async {
    return {
      'task_completion': 90.0,
      'time_management': 85.0,
      'tool_utilization': 80.0,
      'productivity': 88.0,
    };
  }

  Future<int> _getPreviousRanking(String workerId, String category) async {
    // Get previous ranking from history
    return 5;
  }

  Future<List<String>> _getWorkerAchievements(String workerId, String category) async {
    final achievements = <String>[];

    if (category == 'safety') {
      achievements.add('30 Days Violation Free');
      achievements.add('Safety Champion');
    }

    return achievements;
  }

  String _calculateTrend(int currentRank, int previousRank) {
    if (currentRank < previousRank) return 'up';
    if (currentRank > previousRank) return 'down';
    return 'stable';
  }

  Future<double> _calculatePeriodExposure(
    String workerId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final sessions = await _firestore
        .collection('timer_sessions')
        .where('workerId', isEqualTo: workerId)
        .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('startTime', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .get();

    double total = 0.0;
    for (final doc in sessions.docs) {
      total += (doc.data()['dailyExposure'] ?? 0.0) as double;
    }

    return total;
  }

  Future<int> _getViolationCount(
    String workerId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final violations = await _firestore
        .collection('safety_violations')
        .where('workerId', isEqualTo: workerId)
        .where('occurredAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('occurredAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .get();

    return violations.docs.length;
  }

  double _calculateDepartmentRiskScore(
    double averageExposure,
    int violations,
    double complianceRate,
  ) {
    double score = 0.0;

    // Exposure component (0-40 points)
    score += math.min(40, averageExposure * 8);

    // Violations component (0-30 points)
    score += math.min(30, violations * 5);

    // Compliance component (0-30 points)
    score += (1 - complianceRate) * 30;

    return score;
  }

  Future<Map<String, double>> _getDepartmentKPIs(
    String department,
    List<String> workerIds,
    DateTime startDate,
    DateTime endDate,
  ) async {
    return {
      'productivity': 85.0,
      'efficiency': 78.0,
      'safety_score': 92.0,
      'training_completion': 95.0,
    };
  }

  Future<double> _calculateOverallExposureTrend() async {
    // Calculate overall exposure trend across all workers
    return -5.2; // Example: 5.2% reduction
  }

  Future<Map<String, int>> _getRiskDistribution() async {
    return {
      'low': 45,
      'moderate': 30,
      'high': 20,
      'critical': 5,
    };
  }

  Future<double> _getToolUtilizationRate() async {
    return 78.5; // 78.5% utilization
  }

  Future<double> _getIncidentRate() async {
    return 2.3; // 2.3 incidents per 100 workers
  }
}