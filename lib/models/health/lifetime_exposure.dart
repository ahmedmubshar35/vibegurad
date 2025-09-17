import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/base_model.dart';

/// Cumulative lifetime exposure tracking for HAVS risk assessment
class LifetimeExposure extends BaseModel {
  final String workerId;
  
  // Cumulative exposure metrics
  final double totalLifetimeA8; // Cumulative A(8) exposure
  final double totalLifetimeHours; // Total hours using vibrating tools
  final double totalLifetimePoints; // Total HSE points accumulated
  
  // Year-by-year breakdown
  final Map<int, YearlyExposure> yearlyBreakdown;
  
  // Tool-specific cumulative exposure
  final Map<String, ToolLifetimeExposure> toolExposureBreakdown;
  
  // Risk progression tracking
  final List<ExposureRiskPoint> riskProgressionHistory;
  
  // Current status
  final DateTime lastUpdated;
  final double currentRiskTrend; // positive = increasing risk, negative = decreasing
  final ExposureRiskLevel currentRiskLevel;
  final DateTime? projectedHAVSOnset; // Estimated date based on current trajectory

  LifetimeExposure({
    super.id,
    required this.workerId,
    required this.totalLifetimeA8,
    required this.totalLifetimeHours,
    required this.totalLifetimePoints,
    required this.yearlyBreakdown,
    required this.toolExposureBreakdown,
    required this.riskProgressionHistory,
    required this.lastUpdated,
    required this.currentRiskTrend,
    required this.currentRiskLevel,
    this.projectedHAVSOnset,
    super.createdAt,
    super.updatedAt,
    super.isActive,
  });

  // Calculate exposure velocity (A8 units per month)
  double get exposureVelocity {
    if (riskProgressionHistory.length < 2) return 0.0;
    
    final recent = riskProgressionHistory.take(6).toList(); // Last 6 months
    if (recent.length < 2) return 0.0;
    
    final oldestRecent = recent.last;
    final newest = recent.first;
    final monthsDiff = newest.recordedAt.difference(oldestRecent.recordedAt).inDays / 30.0;
    
    if (monthsDiff <= 0) return 0.0;
    return (newest.cumulativeA8 - oldestRecent.cumulativeA8) / monthsDiff;
  }

  // Calculate acceleration (change in velocity)
  double get exposureAcceleration {
    if (riskProgressionHistory.length < 12) return 0.0;
    
    final recentVelocity = _calculateVelocityForPeriod(0, 6); // Last 6 months
    final olderVelocity = _calculateVelocityForPeriod(6, 12); // Previous 6 months
    
    return recentVelocity - olderVelocity;
  }

  double _calculateVelocityForPeriod(int startMonths, int endMonths) {
    final periodData = riskProgressionHistory.skip(startMonths).take(endMonths - startMonths).toList();
    if (periodData.length < 2) return 0.0;
    
    final oldest = periodData.last;
    final newest = periodData.first;
    final monthsDiff = newest.recordedAt.difference(oldest.recordedAt).inDays / 30.0;
    
    if (monthsDiff <= 0) return 0.0;
    return (newest.cumulativeA8 - oldest.cumulativeA8) / monthsDiff;
  }

  // Get exposure trend over last N months
  ExposureTrend getExposureTrend(int months) {
    if (riskProgressionHistory.length < 2) {
      return ExposureTrend.stable;
    }
    
    final recentData = riskProgressionHistory.take(months).toList();
    if (recentData.length < 2) return ExposureTrend.stable;
    
    final velocity = exposureVelocity;
    final acceleration = exposureAcceleration;
    
    if (velocity > 0.5 && acceleration > 0.1) return ExposureTrend.rapidlyIncreasing;
    if (velocity > 0.2) return ExposureTrend.increasing;
    if (velocity < -0.2) return ExposureTrend.decreasing;
    if (velocity < -0.5 && acceleration < -0.1) return ExposureTrend.rapidlyDecreasing;
    
    return ExposureTrend.stable;
  }

  // Calculate years to HAVS onset based on current trajectory
  double? get yearsToProjectedHAVSOnset {
    if (projectedHAVSOnset == null) return null;
    final diff = projectedHAVSOnset!.difference(DateTime.now());
    return diff.inDays / 365.25;
  }

  @override
  Map<String, dynamic> toJson() {
    return toFirestore();
  }
  
