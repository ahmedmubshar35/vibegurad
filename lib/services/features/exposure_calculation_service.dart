import 'dart:math' as math;
import 'package:injectable/injectable.dart';

import '../../models/tool/tool.dart';
import '../../models/timer/timer_session.dart';
import '../../enums/exposure_level.dart';

/// Comprehensive exposure calculation service following HSE and OSHA guidelines
/// Implements ISO 5349-1 standards for Hand-Arm Vibration Syndrome (HAVS) assessment
@lazySingleton
class ExposureCalculationService {
  // ISO 5349-1 constants
  static const double _exposureActionValue = 2.5; // m/s² A(8)
  static const double _exposureExceedingValue = 5.0; // m/s² A(8)

  /// Calculate vibration magnitude from raw acceleration values
  /// Using root-sum-of-squares for tri-axial measurements
  double calculateVibrationMagnitude({
    required double x,
    required double y,
    required double z,
  }) {
    return math.sqrt((x * x) + (y * y) + (z * z));
  }

  /// Calculate frequency-weighted vibration magnitude
  /// Applies ISO 5349-1 frequency weighting filters
  double calculateFrequencyWeightedVibration({
    required double rawMagnitude,
    required double frequency,
    String axis = 'combined',
  }) {
    // ISO 5349-1 frequency weighting (Wh for hand-arm vibration)
    // Simplified implementation - in practice would use full filter bank
    double weighting = _getFrequencyWeighting(frequency);
    return rawMagnitude * weighting;
  }

  /// Get frequency weighting factor according to ISO 5349-1
  double _getFrequencyWeighting(double frequency) {
    // ISO 5349-1 frequency weighting curve (approximated)
    if (frequency < 6.3) {
      return math.pow(frequency / 6.3, 0.5).toDouble();
    } else if (frequency <= 1250) {
      return 1.0; // Peak sensitivity region
    } else {
      return math.pow(1250 / frequency, 0.5).toDouble();
    }
  }

  /// Calculate A(8) daily exposure value according to ISO 5349-1
  /// A(8) = sqrt(sum(ai² * ti / T0))
  /// Where ai = vibration magnitude, ti = exposure time, T0 = 8 hours
  double calculateA8DailyExposure({
    required List<ExposureSession> sessions,
  }) {
    if (sessions.isEmpty) return 0.0;

    double sumSquaredExposures = 0.0;
    
    for (final session in sessions) {
      final exposureTimeHours = session.durationMinutes / 60.0;
      final vibrationSquared = session.vibrationMagnitude * session.vibrationMagnitude;
      sumSquaredExposures += vibrationSquared * exposureTimeHours / 8.0;
    }

    return math.sqrt(sumSquaredExposures);
  }

  /// Calculate A(8) from single tool session
  double calculateSingleToolA8({
    required double vibrationLevel,
    required int exposureTimeMinutes,
  }) {
    final exposureTimeHours = exposureTimeMinutes / 60.0;
    final ratio = exposureTimeHours / 8.0; // Normalize to 8-hour reference
    return vibrationLevel * math.sqrt(ratio);
  }

  /// Calculate weekly A(8) exposure
  double calculateWeeklyA8Exposure({
    required List<ExposureSession> weekSessions,
  }) {
    // Group sessions by day
    Map<DateTime, List<ExposureSession>> dailySessions = {};
    
    for (final session in weekSessions) {
      final day = DateTime(session.date.year, session.date.month, session.date.day);
      dailySessions.putIfAbsent(day, () => []).add(session);
    }

    // Calculate daily A(8) values
    List<double> dailyA8Values = [];
    for (final sessions in dailySessions.values) {
      dailyA8Values.add(calculateA8DailyExposure(sessions: sessions));
    }

    // Weekly A(8) is the root-mean-square of daily values
    if (dailyA8Values.isEmpty) return 0.0;
    
    double sumSquared = 0.0;
    for (final a8 in dailyA8Values) {
      sumSquared += a8 * a8;
    }
    
    return math.sqrt(sumSquared / dailyA8Values.length);
  }

  /// Calculate HSE Points-based exposure system
  /// Based on UK HSE guidance for managing hand-arm vibration
  double calculateHSEPoints({
    required double vibrationLevel,
    required int exposureTimeMinutes,
  }) {
    // HSE Points = (vibration level / 2.5)² × (exposure time in minutes / 60)
    final normalizedVibration = vibrationLevel / 2.5;
    final exposureTimeHours = exposureTimeMinutes / 60.0;
    
    return (normalizedVibration * normalizedVibration) * exposureTimeHours;
  }

  /// Calculate daily HSE points from multiple sessions
  double calculateDailyHSEPoints({
    required List<ExposureSession> sessions,
  }) {
    double totalPoints = 0.0;
    
    for (final session in sessions) {
      totalPoints += calculateHSEPoints(
        vibrationLevel: session.vibrationMagnitude,
        exposureTimeMinutes: session.durationMinutes,
      );
    }
    
    return totalPoints;
  }

