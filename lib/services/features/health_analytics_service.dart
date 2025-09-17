import 'dart:math' as math;
import 'package:injectable/injectable.dart';
import 'package:stacked_services/stacked_services.dart';
import 'package:get_it/get_it.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/health/health_profile.dart';
import '../../models/health/lifetime_exposure.dart';
import '../../models/timer/timer_session.dart';
import '../features/exposure_calculation_service.dart';

@lazySingleton
class HealthAnalyticsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ExposureCalculationService _exposureService = GetIt.instance<ExposureCalculationService>();
  final SnackbarService _snackbarService = GetIt.instance<SnackbarService>();

  // HAVS risk assessment constants based on research
  static const double _baselineRiskScore = 0.0;
  static const double _maxRiskScore = 100.0;
  static const double _criticalThreshold = 80.0;
  static const double _highThreshold = 65.0;
  static const double _moderateThreshold = 40.0;
  static const double _lowThreshold = 20.0;

  /// Calculate comprehensive individual health risk score (0-100)
  Future<double> calculateHealthRiskScore({
    required HealthProfile healthProfile,
    required LifetimeExposure lifetimeExposure,
    required List<SymptomReport> recentSymptoms,
    required List<TimerSession> recentSessions,
  }) async {
    try {
      double totalScore = _baselineRiskScore;

      // 1. Exposure-based risk (35% of total score)
      totalScore += _calculateExposureRisk(lifetimeExposure) * 0.35;

      // 2. Age and demographic risk (15% of total score)
      totalScore += _calculateDemographicRisk(healthProfile) * 0.15;

      // 3. Medical history risk (20% of total score)
      totalScore += _calculateMedicalHistoryRisk(healthProfile) * 0.20;

      // 4. Current symptom risk (20% of total score)
      totalScore += _calculateSymptomRisk(recentSymptoms, healthProfile.havsStage.index) * 0.20;

      // 5. Lifestyle and protective factors (10% of total score)
      totalScore += _calculateLifestyleRisk(healthProfile) * 0.10;

      // Apply trend modifiers
      final trendModifier = _calculateTrendModifier(lifetimeExposure);
      totalScore *= (1.0 + trendModifier);

      // Ensure score stays within bounds
      return math.min(_maxRiskScore, math.max(_baselineRiskScore, totalScore));

    } catch (e) {
      _snackbarService.showSnackbar(
        message: 'Error calculating health risk score: $e',
      );
      return 0.0;
    }
  }

  /// Calculate HAVS-specific risk assessment
  Future<HAVSRiskAssessment> calculateHAVSRiskAssessment({
    required HealthProfile healthProfile,
    required LifetimeExposure lifetimeExposure,
    required List<SymptomReport> symptomHistory,
  }) async {
    try {
      // Calculate time to HAVS onset based on multiple factors
      final onsetProbability = _calculateHAVSOnsetProbability(
        healthProfile, lifetimeExposure, symptomHistory,
      );

      // Calculate projected progression
      final progression = _calculateHAVSProgression(
        healthProfile, lifetimeExposure, symptomHistory,
      );

      // Determine interventions needed
      final interventions = _determineRequiredInterventions(
        healthProfile, lifetimeExposure, onsetProbability,
      );

      return HAVSRiskAssessment(
        workerId: healthProfile.workerId,
        assessmentDate: DateTime.now(),
        currentStage: healthProfile.havsStage.index,
        riskScore: await calculateHealthRiskScore(
          healthProfile: healthProfile,
          lifetimeExposure: lifetimeExposure,
          recentSymptoms: symptomHistory.where((s) => 
            s.reportedAt.isAfter(DateTime.now().subtract(const Duration(days: 90)))).toList(),
          recentSessions: [], // Would be provided in real implementation
        ),
        onsetProbability: onsetProbability,
        projectedProgression: progression,
        recommendedInterventions: interventions,
        nextAssessmentDue: _calculateNextAssessmentDate(onsetProbability.riskLevel),
        confidenceLevel: _calculateAssessmentConfidence(
          healthProfile, lifetimeExposure, symptomHistory,
        ),
      );

    } catch (e) {
      _snackbarService.showSnackbar(
        message: 'Error calculating HAVS risk assessment: $e',
      );
      rethrow;
    }
  }

  /// Calculate exposure-based risk component (0-100)
  double _calculateExposureRisk(LifetimeExposure lifetimeExposure) {
    double exposureScore = 0.0;

    // Cumulative A(8) exposure risk
    final a8Risk = math.min(40.0, lifetimeExposure.totalLifetimeA8 * 2.0); // Max 40 points
    exposureScore += a8Risk;

    // Exposure velocity risk (rate of recent exposure)
    final velocityRisk = math.min(20.0, lifetimeExposure.exposureVelocity * 10.0); // Max 20 points
    exposureScore += velocityRisk;

    // Exposure acceleration risk (increasing/decreasing trend)
    final accelerationRisk = math.min(15.0, lifetimeExposure.exposureAcceleration * 15.0); // Max 15 points
    exposureScore += math.max(0.0, accelerationRisk); // Only positive acceleration increases risk

    // Duration of exposure risk
    final yearsExposed = DateTime.now().difference(
      lifetimeExposure.yearlyBreakdown.keys.isNotEmpty 
        ? DateTime(lifetimeExposure.yearlyBreakdown.keys.reduce(math.min), 1, 1)
        : DateTime.now()
    ).inDays / 365.25;
    final durationRisk = math.min(25.0, yearsExposed * 2.5); // Max 25 points
    exposureScore += durationRisk;

    return math.min(100.0, exposureScore);
  }

  /// Calculate demographic risk factors (0-100)
  double _calculateDemographicRisk(HealthProfile healthProfile) {
    double demoScore = 0.0;

    // Age risk - HAVS risk increases with age
    final age = healthProfile.age;
    if (age >= 50) {
      demoScore += 40.0;
    } else if (age >= 40) {
      demoScore += 25.0;
    } else if (age >= 30) {
      demoScore += 10.0;
    }

    // Gender risk - males typically at higher risk
    if (healthProfile.gender == Gender.male) {
      demoScore += 10.0;
    }

    // Smoking increases vascular risks
    if (healthProfile.smokingStatus) {
      demoScore += 25.0;
    }

    // Alcohol consumption affects circulation
    switch (healthProfile.alcoholConsumption.toLowerCase()) {
      case 'heavy':
        demoScore += 20.0;
        break;
      case 'moderate':
        demoScore += 10.0;
        break;
      case 'light':
        demoScore += 5.0;
        break;
    }

    // Cold climate/exposure increases risk (could be inferred from location)
    // This would need additional data collection

    return math.min(100.0, demoScore);
  }

  /// Calculate medical history risk (0-100)
  double _calculateMedicalHistoryRisk(HealthProfile healthProfile) {
    double medicalScore = 0.0;

    // Pre-existing conditions that increase HAVS risk
    for (final condition in healthProfile.medicalConditions) {
      switch (condition.toLowerCase()) {
        case 'diabetes':
        case 'peripheral vascular disease':
        case 'raynaud\'s disease':
        case 'scleroderma':
        case 'carpal tunnel syndrome':
          medicalScore += 20.0;
          break;
        case 'arthritis':
        case 'hypertension':
        case 'heart disease':
          medicalScore += 10.0;
          break;
        default:
          medicalScore += 5.0; // General health condition
      }
    }

    // Medications that might affect circulation or nerve function
    for (final medication in healthProfile.currentMedications) {
      // This would need a comprehensive medication database
      // For now, assume some common medications increase risk
      if (medication.toLowerCase().contains('beta blocker') ||
          medication.toLowerCase().contains('blood pressure')) {
        medicalScore += 5.0;
      }
    }

    // Family history of HAVS or related conditions
    // This would need additional data collection

    return math.min(100.0, medicalScore);
  }

  /// Calculate symptom-based risk (0-100)
  double _calculateSymptomRisk(List<SymptomReport> symptoms, int currentHavsStage) {
    double symptomScore = 0.0;

    // Current HAVS stage
    symptomScore += currentHavsStage * 20.0; // Max 80 points for stage 4

    if (symptoms.isNotEmpty) {
      // Recent symptom severity
      final recentSymptoms = symptoms.where((s) => 
        s.reportedAt.isAfter(DateTime.now().subtract(const Duration(days: 30)))).toList();

      if (recentSymptoms.isNotEmpty) {
        final avgPainLevel = recentSymptoms.fold<double>(0.0, (sum, s) => sum + s.painLevel) / recentSymptoms.length;
        symptomScore += avgPainLevel * 2.0; // Max 20 points for pain level 10

        // Frequency of symptom reports
        final reportsPerMonth = recentSymptoms.length;
        symptomScore += math.min(15.0, reportsPerMonth * 3.0); // Max 15 points

        // Work interference
        final workInterference = recentSymptoms.where((s) => s.interferesWithWork).length;
        if (workInterference > 0) {
          symptomScore += 15.0;
        }

        // Daily life interference
        final dailyInterference = recentSymptoms.where((s) => s.interferesWithDaily).length;
        if (dailyInterference > 0) {
          symptomScore += 10.0;
        }
      }

      // Progression of symptoms over time
      if (symptoms.length >= 2) {
        final symptomProgression = _analyzeSymptomProgression(symptoms);
        if (symptomProgression > 0) {
          symptomScore += math.min(20.0, symptomProgression * 10.0);
        }
      }
    }

    return math.min(100.0, symptomScore);
  }

  /// Calculate lifestyle risk factors (0-100)
  double _calculateLifestyleRisk(HealthProfile healthProfile) {
    double lifestyleScore = 50.0; // Start at neutral

    // Exercise level (protective factor)
    switch (healthProfile.exerciseLevel.toLowerCase()) {
      case 'none':
        lifestyleScore += 30.0;
        break;
      case 'light':
        lifestyleScore += 10.0;
        break;
      case 'moderate':
        lifestyleScore -= 10.0; // Protective
        break;
      case 'heavy':
        lifestyleScore -= 20.0; // Very protective
        break;
    }

    // Sleep quality
    if (healthProfile.hoursOfSleep < 6) {
      lifestyleScore += 20.0;
    } else if (healthProfile.hoursOfSleep >= 8) {
      lifestyleScore -= 10.0; // Protective
    }

    // Stress level
    switch (healthProfile.stressLevel.toLowerCase()) {
      case 'high':
        lifestyleScore += 25.0;
        break;
      case 'moderate':
        lifestyleScore += 10.0;
        break;
      case 'low':
        lifestyleScore -= 5.0; // Protective
        break;
    }

    // PPE usage (highly protective)
    if (healthProfile.usesPPE) {
      lifestyleScore -= 25.0; // Very protective
    } else {
      lifestyleScore += 15.0; // Increases risk significantly
    }

    return math.min(100.0, math.max(0.0, lifestyleScore));
  }

  /// Calculate trend modifier (-0.2 to +0.3)
  double _calculateTrendModifier(LifetimeExposure lifetimeExposure) {
    final trend = lifetimeExposure.getExposureTrend(6); // 6 month trend
    
    switch (trend) {
      case ExposureTrend.rapidlyDecreasing:
        return -0.15;
      case ExposureTrend.decreasing:
        return -0.05;
      case ExposureTrend.stable:
        return 0.0;
      case ExposureTrend.increasing:
        return 0.10;
      case ExposureTrend.rapidlyIncreasing:
        return 0.25;
    }
  }

  /// Analyze symptom progression over time
  double _analyzeSymptomProgression(List<SymptomReport> symptoms) {
    if (symptoms.length < 2) return 0.0;

    // Sort by date
    final sortedSymptoms = symptoms.toList()
      ..sort((a, b) => a.reportedAt.compareTo(b.reportedAt));

    // Compare recent vs older symptoms
    final recent = sortedSymptoms.take(sortedSymptoms.length ~/ 2).toList();
    final older = sortedSymptoms.skip(sortedSymptoms.length ~/ 2).toList();

    if (recent.isEmpty || older.isEmpty) return 0.0;

    final recentAvgPain = recent.fold<double>(0.0, (sum, s) => sum + s.painLevel) / recent.length;
    final olderAvgPain = older.fold<double>(0.0, (sum, s) => sum + s.painLevel) / older.length;

    // Return positive value if symptoms are worsening
    return (recentAvgPain - olderAvgPain) / 10.0; // Normalize to 0-1 scale
  }

  /// Calculate HAVS onset probability
  HAVSOnsetProbability _calculateHAVSOnsetProbability(
    HealthProfile healthProfile,
    LifetimeExposure lifetimeExposure,
    List<SymptomReport> symptoms,
  ) {
    if (healthProfile.hasHAVSSymptoms || healthProfile.havsStage.index > 0) {
      return HAVSOnsetProbability(
        probabilityPercent: 100.0,
        estimatedTimeToOnset: Duration.zero,
        riskLevel: ExposureRiskLevel.critical,
        confidenceLevel: 95.0,
      );
    }

    // Use epidemiological models for onset prediction
    // This is a simplified version - real implementation would use research-based algorithms

    double onsetProbability = 0.0;
    Duration estimatedTime = const Duration(days: 365 * 20); // Default 20 years

    // Base probability from exposure
    final cumulativeA8 = lifetimeExposure.totalLifetimeA8;
    if (cumulativeA8 > 15.0) {
      onsetProbability = 80.0;
      estimatedTime = Duration(days: (365 * 2).round());
    } else if (cumulativeA8 > 10.0) {
      onsetProbability = 60.0;
      estimatedTime = Duration(days: (365 * 5).round());
    } else if (cumulativeA8 > 5.0) {
      onsetProbability = 30.0;
      estimatedTime = Duration(days: (365 * 10).round());
    } else {
      onsetProbability = 10.0;
    }

    // Adjust for age
    final ageMultiplier = healthProfile.age < 30 ? 0.7 : 
                         healthProfile.age < 40 ? 1.0 :
                         healthProfile.age < 50 ? 1.3 : 1.6;
    onsetProbability *= ageMultiplier;

    // Adjust for risk factors
    if (healthProfile.smokingStatus) onsetProbability *= 1.2;
    if (healthProfile.medicalConditions.isNotEmpty) onsetProbability *= 1.1;
    if (!healthProfile.usesPPE) onsetProbability *= 1.4;

    // Determine risk level
    ExposureRiskLevel riskLevel;
    if (onsetProbability >= 70.0) {
      riskLevel = ExposureRiskLevel.critical;
    } else if (onsetProbability >= 50.0) {
      riskLevel = ExposureRiskLevel.veryHigh;
    } else if (onsetProbability >= 30.0) {
      riskLevel = ExposureRiskLevel.high;
    } else if (onsetProbability >= 15.0) {
      riskLevel = ExposureRiskLevel.moderate;
    } else {
      riskLevel = ExposureRiskLevel.low;
    }

    return HAVSOnsetProbability(
      probabilityPercent: math.min(95.0, onsetProbability),
      estimatedTimeToOnset: estimatedTime,
      riskLevel: riskLevel,
      confidenceLevel: _calculatePredictionConfidence(lifetimeExposure, symptoms),
    );
  }

  /// Calculate HAVS progression prediction
  HAVSProgression _calculateHAVSProgression(
    HealthProfile healthProfile,
    LifetimeExposure lifetimeExposure,
    List<SymptomReport> symptoms,
  ) {
    final currentStage = healthProfile.havsStage.index;
    final projections = <HAVSStageProjection>[];

    // Project progression for each stage
    for (int stage = currentStage + 1; stage <= 4; stage++) {
      final timeToStage = _estimateTimeToStage(
        currentStage, stage, lifetimeExposure, symptoms,
      );
      
      if (timeToStage != null) {
        projections.add(HAVSStageProjection(
          stage: stage,
          estimatedTimeToReach: timeToStage,
          probability: _calculateStageReachProbability(currentStage, stage, lifetimeExposure),
        ));
      }
    }

    return HAVSProgression(
      currentStage: currentStage,
      stageProjections: projections,
      overallTrend: lifetimeExposure.getExposureTrend(12),
    );
  }

  /// Determine required interventions
  List<String> _determineRequiredInterventions(
    HealthProfile healthProfile,
    LifetimeExposure lifetimeExposure,
    HAVSOnsetProbability onsetProbability,
  ) {
    final interventions = <String>[];

    // High-risk interventions
    if (onsetProbability.riskLevel.numericValue >= 4.0) {
      interventions.add('Immediate medical evaluation required');
      interventions.add('Consider job rotation or tool restriction');
      interventions.add('Mandatory PPE usage');
    }

    // Moderate-risk interventions
    if (onsetProbability.riskLevel.numericValue >= 3.0) {
      interventions.add('Increase medical surveillance frequency');
      interventions.add('Implement regular rest breaks');
      interventions.add('Review and optimize tool maintenance');
    }

    // General recommendations
    if (!healthProfile.usesPPE) {
      interventions.add('Implement proper PPE usage');
    }

    if (healthProfile.smokingStatus) {
      interventions.add('Smoking cessation program recommended');
    }

    if (healthProfile.exerciseLevel == 'none') {
      interventions.add('Implement regular exercise program');
    }

    return interventions;
  }

  /// Calculate next assessment date
  DateTime _calculateNextAssessmentDate(ExposureRiskLevel riskLevel) {
    final now = DateTime.now();
    switch (riskLevel) {
      case ExposureRiskLevel.critical:
        return now.add(const Duration(days: 30)); // Monthly
      case ExposureRiskLevel.veryHigh:
        return now.add(const Duration(days: 90)); // Quarterly
      case ExposureRiskLevel.high:
        return now.add(const Duration(days: 180)); // Bi-annually
      case ExposureRiskLevel.moderate:
        return now.add(const Duration(days: 365)); // Annually
      default:
        return now.add(const Duration(days: 730)); // Every 2 years
    }
  }

  /// Calculate assessment confidence level
  double _calculateAssessmentConfidence(
    HealthProfile healthProfile,
    LifetimeExposure lifetimeExposure,
    List<SymptomReport> symptoms,
  ) {
    double confidence = 50.0; // Base confidence

    // Data completeness factors
    if (lifetimeExposure.riskProgressionHistory.length >= 12) {
      confidence += 15.0; // Good historical data
    }

    if (symptoms.length >= 5) {
      confidence += 10.0; // Adequate symptom history
    }

    if (healthProfile.lastHealthAssessment.isAfter(
        DateTime.now().subtract(const Duration(days: 365)))) {
      confidence += 15.0; // Recent medical assessment
    }

    // Experience factors
    final yearsData = DateTime.now().difference(
      lifetimeExposure.yearlyBreakdown.keys.isNotEmpty 
        ? DateTime(lifetimeExposure.yearlyBreakdown.keys.reduce(math.min), 1, 1)
        : DateTime.now()
    ).inDays / 365.25;
    
    if (yearsData >= 5) {
      confidence += 10.0; // Long-term data available
    }

    return math.min(95.0, confidence);
  }

  /// Calculate prediction confidence
  double _calculatePredictionConfidence(
    LifetimeExposure lifetimeExposure,
    List<SymptomReport> symptoms,
  ) {
    double confidence = 40.0; // Base prediction confidence

    if (lifetimeExposure.riskProgressionHistory.length >= 24) {
      confidence += 20.0; // 2+ years of data
    }

    if (symptoms.isNotEmpty) {
      confidence += 15.0; // Symptom data available
    }

    return math.min(90.0, confidence); // Predictions never 100% certain
  }

  /// Estimate time to reach specific HAVS stage
  Duration? _estimateTimeToStage(
    int currentStage,
    int targetStage,
    LifetimeExposure lifetimeExposure,
    List<SymptomReport> symptoms,
  ) {
    if (targetStage <= currentStage) return null;

    // This would use epidemiological data and progression models
    // Simplified implementation
    final progressionRate = lifetimeExposure.exposureVelocity;
    if (progressionRate <= 0) return null;

    final stagestoProgress = targetStage - currentStage;
    final yearsPerStage = math.max(1.0, 5.0 / progressionRate); // Rough estimate
    final totalYears = stagestoProgress * yearsPerStage;

    return Duration(days: (totalYears * 365).round());
  }

  /// Calculate probability of reaching specific stage
  double _calculateStageReachProbability(
    int currentStage,
    int targetStage,
    LifetimeExposure lifetimeExposure,
  ) {
    if (targetStage <= currentStage) return 100.0;

    // Simplified probability model
    final baseProbability = 80.0 / (targetStage - currentStage); // Decreases with distance
    final velocityMultiplier = math.min(2.0, 1.0 + lifetimeExposure.exposureVelocity);
    
    return math.min(95.0, baseProbability * velocityMultiplier);
  }

  /// Get risk level from score
  ExposureRiskLevel getRiskLevelFromScore(double score) {
    if (score >= _criticalThreshold) return ExposureRiskLevel.critical;
    if (score >= _highThreshold) return ExposureRiskLevel.veryHigh;
    if (score >= _moderateThreshold) return ExposureRiskLevel.high;
    if (score >= _lowThreshold) return ExposureRiskLevel.moderate;
    return ExposureRiskLevel.low;
  }
}