  Map<String, dynamic> toFirestore() {
    return {
      if (id != null) 'id': id,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
      'isActive': isActive,
      'workerId': workerId,
      'totalLifetimeA8': totalLifetimeA8,
      'totalLifetimeHours': totalLifetimeHours,
      'totalLifetimePoints': totalLifetimePoints,
      'yearlyBreakdown': yearlyBreakdown.map((year, exposure) => 
          MapEntry(year.toString(), exposure.toMap())),
      'toolExposureBreakdown': toolExposureBreakdown.map((tool, exposure) => 
          MapEntry(tool, exposure.toMap())),
      'riskProgressionHistory': riskProgressionHistory.map((point) => point.toMap()).toList(),
      'lastUpdated': Timestamp.fromDate(lastUpdated),
      'currentRiskTrend': currentRiskTrend,
      'currentRiskLevel': currentRiskLevel.name,
      'projectedHAVSOnset': projectedHAVSOnset != null ? Timestamp.fromDate(projectedHAVSOnset!) : null,
    };
  }

  factory LifetimeExposure.fromFirestore(Map<String, dynamic> data, String id) {
    return LifetimeExposure(
      id: id,
      workerId: data['workerId'] ?? '',
      totalLifetimeA8: (data['totalLifetimeA8'] ?? 0.0).toDouble(),
      totalLifetimeHours: (data['totalLifetimeHours'] ?? 0.0).toDouble(),
      totalLifetimePoints: (data['totalLifetimePoints'] ?? 0.0).toDouble(),
      yearlyBreakdown: (data['yearlyBreakdown'] as Map<String, dynamic>? ?? {})
          .map((year, exposureData) => MapEntry(
              int.parse(year), 
              YearlyExposure.fromMap(exposureData as Map<String, dynamic>))),
      toolExposureBreakdown: (data['toolExposureBreakdown'] as Map<String, dynamic>? ?? {})
          .map((tool, exposureData) => MapEntry(
              tool, 
              ToolLifetimeExposure.fromMap(exposureData as Map<String, dynamic>))),
      riskProgressionHistory: (data['riskProgressionHistory'] as List<dynamic>? ?? [])
          .map((pointData) => ExposureRiskPoint.fromMap(pointData as Map<String, dynamic>))
          .toList(),
      lastUpdated: (data['lastUpdated'] as Timestamp).toDate(),
      currentRiskTrend: (data['currentRiskTrend'] ?? 0.0).toDouble(),
      currentRiskLevel: ExposureRiskLevel.fromString(data['currentRiskLevel'] ?? 'low'),
      projectedHAVSOnset: data['projectedHAVSOnset'] != null 
          ? (data['projectedHAVSOnset'] as Timestamp).toDate() 
          : null,
      createdAt: data['createdAt'] != null 
          ? (data['createdAt'] as Timestamp).toDate() 
          : DateTime.now(),
      updatedAt: data['updatedAt'] != null 
          ? (data['updatedAt'] as Timestamp).toDate() 
          : DateTime.now(),
      isActive: data['isActive'] ?? true,
    );
  }
  
  // Add required properties for exposure chart
  double get cumulativeA8 => totalLifetimeA8;
  double get hsePoints => totalLifetimePoints;
  double get yearsOfExposure => totalLifetimeHours / (8 * 240); // 8 hours/day, 240 days/year
  ExposureRiskLevel get riskLevel => currentRiskLevel;
  
  @override
  LifetimeExposure copyWith({
    String? id,
    String? workerId,
    double? totalLifetimeA8,
    double? totalLifetimeHours,
    double? totalLifetimePoints,
    Map<int, YearlyExposure>? yearlyBreakdown,
    Map<String, ToolLifetimeExposure>? toolExposureBreakdown,
    List<ExposureRiskPoint>? riskProgressionHistory,
    DateTime? lastUpdated,
    double? currentRiskTrend,
    ExposureRiskLevel? currentRiskLevel,
    DateTime? projectedHAVSOnset,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
  }) {
    return LifetimeExposure(
      id: id ?? this.id,
      workerId: workerId ?? this.workerId,
      totalLifetimeA8: totalLifetimeA8 ?? this.totalLifetimeA8,
      totalLifetimeHours: totalLifetimeHours ?? this.totalLifetimeHours,
      totalLifetimePoints: totalLifetimePoints ?? this.totalLifetimePoints,
      yearlyBreakdown: yearlyBreakdown ?? this.yearlyBreakdown,
      toolExposureBreakdown: toolExposureBreakdown ?? this.toolExposureBreakdown,
      riskProgressionHistory: riskProgressionHistory ?? this.riskProgressionHistory,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      currentRiskTrend: currentRiskTrend ?? this.currentRiskTrend,
      currentRiskLevel: currentRiskLevel ?? this.currentRiskLevel,
      projectedHAVSOnset: projectedHAVSOnset ?? this.projectedHAVSOnset,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
    );
  }
}