  /// Calculate required rest period based on exposure
  RestPeriodResult calculateRestPeriod({
    required double currentA8,
    required int exposureTimeMinutes,
    required double vibrationLevel,
  }) {
    // If under action value (2.5 m/s²), no mandatory rest required
    if (currentA8 <= _exposureActionValue) {
      return RestPeriodResult(
        requiredRestMinutes: 0,
        recommendation: 'No mandatory rest required - exposure within safe limits',
        riskLevel: ExposureLevel.low,
      );
    }

    // Calculate time to reach action value
    final safeTimeRemaining = calculateSafeTimeRemaining(
      vibrationLevel: vibrationLevel,
      currentExposureMinutes: exposureTimeMinutes,
    );

    int restMinutes;
    String recommendation;
    ExposureLevel riskLevel;

    if (currentA8 >= _exposureExceedingValue) {
      // Above exposure limit - mandatory immediate rest
      restMinutes = 60; // Minimum 1 hour rest
      recommendation = 'CRITICAL: Exposure limit exceeded. Mandatory 1-hour rest minimum.';
      riskLevel = ExposureLevel.critical;
    } else if (currentA8 >= _exposureActionValue * 1.5) {
      // High exposure - extended rest recommended
      restMinutes = 30;
      recommendation = 'High exposure detected. 30-minute rest recommended.';
      riskLevel = ExposureLevel.high;
    } else {
      // Moderate exposure - standard rest
      restMinutes = 15;
      recommendation = 'Standard 15-minute rest break recommended.';
      riskLevel = ExposureLevel.medium;
    }

    return RestPeriodResult(
      requiredRestMinutes: restMinutes,
      recommendation: recommendation,
      riskLevel: riskLevel,
      safeTimeRemaining: safeTimeRemaining,
    );
  }

  /// Calculate safe remaining exposure time for current day
  int calculateSafeTimeRemaining({
    required double vibrationLevel,
    required int currentExposureMinutes,
    double targetA8 = 2.5, // Default to action value
  }) {
    // Using A(8) formula: A(8) = a × sqrt(t/8)
    // Solve for t: t = 8 × (A(8)/a)²
    
    final targetRatio = targetA8 / vibrationLevel;
    final maxSafeHours = 8.0 * (targetRatio * targetRatio);
    final maxSafeMinutes = (maxSafeHours * 60).round();
    
    final remainingMinutes = maxSafeMinutes - currentExposureMinutes;
    return math.max(0, remainingMinutes);
  }

  /// Forecast exposure for planning purposes
  ExposureForecast forecastExposure({
    required Tool tool,
    required int plannedUsageMinutes,
    required List<ExposureSession> todaySessions,
  }) {
    // Calculate current A(8)
    final currentA8 = calculateA8DailyExposure(sessions: todaySessions);
    
    // Add planned session
    final plannedSession = ExposureSession(
      vibrationMagnitude: tool.vibrationLevel,
      durationMinutes: plannedUsageMinutes,
      date: DateTime.now(),
    );
    
    final allSessions = [...todaySessions, plannedSession];
    final projectedA8 = calculateA8DailyExposure(sessions: allSessions);
    
    // Calculate HSE points
    final currentHSEPoints = calculateDailyHSEPoints(sessions: todaySessions);
    final projectedHSEPoints = calculateDailyHSEPoints(sessions: allSessions);
    
    // Determine risk level
    ExposureLevel riskLevel;
    String recommendation;
    
    if (projectedA8 >= _exposureExceedingValue) {
      riskLevel = ExposureLevel.critical;
      recommendation = 'DANGER: Planned usage will exceed daily exposure limit!';
    } else if (projectedA8 >= _exposureActionValue) {
      riskLevel = ExposureLevel.high;
      recommendation = 'WARNING: Planned usage will exceed action value. Monitor closely.';
    } else if (projectedA8 >= _exposureActionValue * 0.8) {
      riskLevel = ExposureLevel.medium;
      recommendation = 'CAUTION: Approaching action value. Consider reducing exposure.';
    } else {
      riskLevel = ExposureLevel.low;
      recommendation = 'Safe exposure level for planned usage.';
    }
    
    return ExposureForecast(
      currentA8: currentA8,
      projectedA8: projectedA8,
      currentHSEPoints: currentHSEPoints,
      projectedHSEPoints: projectedHSEPoints,
      riskLevel: riskLevel,
      recommendation: recommendation,
      safeTimeRemaining: calculateSafeTimeRemaining(
        vibrationLevel: tool.vibrationLevel,
        currentExposureMinutes: todaySessions.fold<int>(0, (sum, s) => sum + s.durationMinutes),
      ),
    );
  }

