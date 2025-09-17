import 'dart:async';
import 'package:injectable/injectable.dart';
import 'package:stacked_services/stacked_services.dart';
import 'package:get_it/get_it.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/health/health_profile.dart';
import '../features/notification_service.dart';
import '../../enums/exposure_level.dart';

@lazySingleton
class HealthQuestionnaireService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = GetIt.instance<NotificationService>();
  final SnackbarService _snackbarService = GetIt.instance<SnackbarService>();

  /// Submit health questionnaire response
  Future<String?> submitQuestionnaire({
    required String workerId,
    required String questionnaireType,
    required Map<String, dynamic> responses,
    String? reviewNotes,
  }) async {
    try {
      // Calculate risk score based on responses
      final riskScore = _calculateRiskScoreFromResponses(responses, questionnaireType);
      
      // Determine if questionnaire should be flagged for review
      final flaggedForReview = _shouldFlagForReview(responses, riskScore, questionnaireType);

      final questionnaire = HealthQuestionnaire(
        workerId: workerId,
        questionnaireType: questionnaireType,
        responses: responses,
        calculatedRiskScore: riskScore,
        flaggedForReview: flaggedForReview,
        reviewNotes: reviewNotes,
        completedAt: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final docRef = await _firestore
          .collection('health_questionnaires')
          .add(questionnaire.toFirestore());

      // Send notifications if flagged for review
      if (flaggedForReview) {
        await _sendReviewAlerts(questionnaire.copyWith(id: docRef.id));
      }

      // Update health profile if this affects current assessment
      await _updateHealthProfileFromQuestionnaire(workerId, questionnaire);

      return docRef.id;

    } catch (e) {
      _snackbarService.showSnackbar(
        message: 'Error submitting health questionnaire: $e',
      );
      return null;
    }
  }

  /// Get questionnaires for a worker
  Stream<List<HealthQuestionnaire>> getWorkerQuestionnaires({
    required String workerId,
    String? questionnaireType,
    int? limit,
  }) {
    Query query = _firestore
        .collection('health_questionnaires')
        .where('workerId', isEqualTo: workerId)
        .orderBy('completedAt', descending: true);

    if (questionnaireType != null) {
      query = query.where('questionnaireType', isEqualTo: questionnaireType);
    }

    if (limit != null) {
      query = query.limit(limit);
    }

    return query.snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => HealthQuestionnaire.fromFirestore(doc.data() as Map<String, dynamic>, doc.id)).toList());
  }

  /// Get questionnaires flagged for review
  Stream<List<HealthQuestionnaire>> getFlaggedQuestionnaires({String? companyId}) {
    Query query = _firestore
        .collection('health_questionnaires')
        .where('flaggedForReview', isEqualTo: true)
        .orderBy('completedAt', descending: true);

    // In a full implementation, would filter by company
    
    return query.snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => HealthQuestionnaire.fromFirestore(doc.data() as Map<String, dynamic>, doc.id)).toList());
  }

  /// Get questionnaire templates
  Map<String, QuestionnaireTemplate> getQuestionnaireTemplates() {
    return {
      'initial': _getInitialAssessmentTemplate(),
      'monthly': _getMonthlyCheckTemplate(),
      'annual': _getAnnualAssessmentTemplate(),
      'symptom_check': _getSymptomCheckTemplate(),
    };
  }

  /// Submit symptom report
  Future<String?> submitSymptomReport({
    required String workerId,
    required Map<String, int> symptomSeverity,
    required List<String> affectedAreas,
    String? triggerActivity,
    required int painLevel,
    required bool interferesWithWork,
    required bool interferesWithDaily,
    String? additionalNotes,
  }) async {
    try {
      final symptomReport = SymptomReport(
        workerId: workerId,
        reportedAt: DateTime.now(),
        symptomSeverity: symptomSeverity,
        affectedAreas: affectedAreas,
        triggerActivity: triggerActivity,
        painLevel: painLevel,
        interferesWithWork: interferesWithWork,
        interferesWithDaily: interferesWithDaily,
        additionalNotes: additionalNotes,
        reviewedByMedical: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final docRef = await _firestore
          .collection('symptom_reports')
          .add(symptomReport.toFirestore());

      // Check if symptoms indicate urgent medical attention needed
      if (_requiresUrgentAttention(symptomReport)) {
        await _sendUrgentSymptomAlert(symptomReport.copyWith(id: docRef.id));
      }

      // Update health profile HAVS stage if symptoms indicate progression
      await _updateHealthProfileFromSymptoms(workerId, symptomReport);

      return docRef.id;

    } catch (e) {
      _snackbarService.showSnackbar(
        message: 'Error submitting symptom report: $e',
      );
      return null;
    }
  }

  /// Get symptom reports for a worker
  Stream<List<SymptomReport>> getWorkerSymptomReports({
    required String workerId,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  }) {
    Query query = _firestore
        .collection('symptom_reports')
        .where('workerId', isEqualTo: workerId)
        .orderBy('reportedAt', descending: true);

    if (startDate != null) {
      query = query.where('reportedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
    }

    if (endDate != null) {
      query = query.where('reportedAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
    }

    if (limit != null) {
      query = query.limit(limit);
    }

    return query.snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => SymptomReport.fromFirestore(doc.data() as Map<String, dynamic>, doc.id)).toList());
  }

  /// Get symptom trend analysis
  Future<SymptomTrendAnalysis> getSymptomTrendAnalysis(String workerId, int months) async {
    try {
      final endDate = DateTime.now();
      final startDate = endDate.subtract(Duration(days: months * 30));
      
      final reportsStream = getWorkerSymptomReports(
        workerId: workerId,
        startDate: startDate,
        endDate: endDate,
      );
      
      final reports = await reportsStream.first;
      
      if (reports.isEmpty) {
        return SymptomTrendAnalysis.empty(workerId);
      }

      // Calculate trends
      final painLevelTrend = _calculatePainLevelTrend(reports);
      final frequencyTrend = _calculateReportingFrequencyTrend(reports, months);
      final severityTrend = _calculateSymptomSeverityTrend(reports);
      final functionalImpactTrend = _calculateFunctionalImpactTrend(reports);
      
      return SymptomTrendAnalysis(
        workerId: workerId,
        analysisStartDate: startDate,
        analysisEndDate: endDate,
        totalReports: reports.length,
        averagePainLevel: reports.fold<double>(0.0, (sum, r) => sum + r.painLevel) / reports.length,
        painLevelTrend: painLevelTrend,
        reportingFrequency: reports.length / months,
        frequencyTrend: frequencyTrend,
        mostCommonSymptoms: _getMostCommonSymptoms(reports),
        mostAffectedAreas: _getMostAffectedAreas(reports),
        severityTrend: severityTrend,
        functionalImpactTrend: functionalImpactTrend,
        recommendations: _generateSymptomRecommendations(reports, painLevelTrend, frequencyTrend),
      );

    } catch (e) {
      _snackbarService.showSnackbar(
        message: 'Error analyzing symptom trends: $e',
      );
      return SymptomTrendAnalysis.empty(workerId);
    }
  }

  // Private helper methods

  double _calculateRiskScoreFromResponses(Map<String, dynamic> responses, String questionnaireType) {
    double score = 0.0;
    
    switch (questionnaireType) {
      case 'initial':
        score = _calculateInitialAssessmentScore(responses);
        break;
      case 'monthly':
        score = _calculateMonthlyCheckScore(responses);
        break;
      case 'annual':
        score = _calculateAnnualAssessmentScore(responses);
        break;
      case 'symptom_check':
        score = _calculateSymptomCheckScore(responses);
        break;
    }
    
    return score.clamp(0.0, 100.0);
  }

  double _calculateInitialAssessmentScore(Map<String, dynamic> responses) {
    double score = 0.0;
    
    // Age factor
    final age = responses['age'] as int? ?? 0;
    if (age > 50) score += 15.0;
    else if (age > 40) score += 10.0;
    else if (age > 30) score += 5.0;
    
    // Previous vibration exposure
    if (responses['previousVibrationExposure'] == true) score += 20.0;
    
    // Medical conditions
    final conditions = responses['medicalConditions'] as List<String>? ?? [];
    score += conditions.length * 5.0;
    
    // Smoking
    if (responses['smoker'] == true) score += 15.0;
    
    // Exercise level
    final exercise = responses['exerciseLevel'] as String? ?? 'moderate';
    if (exercise == 'none') score += 10.0;
    else if (exercise == 'heavy') score -= 5.0;
    
    return score;
  }

  double _calculateMonthlyCheckScore(Map<String, dynamic> responses) {
    double score = 0.0;
    
    // Symptom presence
    if (responses['hasSymptoms'] == true) score += 30.0;
    
    // Symptom severity (0-10 scale)
    final severity = responses['symptomSeverity'] as int? ?? 0;
    score += severity * 3.0;
    
    // Work interference
    if (responses['interferesWithWork'] == true) score += 25.0;
    
    // Daily life interference
    if (responses['interferesWithDaily'] == true) score += 20.0;
    
    // Sleep affected
    if (responses['sleepAffected'] == true) score += 15.0;
    
    return score;
  }

  double _calculateAnnualAssessmentScore(Map<String, dynamic> responses) {
    // Combine initial assessment factors with current status
    double score = _calculateInitialAssessmentScore(responses);
    score += _calculateMonthlyCheckScore(responses);
    
    // Additional annual factors
    if (responses['symptomsWorsening'] == true) score += 20.0;
    if (responses['newMedicalConditions'] == true) score += 15.0;
    
    return score;
  }

  double _calculateSymptomCheckScore(Map<String, dynamic> responses) {
    return _calculateMonthlyCheckScore(responses);
  }

  bool _shouldFlagForReview(Map<String, dynamic> responses, double riskScore, String questionnaireType) {
    // High risk score
    if (riskScore >= 60.0) return true;
    
    // Specific red flags
    if (responses['hasSymptoms'] == true && responses['interferesWithWork'] == true) return true;
    if (responses['symptomSeverity'] != null && (responses['symptomSeverity'] as int) >= 7) return true;
    if (responses['symptomsWorsening'] == true) return true;
    
    return false;
  }

  Future<void> _sendReviewAlerts(HealthQuestionnaire questionnaire) async {
    await _notificationService.showSafetyWarning(
      title: '📋 Health Questionnaire Review Required',
      body: 'Worker health questionnaire flagged for medical review. Risk score: ${questionnaire.calculatedRiskScore.toStringAsFixed(1)}',
      level: ExposureLevel.high,
      payload: {
        'type': 'health_review',
        'questionnaireId': questionnaire.id ?? '',
        'workerId': questionnaire.workerId,
      },
    );
  }

  Future<void> _updateHealthProfileFromQuestionnaire(String workerId, HealthQuestionnaire questionnaire) async {
    // This would update the health profile based on questionnaire responses
    // Implementation would depend on specific business logic
  }

  bool _requiresUrgentAttention(SymptomReport report) {
    // Check for urgent symptoms
    if (report.painLevel >= 8) return true;
    if (report.symptomSeverity.values.any((severity) => severity >= 8)) return true;
    if (report.interferesWithWork && report.interferesWithDaily) return true;
    
    return false;
  }

  Future<void> _sendUrgentSymptomAlert(SymptomReport report) async {
    await _notificationService.showSafetyWarning(
      title: '🚨 Urgent Symptom Report',
      body: 'Worker reported severe symptoms (pain level: ${report.painLevel}/10). Immediate medical attention may be required.',
      level: ExposureLevel.critical,
      payload: {
        'type': 'urgent_symptoms',
        'reportId': report.id ?? '',
        'workerId': report.workerId,
      },
    );
  }

  Future<void> _updateHealthProfileFromSymptoms(String workerId, SymptomReport report) async {
    // Update HAVS stage based on symptom severity
    // This would integrate with health profile service
  }

  // Symptom trend analysis methods
  
  SymptomTrend _calculatePainLevelTrend(List<SymptomReport> reports) {
    if (reports.length < 2) return SymptomTrend.stable;
    
    final sortedReports = reports.toList()..sort((a, b) => a.reportedAt.compareTo(b.reportedAt));
    
    final recentAvg = sortedReports.take(sortedReports.length ~/ 2).fold<double>(
      0.0, (sum, r) => sum + r.painLevel) / (sortedReports.length ~/ 2);
    final olderAvg = sortedReports.skip(sortedReports.length ~/ 2).fold<double>(
      0.0, (sum, r) => sum + r.painLevel) / (sortedReports.length - sortedReports.length ~/ 2);
    
    final change = recentAvg - olderAvg;
    if (change > 2.0) return SymptomTrend.worsening;
    if (change < -2.0) return SymptomTrend.improving;
    return SymptomTrend.stable;
  }

  SymptomTrend _calculateReportingFrequencyTrend(List<SymptomReport> reports, int months) {
    if (reports.length < 4) return SymptomTrend.stable;
    
    final halfwayPoint = DateTime.now().subtract(Duration(days: months * 15)); // Halfway through period
    final recentReports = reports.where((r) => r.reportedAt.isAfter(halfwayPoint)).length;
    final olderReports = reports.length - recentReports;
    
    if (recentReports > olderReports * 1.5) return SymptomTrend.worsening;
    if (recentReports < olderReports * 0.5) return SymptomTrend.improving;
    return SymptomTrend.stable;
  }

  SymptomTrend _calculateSymptomSeverityTrend(List<SymptomReport> reports) {
    if (reports.length < 2) return SymptomTrend.stable;
    
    final recentSeverity = reports.take(reports.length ~/ 2).fold<double>(0.0, (sum, r) => 
        sum + r.symptomSeverity.values.fold<double>(0.0, (s, v) => s + v)) / (reports.length ~/ 2);
    final olderSeverity = reports.skip(reports.length ~/ 2).fold<double>(0.0, (sum, r) => 
        sum + r.symptomSeverity.values.fold<double>(0.0, (s, v) => s + v)) / (reports.length - reports.length ~/ 2);
    
    final change = recentSeverity - olderSeverity;
    if (change > 10.0) return SymptomTrend.worsening;
    if (change < -10.0) return SymptomTrend.improving;
    return SymptomTrend.stable;
  }

  SymptomTrend _calculateFunctionalImpactTrend(List<SymptomReport> reports) {
    if (reports.length < 2) return SymptomTrend.stable;
    
    final recentImpact = reports.take(reports.length ~/ 2).where(
        (r) => r.interferesWithWork || r.interferesWithDaily).length;
    final olderImpact = reports.skip(reports.length ~/ 2).where(
        (r) => r.interferesWithWork || r.interferesWithDaily).length;
    
    if (recentImpact > olderImpact) return SymptomTrend.worsening;
    if (recentImpact < olderImpact) return SymptomTrend.improving;
    return SymptomTrend.stable;
  }

  List<String> _getMostCommonSymptoms(List<SymptomReport> reports) {
    final symptomCounts = <String, int>{};
    
    for (final report in reports) {
      for (final symptom in report.symptomSeverity.keys) {
        symptomCounts[symptom] = (symptomCounts[symptom] ?? 0) + 1;
      }
    }
    
    final sortedSymptoms = symptomCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return sortedSymptoms.take(5).map((e) => e.key).toList();
  }

  List<String> _getMostAffectedAreas(List<SymptomReport> reports) {
    final areaCounts = <String, int>{};
    
    for (final report in reports) {
      for (final area in report.affectedAreas) {
        areaCounts[area] = (areaCounts[area] ?? 0) + 1;
      }
    }
    
    final sortedAreas = areaCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return sortedAreas.take(5).map((e) => e.key).toList();
  }

  List<String> _generateSymptomRecommendations(
    List<SymptomReport> reports,
    SymptomTrend painTrend,
    SymptomTrend frequencyTrend,
  ) {
    final recommendations = <String>[];
    
    if (painTrend == SymptomTrend.worsening) {
      recommendations.add('Pain levels are increasing - consider medical evaluation');
    }
    
    if (frequencyTrend == SymptomTrend.worsening) {
      recommendations.add('Symptom reporting frequency increasing - review work practices');
    }
    
    final recentReports = reports.take(5).toList();
    if (recentReports.any((r) => r.interferesWithWork)) {
      recommendations.add('Symptoms affecting work performance - consider job modifications');
    }
    
    if (recentReports.any((r) => r.painLevel >= 7)) {
      recommendations.add('High pain levels reported - medical attention recommended');
    }
    
    if (recommendations.isEmpty) {
      recommendations.add('Continue current monitoring and prevention measures');
    }
    
    return recommendations;
  }

  // Questionnaire templates

  QuestionnaireTemplate _getInitialAssessmentTemplate() {
    return QuestionnaireTemplate(
      id: 'initial',
      title: 'Initial Health Assessment',
      description: 'Baseline health assessment for new workers',
      questions: [
        QuestionnaireQuestion(
          id: 'age',
          question: 'What is your age?',
          type: QuestionType.number,
          required: true,
        ),
        QuestionnaireQuestion(
          id: 'previousVibrationExposure',
          question: 'Have you previously worked with vibrating tools or machinery?',
          type: QuestionType.yesNo,
          required: true,
        ),
        QuestionnaireQuestion(
          id: 'medicalConditions',
          question: 'Do you have any of the following medical conditions?',
          type: QuestionType.multipleChoice,
          options: ['Diabetes', 'Heart Disease', 'Arthritis', 'Carpal Tunnel', 'None'],
          required: true,
        ),
        QuestionnaireQuestion(
          id: 'smoker',
          question: 'Do you currently smoke?',
          type: QuestionType.yesNo,
          required: true,
        ),
        QuestionnaireQuestion(
          id: 'exerciseLevel',
          question: 'What is your typical exercise level?',
          type: QuestionType.singleChoice,
          options: ['None', 'Light', 'Moderate', 'Heavy'],
          required: true,
        ),
      ],
    );
  }

  QuestionnaireTemplate _getMonthlyCheckTemplate() {
    return QuestionnaireTemplate(
      id: 'monthly',
      title: 'Monthly Health Check',
      description: 'Monthly symptom and health status check',
      questions: [
        QuestionnaireQuestion(
          id: 'hasSymptoms',
          question: 'Have you experienced any tingling, numbness, or pain in your hands, wrists, or arms this month?',
          type: QuestionType.yesNo,
          required: true,
        ),
        QuestionnaireQuestion(
          id: 'symptomSeverity',
          question: 'If yes, rate the severity of your symptoms (0 = no symptoms, 10 = severe)',
          type: QuestionType.scale,
          scaleMin: 0,
          scaleMax: 10,
          required: false,
        ),
        QuestionnaireQuestion(
          id: 'interferesWithWork',
          question: 'Do these symptoms interfere with your work?',
          type: QuestionType.yesNo,
          required: false,
        ),
        QuestionnaireQuestion(
          id: 'interferesWithDaily',
          question: 'Do these symptoms interfere with daily activities?',
          type: QuestionType.yesNo,
          required: false,
        ),
        QuestionnaireQuestion(
          id: 'sleepAffected',
          question: 'Do these symptoms affect your sleep?',
          type: QuestionType.yesNo,
          required: false,
        ),
      ],
    );
  }

  QuestionnaireTemplate _getAnnualAssessmentTemplate() {
    return QuestionnaireTemplate(
      id: 'annual',
      title: 'Annual Health Assessment',
      description: 'Comprehensive annual health review',
      questions: [
        // Combine questions from initial and monthly assessments
        ...(_getInitialAssessmentTemplate().questions),
        ...(_getMonthlyCheckTemplate().questions),
        QuestionnaireQuestion(
          id: 'symptomsWorsening',
          question: 'Have your symptoms gotten worse over the past year?',
          type: QuestionType.yesNo,
          required: true,
        ),
        QuestionnaireQuestion(
          id: 'newMedicalConditions',
          question: 'Have you been diagnosed with any new medical conditions this year?',
          type: QuestionType.yesNo,
          required: true,
        ),
      ],
    );
  }

  QuestionnaireTemplate _getSymptomCheckTemplate() {
    return QuestionnaireTemplate(
      id: 'symptom_check',
      title: 'Symptom Check',
      description: 'Quick symptom assessment',
      questions: _getMonthlyCheckTemplate().questions,
    );
  }
}