/// Yearly exposure breakdown
class YearlyExposure {
  final int year;
  final double totalA8;
  final double totalHours;
  final double totalPoints;
  final int daysWorked;
  final double averageDailyA8;
  final Map<String, double> monthlyBreakdown; // month -> A8 value

  YearlyExposure({
    required this.year,
    required this.totalA8,
    required this.totalHours,
    required this.totalPoints,
    required this.daysWorked,
    required this.averageDailyA8,
    required this.monthlyBreakdown,
  });

  Map<String, dynamic> toMap() {
    return {
      'year': year,
      'totalA8': totalA8,
      'totalHours': totalHours,
      'totalPoints': totalPoints,
      'daysWorked': daysWorked,
      'averageDailyA8': averageDailyA8,
      'monthlyBreakdown': monthlyBreakdown,
    };
  }

  factory YearlyExposure.fromMap(Map<String, dynamic> map) {
    return YearlyExposure(
      year: map['year'] ?? 0,
      totalA8: (map['totalA8'] ?? 0.0).toDouble(),
      totalHours: (map['totalHours'] ?? 0.0).toDouble(),
      totalPoints: (map['totalPoints'] ?? 0.0).toDouble(),
      daysWorked: map['daysWorked'] ?? 0,
      averageDailyA8: (map['averageDailyA8'] ?? 0.0).toDouble(),
      monthlyBreakdown: Map<String, double>.from(map['monthlyBreakdown'] ?? {}),
    );
  }
}

/// Tool-specific lifetime exposure
class ToolLifetimeExposure {
  final String toolId;
  final String toolName;
  final double totalA8;
  final double totalHours;
  final double totalPoints;
  final int totalSessions;
  final DateTime firstUsed;
  final DateTime lastUsed;
  final double averageVibrationLevel;
  final List<String> maintenanceIssues; // Times used with maintenance due/overdue

  ToolLifetimeExposure({
    required this.toolId,
    required this.toolName,
    required this.totalA8,
    required this.totalHours,
    required this.totalPoints,
    required this.totalSessions,
    required this.firstUsed,
    required this.lastUsed,
    required this.averageVibrationLevel,
    required this.maintenanceIssues,
  });

  Map<String, dynamic> toMap() {
    return {
      'toolId': toolId,
      'toolName': toolName,
      'totalA8': totalA8,
      'totalHours': totalHours,
      'totalPoints': totalPoints,
      'totalSessions': totalSessions,
      'firstUsed': Timestamp.fromDate(firstUsed),
      'lastUsed': Timestamp.fromDate(lastUsed),
      'averageVibrationLevel': averageVibrationLevel,
      'maintenanceIssues': maintenanceIssues,
    };
  }

  factory ToolLifetimeExposure.fromMap(Map<String, dynamic> map) {
    return ToolLifetimeExposure(
      toolId: map['toolId'] ?? '',
      toolName: map['toolName'] ?? '',
      totalA8: (map['totalA8'] ?? 0.0).toDouble(),
      totalHours: (map['totalHours'] ?? 0.0).toDouble(),
      totalPoints: (map['totalPoints'] ?? 0.0).toDouble(),
      totalSessions: map['totalSessions'] ?? 0,
      firstUsed: (map['firstUsed'] as Timestamp).toDate(),
      lastUsed: (map['lastUsed'] as Timestamp).toDate(),
      averageVibrationLevel: (map['averageVibrationLevel'] ?? 0.0).toDouble(),
      maintenanceIssues: List<String>.from(map['maintenanceIssues'] ?? []),
    );
  }
}

/// Point-in-time risk assessment
class ExposureRiskPoint {
  final DateTime recordedAt;
  final double cumulativeA8;
  final double cumulativeHours;
  final double cumulativePoints;
  final double healthRiskScore;
  final ExposureRiskLevel riskLevel;
  final int havsStage;
  final bool hadSymptoms;
  final String? triggerEvent; // 'medical_exam', 'symptom_report', 'routine_update'

  ExposureRiskPoint({
    required this.recordedAt,
    required this.cumulativeA8,
    required this.cumulativeHours,
    required this.cumulativePoints,
    required this.healthRiskScore,
    required this.riskLevel,
    required this.havsStage,
    required this.hadSymptoms,
    this.triggerEvent,
  });

