import 'package:cloud_firestore/cloud_firestore.dart';
import '../health/lifetime_exposure.dart';

/// Worker monitoring data for real-time map display
class WorkerMonitoringData {
  final String workerId;
  final String workerName;
  final String department;
  final String? projectId;
  final GeoLocation? currentLocation;
  final bool isActive;
  final String? currentToolId;
  final String? currentToolName;
  final double? currentVibrationLevel;
  final DateTime? sessionStartTime;
  final double currentDailyExposure;
  final ExposureRiskLevel riskLevel;
  final bool hasActiveAlert;
  final DateTime lastUpdated;

  WorkerMonitoringData({
    required this.workerId,
    required this.workerName,
    required this.department,
    this.projectId,
    this.currentLocation,
    required this.isActive,
    this.currentToolId,
    this.currentToolName,
    this.currentVibrationLevel,
    this.sessionStartTime,
    required this.currentDailyExposure,
    required this.riskLevel,
    required this.hasActiveAlert,
    required this.lastUpdated,
  });

  Map<String, dynamic> toMap() {
    return {
      'workerId': workerId,
      'workerName': workerName,
      'department': department,
      'projectId': projectId,
      'currentLocation': currentLocation?.toMap(),
      'isActive': isActive,
      'currentToolId': currentToolId,
      'currentToolName': currentToolName,
      'currentVibrationLevel': currentVibrationLevel,
      'sessionStartTime': sessionStartTime?.toIso8601String(),
      'currentDailyExposure': currentDailyExposure,
      'riskLevel': riskLevel.name,
      'hasActiveAlert': hasActiveAlert,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }
}

/// Geographic location for mapping
class GeoLocation {
  final double latitude;
  final double longitude;
  final double? accuracy;
  final String? address;

  GeoLocation({
    required this.latitude,
    required this.longitude,
    this.accuracy,
    this.address,
  });

  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'address': address,
    };
  }
}

/// Team exposure overview data
class TeamExposureOverview {
  final String teamId;
  final String teamName;
  final int totalWorkers;
  final int activeWorkers;
  final double averageDailyExposure;
  final double totalTeamExposure;
  final Map<ExposureRiskLevel, int> riskDistribution;
  final List<String> highRiskWorkerIds;
  final double complianceRate;
  final DateTime lastUpdated;

  TeamExposureOverview({
    required this.teamId,
    required this.teamName,
    required this.totalWorkers,
    required this.activeWorkers,
    required this.averageDailyExposure,
    required this.totalTeamExposure,
    required this.riskDistribution,
    required this.highRiskWorkerIds,
    required this.complianceRate,
    required this.lastUpdated,
  });
}

/// High-risk worker profile for priority monitoring
class HighRiskWorkerProfile {
  final String workerId;
  final String workerName;
  final String department;
  final double riskScore;
  final ExposureRiskLevel riskLevel;
  final double lifetimeExposure;
  final double currentWeekExposure;
  final double exposureTrend; // percentage change
  final int havsStage;
  final DateTime? lastMedicalExam;
  final DateTime? nextMedicalExamDue;
  final List<String> riskFactors;
  final List<String> recommendations;
  final bool requiresImmediateAction;

  HighRiskWorkerProfile({
    required this.workerId,
    required this.workerName,
    required this.department,
    required this.riskScore,
    required this.riskLevel,
    required this.lifetimeExposure,
    required this.currentWeekExposure,
    required this.exposureTrend,
    required this.havsStage,
    this.lastMedicalExam,
    this.nextMedicalExamDue,
    required this.riskFactors,
    required this.recommendations,
    required this.requiresImmediateAction,
  });
}

/// Compliance status for dashboard display
class ComplianceStatus {
  final String entityId; // worker, team, or department ID
  final String entityType; // 'worker', 'team', 'department'
  final String entityName;
  final double overallComplianceRate;
  final Map<String, ComplianceMetric> metrics;
  final List<ComplianceViolation> recentViolations;
  final DateTime lastUpdated;

  ComplianceStatus({
    required this.entityId,
    required this.entityType,
    required this.entityName,
    required this.overallComplianceRate,
    required this.metrics,
    required this.recentViolations,
    required this.lastUpdated,
  });
}