// Data models for questionnaire system

class QuestionnaireTemplate {
  final String id;
  final String title;
  final String description;
  final List<QuestionnaireQuestion> questions;

  QuestionnaireTemplate({
    required this.id,
    required this.title,
    required this.description,
    required this.questions,
  });
}

class QuestionnaireQuestion {
  final String id;
  final String question;
  final QuestionType type;
  final bool required;
  final List<String>? options;
  final int? scaleMin;
  final int? scaleMax;

  QuestionnaireQuestion({
    required this.id,
    required this.question,
    required this.type,
    required this.required,
    this.options,
    this.scaleMin,
    this.scaleMax,
  });
}

enum QuestionType {
  yesNo,
  singleChoice,
  multipleChoice,
  number,
  text,
  scale,
}

class SymptomTrendAnalysis {
  final String workerId;
  final DateTime analysisStartDate;
  final DateTime analysisEndDate;
  final int totalReports;
  final double averagePainLevel;
  final SymptomTrend painLevelTrend;
  final double reportingFrequency;
  final SymptomTrend frequencyTrend;
  final List<String> mostCommonSymptoms;
  final List<String> mostAffectedAreas;
  final SymptomTrend severityTrend;
  final SymptomTrend functionalImpactTrend;
  final List<String> recommendations;