  Map<String, dynamic> toMap() {
    return {
      'recordedAt': Timestamp.fromDate(recordedAt),
      'cumulativeA8': cumulativeA8,
      'cumulativeHours': cumulativeHours,
      'cumulativePoints': cumulativePoints,
      'healthRiskScore': healthRiskScore,
      'riskLevel': riskLevel.name,
      'havsStage': havsStage,
      'hadSymptoms': hadSymptoms,
      'triggerEvent': triggerEvent,
    };
  }

  factory ExposureRiskPoint.fromMap(Map<String, dynamic> map) {
    return ExposureRiskPoint(
      recordedAt: (map['recordedAt'] as Timestamp).toDate(),
      cumulativeA8: (map['cumulativeA8'] ?? 0.0).toDouble(),
      cumulativeHours: (map['cumulativeHours'] ?? 0.0).toDouble(),
      cumulativePoints: (map['cumulativePoints'] ?? 0.0).toDouble(),
      healthRiskScore: (map['healthRiskScore'] ?? 0.0).toDouble(),
      riskLevel: ExposureRiskLevel.fromString(map['riskLevel'] ?? 'low'),
      havsStage: map['havsStage'] ?? 0,
      hadSymptoms: map['hadSymptoms'] ?? false,
      triggerEvent: map['triggerEvent'],
    );
  }
}

/// Risk level enumeration
enum ExposureRiskLevel {
  veryLow,
  low,
  moderate,
  high,
  veryHigh,
  critical;

  static ExposureRiskLevel fromString(String value) {
    return ExposureRiskLevel.values.firstWhere(
      (level) => level.name == value.toLowerCase(),
      orElse: () => ExposureRiskLevel.low,
    );
  }

  String get displayName {
    switch (this) {
      case ExposureRiskLevel.veryLow:
        return 'Very Low';
      case ExposureRiskLevel.low:
        return 'Low';
      case ExposureRiskLevel.moderate:
        return 'Moderate';
      case ExposureRiskLevel.high:
        return 'High';
      case ExposureRiskLevel.veryHigh:
        return 'Very High';
      case ExposureRiskLevel.critical:
        return 'Critical';
    }
  }

  String get description {
    switch (this) {
      case ExposureRiskLevel.veryLow:
        return 'Minimal risk of HAVS development';
      case ExposureRiskLevel.low:
        return 'Low risk - continue monitoring';
      case ExposureRiskLevel.moderate:
        return 'Moderate risk - increased surveillance recommended';
      case ExposureRiskLevel.high:
        return 'High risk - consider job rotation or restrictions';
      case ExposureRiskLevel.veryHigh:
        return 'Very high risk - immediate intervention required';
      case ExposureRiskLevel.critical:
        return 'Critical risk - work restrictions mandatory';
    }
  }

  double get numericValue {
    switch (this) {
      case ExposureRiskLevel.veryLow:
        return 1.0;
      case ExposureRiskLevel.low:
        return 2.0;
      case ExposureRiskLevel.moderate:
        return 3.0;
      case ExposureRiskLevel.high:
        return 4.0;
      case ExposureRiskLevel.veryHigh:
        return 5.0;
      case ExposureRiskLevel.critical:
        return 6.0;
    }
  }
}

/// Exposure trend enumeration
enum ExposureTrend {
  rapidlyDecreasing,
  decreasing,
  stable,
  increasing,
  rapidlyIncreasing;

  String get displayName {
    switch (this) {
      case ExposureTrend.rapidlyDecreasing:
        return 'Rapidly Decreasing';
      case ExposureTrend.decreasing:
        return 'Decreasing';
      case ExposureTrend.stable:
        return 'Stable';
      case ExposureTrend.increasing:
        return 'Increasing';
      case ExposureTrend.rapidlyIncreasing:
        return 'Rapidly Increasing';
    }
  }

  String get description {
    switch (this) {
      case ExposureTrend.rapidlyDecreasing:
        return 'Exposure levels are rapidly decreasing - excellent progress';
      case ExposureTrend.decreasing:
        return 'Exposure levels are decreasing - positive trend';
      case ExposureTrend.stable:
        return 'Exposure levels are stable';
      case ExposureTrend.increasing:
        return 'Exposure levels are increasing - monitor closely';
      case ExposureTrend.rapidlyIncreasing:
        return 'Exposure levels are rapidly increasing - immediate attention required';
    }
  }

  bool get isPositive => this == ExposureTrend.decreasing || this == ExposureTrend.rapidlyDecreasing;
  bool get isNegative => this == ExposureTrend.increasing || this == ExposureTrend.rapidlyIncreasing;
}