/// Individual compliance metric
class ComplianceMetric {
  final String metricId;
  final String metricName;
  final double complianceRate;
  final int totalChecks;
  final int compliantChecks;
  final String status; // 'compliant', 'warning', 'violation'
  final DateTime lastChecked;

  ComplianceMetric({
    required this.metricId,
    required this.metricName,
    required this.complianceRate,
    required this.totalChecks,
    required this.compliantChecks,
    required this.status,
    required this.lastChecked,
  });
}

/// Safety violation record
class SafetyViolation {
  final String violationId;
  final String workerId;
  final String workerName;
  final DateTime occurredAt;
  final String violationType;
  final String severity; // 'low', 'medium', 'high', 'critical'
  final String description;
  final double? exposureValue;
  final String? toolId;
  final String? locationId;
  final List<String> correctionsTaken;
  final bool isResolved;
  final String? resolvedBy;
  final DateTime? resolvedAt;

  SafetyViolation({
    required this.violationId,
    required this.workerId,
    required this.workerName,
    required this.occurredAt,
    required this.violationType,
    required this.severity,
    required this.description,
    this.exposureValue,
    this.toolId,
    this.locationId,
    required this.correctionsTaken,
    required this.isResolved,
    this.resolvedBy,
    this.resolvedAt,
  });
}

/// Compliance violation for tracking
class ComplianceViolation {
  final String violationId;
  final String violationType;
  final DateTime occurredAt;
  final String severity;
  final String description;

  ComplianceViolation({
    required this.violationId,
    required this.violationType,
    required this.occurredAt,
    required this.severity,
    required this.description,
  });
}

/// Tool usage analytics data
class ToolUsageAnalytics {
  final String toolId;
  final String toolName;
  final String toolType;
  final double averageVibrationLevel;
  final int totalUsageMinutes;
  final int totalSessions;
  final int uniqueUsers;
  final Map<String, int> usageByDepartment;
  final Map<String, double> exposureContribution;
  final double maintenanceCompliance;
  final int overdueMaintenanceCount;
  final DateTime lastUsed;
  final List<ToolUsageTrend> usageTrends;

  ToolUsageAnalytics({
    required this.toolId,
    required this.toolName,
    required this.toolType,
    required this.averageVibrationLevel,
    required this.totalUsageMinutes,
    required this.totalSessions,
    required this.uniqueUsers,
    required this.usageByDepartment,
    required this.exposureContribution,
    required this.maintenanceCompliance,
    required this.overdueMaintenanceCount,
    required this.lastUsed,
    required this.usageTrends,
  });
}

/// Tool usage trend over time
class ToolUsageTrend {
  final DateTime date;
  final int usageMinutes;
  final int sessions;
  final double averageVibration;

  ToolUsageTrend({
    required this.date,
    required this.usageMinutes,
    required this.sessions,
    required this.averageVibration,
  });
}

/// Worker ranking for leaderboard
class WorkerRanking {
  final String workerId;
  final String workerName;
  final String department;
  final String profilePhotoUrl;
  final int rank;
  final double score;
  final String category; // 'safety', 'compliance', 'efficiency'
  final Map<String, double> metrics;
  final int previousRank;
  final String trend; // 'up', 'down', 'stable'
  final List<String> achievements;
  final DateTime lastUpdated;

  WorkerRanking({
    required this.workerId,
    required this.workerName,
    required this.department,
    required this.profilePhotoUrl,
    required this.rank,
    required this.score,
    required this.category,
    required this.metrics,
    required this.previousRank,
    required this.trend,
    required this.achievements,
    required this.lastUpdated,
  });

  int get rankChange => previousRank - rank;
}

/// Department comparison data
class DepartmentComparison {
  final String departmentId;
  final String departmentName;
  final int workerCount;
  final double averageExposure;
  final double totalExposure;
  final double complianceRate;
  final int safetyViolations;
  final double riskScore;
  final Map<String, double> kpiMetrics;
  final int ranking;
  final DateTime periodStart;
  final DateTime periodEnd;