  SymptomTrendAnalysis({
    required this.workerId,
    required this.analysisStartDate,
    required this.analysisEndDate,
    required this.totalReports,
    required this.averagePainLevel,
    required this.painLevelTrend,
    required this.reportingFrequency,
    required this.frequencyTrend,
    required this.mostCommonSymptoms,
    required this.mostAffectedAreas,
    required this.severityTrend,
    required this.functionalImpactTrend,
    required this.recommendations,
  });

  factory SymptomTrendAnalysis.empty(String workerId) {
    final now = DateTime.now();
    return SymptomTrendAnalysis(
      workerId: workerId,
      analysisStartDate: now,
      analysisEndDate: now,
      totalReports: 0,
      averagePainLevel: 0.0,
      painLevelTrend: SymptomTrend.stable,
      reportingFrequency: 0.0,
      frequencyTrend: SymptomTrend.stable,
      mostCommonSymptoms: [],
      mostAffectedAreas: [],
      severityTrend: SymptomTrend.stable,
      functionalImpactTrend: SymptomTrend.stable,
      recommendations: ['No symptom data available'],
    );
  }
}

enum SymptomTrend {
  improving,
  stable,
  worsening;

  String get displayName {
    switch (this) {
      case SymptomTrend.improving:
        return 'Improving';
      case SymptomTrend.stable:
        return 'Stable';
      case SymptomTrend.worsening:
        return 'Worsening';
    }
  }

  String get description {
    switch (this) {
      case SymptomTrend.improving:
        return 'Symptoms are showing improvement over time';
      case SymptomTrend.stable:
        return 'Symptoms remain stable with no significant changes';
      case SymptomTrend.worsening:
        return 'Symptoms are worsening and require attention';
    }
  }
}