/// HAVS risk assessment result
class HAVSRiskAssessment {
  final String workerId;
  final DateTime assessmentDate;
  final int currentStage;
  final double riskScore;
  final HAVSOnsetProbability onsetProbability;
  final HAVSProgression projectedProgression;
  final List<String> recommendedInterventions;
  final DateTime nextAssessmentDue;
  final double confidenceLevel;

  HAVSRiskAssessment({
    required this.workerId,
    required this.assessmentDate,
    required this.currentStage,
    required this.riskScore,
    required this.onsetProbability,
    required this.projectedProgression,
    required this.recommendedInterventions,
    required this.nextAssessmentDue,
    required this.confidenceLevel,
  });
}

/// HAVS onset probability assessment
class HAVSOnsetProbability {
  final double probabilityPercent;
  final Duration estimatedTimeToOnset;
  final ExposureRiskLevel riskLevel;
  final double confidenceLevel;

  HAVSOnsetProbability({
    required this.probabilityPercent,
    required this.estimatedTimeToOnset,
    required this.riskLevel,
    required this.confidenceLevel,
  });
}

/// HAVS progression prediction
class HAVSProgression {
  final int currentStage;
  final List<HAVSStageProjection> stageProjections;
  final ExposureTrend overallTrend;

  HAVSProgression({
    required this.currentStage,
    required this.stageProjections,
    required this.overallTrend,
  });
}

/// Individual stage progression projection
class HAVSStageProjection {
  final int stage;
  final Duration estimatedTimeToReach;
  final double probability;

  HAVSStageProjection({
    required this.stage,
    required this.estimatedTimeToReach,
    required this.probability,
  });
}