  /// Weekly exposure limit tracking
  WeeklyExposureStatus calculateWeeklyExposureStatus({
    required List<ExposureSession> weekSessions,
  }) {
    final weeklyA8 = calculateWeeklyA8Exposure(weekSessions: weekSessions);
    final totalExposureMinutes = weekSessions.fold<int>(0, (sum, s) => sum + s.durationMinutes);
    final totalHSEPoints = calculateDailyHSEPoints(sessions: weekSessions);
    
    // Group by day for daily breakdown
    Map<DateTime, double> dailyA8Values = {};
    Map<DateTime, List<ExposureSession>> dailySessions = {};
    
    for (final session in weekSessions) {
      final day = DateTime(session.date.year, session.date.month, session.date.day);
      dailySessions.putIfAbsent(day, () => []).add(session);
    }
    
    for (final entry in dailySessions.entries) {
      dailyA8Values[entry.key] = calculateA8DailyExposure(sessions: entry.value);
    }
    
    // Determine status
    WeeklyExposureLevel status;
    if (weeklyA8 >= _exposureExceedingValue) {
      status = WeeklyExposureLevel.excessive;
    } else if (weeklyA8 >= _exposureActionValue) {
      status = WeeklyExposureLevel.high;
    } else if (weeklyA8 >= _exposureActionValue * 0.8) {
      status = WeeklyExposureLevel.moderate;
    } else {
      status = WeeklyExposureLevel.acceptable;
    }
    
    return WeeklyExposureStatus(
      weeklyA8: weeklyA8,
      status: status,
      totalExposureMinutes: totalExposureMinutes,
      totalHSEPoints: totalHSEPoints,
      dailyA8Values: dailyA8Values,
      daysExceedingAction: dailyA8Values.values.where((a8) => a8 >= _exposureActionValue).length,
      daysExceedingLimit: dailyA8Values.values.where((a8) => a8 >= _exposureExceedingValue).length,
    );
  }
}

/// Data classes for exposure calculations

class ExposureSession {
  final double vibrationMagnitude;
  final int durationMinutes;
  final DateTime date;
  final String? toolId;

  ExposureSession({
    required this.vibrationMagnitude,
    required this.durationMinutes,
    required this.date,
    this.toolId,
  });

  factory ExposureSession.fromTimerSession(TimerSession session) {
    return ExposureSession(
      vibrationMagnitude: session.tool?.vibrationLevel ?? 0.0,
      durationMinutes: session.totalMinutes,
      date: session.startTime,
      toolId: session.toolId,
    );
  }
}

class RestPeriodResult {
  final int requiredRestMinutes;
  final String recommendation;
  final ExposureLevel riskLevel;
  final int? safeTimeRemaining;

  RestPeriodResult({
    required this.requiredRestMinutes,
    required this.recommendation,
    required this.riskLevel,
    this.safeTimeRemaining,
  });
}

class ExposureForecast {
  final double currentA8;
  final double projectedA8;
  final double currentHSEPoints;
  final double projectedHSEPoints;
  final ExposureLevel riskLevel;
  final String recommendation;
  final int safeTimeRemaining;

  ExposureForecast({
    required this.currentA8,
    required this.projectedA8,
    required this.currentHSEPoints,
    required this.projectedHSEPoints,
    required this.riskLevel,
    required this.recommendation,
    required this.safeTimeRemaining,
  });
}

class WeeklyExposureStatus {
  final double weeklyA8;
  final WeeklyExposureLevel status;
  final int totalExposureMinutes;
  final double totalHSEPoints;
  final Map<DateTime, double> dailyA8Values;
  final int daysExceedingAction;
  final int daysExceedingLimit;

  WeeklyExposureStatus({
    required this.weeklyA8,
    required this.status,
    required this.totalExposureMinutes,
    required this.totalHSEPoints,
    required this.dailyA8Values,
    required this.daysExceedingAction,
    required this.daysExceedingLimit,
  });
}

enum WeeklyExposureLevel {
  acceptable,
  moderate,
  high,
  excessive,
}

extension WeeklyExposureLevelExtension on WeeklyExposureLevel {
  String get displayName {
    switch (this) {
      case WeeklyExposureLevel.acceptable:
        return 'Acceptable';
      case WeeklyExposureLevel.moderate:
        return 'Moderate';
      case WeeklyExposureLevel.high:
        return 'High Risk';
      case WeeklyExposureLevel.excessive:
        return 'Excessive';
    }
  }

  String get description {
    switch (this) {
      case WeeklyExposureLevel.acceptable:
        return 'Weekly exposure within acceptable limits';
      case WeeklyExposureLevel.moderate:
        return 'Weekly exposure approaching action value';
      case WeeklyExposureLevel.high:
        return 'Weekly exposure above action value - increased monitoring required';
      case WeeklyExposureLevel.excessive:
        return 'Weekly exposure above limit - immediate action required';
    }
  }
}