  DepartmentComparison({
    required this.departmentId,
    required this.departmentName,
    required this.workerCount,
    required this.averageExposure,
    required this.totalExposure,
    required this.complianceRate,
    required this.safetyViolations,
    required this.riskScore,
    required this.kpiMetrics,
    required this.ranking,
    required this.periodStart,
    required this.periodEnd,
  });
}

/// Project comparison data
class ProjectComparison {
  final String projectId;
  final String projectName;
  final String projectManager;
  final int workerCount;
  final double totalExposure;
  final double averageExposure;
  final double complianceRate;
  final int incidentCount;
  final double budgetImpact;
  final String status; // 'on-track', 'at-risk', 'critical'
  final DateTime startDate;
  final DateTime? endDate;
  final Map<String, double> metrics;

  ProjectComparison({
    required this.projectId,
    required this.projectName,
    required this.projectManager,
    required this.workerCount,
    required this.totalExposure,
    required this.averageExposure,
    required this.complianceRate,
    required this.incidentCount,
    required this.budgetImpact,
    required this.status,
    required this.startDate,
    this.endDate,
    required this.metrics,
  });
}

/// Custom report configuration
class CustomReportConfig {
  final String reportId;
  final String reportName;
  final String createdBy;
  final DateTime createdAt;
  final List<String> dataTypes;
  final Map<String, dynamic> filters;
  final List<String> groupBy;
  final List<String> metrics;
  final String outputFormat; // 'pdf', 'excel', 'csv', 'json'
  final bool isScheduled;
  final String? schedule; // cron expression
  final List<String> recipients;
  final DateTime? lastGenerated;

  CustomReportConfig({
    required this.reportId,
    required this.reportName,
    required this.createdBy,
    required this.createdAt,
    required this.dataTypes,
    required this.filters,
    required this.groupBy,
    required this.metrics,
    required this.outputFormat,
    required this.isScheduled,
    this.schedule,
    required this.recipients,
    this.lastGenerated,
  });
}

/// Budget impact analysis
class BudgetImpactAnalysis {
  final DateTime analysisDate;
  final DateTime periodStart;
  final DateTime periodEnd;
  
  // Current costs
  final double currentCompensationClaims;
  final double currentMedicalCosts;
  final double currentLostProductivity;
  final double currentInsurancePremiums;
  final double currentTotalCost;
  
  // Projected savings
  final double projectedClaimsReduction;
  final double projectedMedicalSavings;
  final double projectedProductivityGains;
  final double projectedInsuranceSavings;
  final double projectedTotalSavings;
  
  // Risk metrics
  final int workersAtRisk;
  final int potentialClaimsAvoided;
  final double riskReductionPercentage;
  
  // ROI calculations
  final double systemImplementationCost;
  final double returnOnInvestment;
  final int paybackPeriodMonths;
  
  BudgetImpactAnalysis({
    required this.analysisDate,
    required this.periodStart,
    required this.periodEnd,
    required this.currentCompensationClaims,
    required this.currentMedicalCosts,
    required this.currentLostProductivity,
    required this.currentInsurancePremiums,
    required this.currentTotalCost,
    required this.projectedClaimsReduction,
    required this.projectedMedicalSavings,
    required this.projectedProductivityGains,
    required this.projectedInsuranceSavings,
    required this.projectedTotalSavings,
    required this.workersAtRisk,
    required this.potentialClaimsAvoided,
    required this.riskReductionPercentage,
    required this.systemImplementationCost,
    required this.returnOnInvestment,
    required this.paybackPeriodMonths,
  });
}

/// Admin dashboard summary
class AdminDashboardSummary {
  final int totalWorkers;
  final int activeWorkers;
  final int highRiskWorkers;
  final double averageDailyExposure;
  final double complianceRate;
  final int todayViolations;
  final int pendingMedicalExams;
  final double estimatedMonthlySavings;
  final Map<String, dynamic> keyMetrics;
  final DateTime lastUpdated;

  AdminDashboardSummary({
    required this.totalWorkers,
    required this.activeWorkers,
    required this.highRiskWorkers,
    required this.averageDailyExposure,
    required this.complianceRate,
    required this.todayViolations,
    required this.pendingMedicalExams,
    required this.estimatedMonthlySavings,
    required this.keyMetrics,
    required this.lastUpdated,
  });
}