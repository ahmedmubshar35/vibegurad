import 'dart:async';
import 'package:injectable/injectable.dart';
import 'package:stacked_services/stacked_services.dart';
import 'package:get_it/get_it.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/health/health_profile.dart';
import '../../models/health/lifetime_exposure.dart';
import '../features/notification_service.dart';
import '../core/notification_manager.dart';
import '../../enums/exposure_level.dart';

@lazySingleton
class MedicalExaminationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = GetIt.instance<NotificationService>();
  final SnackbarService _snackbarService = GetIt.instance<SnackbarService>();
  
  SharedPreferences? _prefs;
  Timer? _reminderTimer;

  // Examination frequency constants (in months)
  static const int baselineExamFrequency = 12; // Annual for low risk
  static const int moderateRiskFrequency = 6;  // Bi-annual for moderate risk
  static const int highRiskFrequency = 3;      // Quarterly for high risk
  static const int criticalRiskFrequency = 1;   // Monthly for critical risk

  MedicalExaminationService();

  /// Initialize the service
  Future<void> initialize() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      await _scheduleReminderChecks();
    } catch (e) {
      NotificationManager().showError('Failed to initialize medical examination service: $e');
    }
  }

  /// Schedule a medical examination
  Future<String?> scheduleMedicalExamination({
    required String workerId,
    required DateTime scheduledDate,
    required String examinationType,
    String? facilityName,
    String? examinerName,
    String? notes,
  }) async {
    try {
      final examination = MedicalExamination(
        workerId: workerId,
        examinationDate: scheduledDate,
        examinerName: examinerName ?? '',
        facilityName: facilityName ?? '',
        examinationType: examinationType,
        vitalSigns: {},
        neurologyTests: {},
        circulationTests: {},
        havsStageAssessment: 0,
        havsProgression: false,
        recommendations: [],
        fitForWork: true,
        restrictionsRecommended: false,
        workRestrictions: [],
        attachmentUrls: [],
        overallNotes: notes ?? '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final docRef = await _firestore
          .collection('medical_examinations')
          .add(examination.toFirestore());

      // Update health profile with next exam date
      await _updateNextExamDate(workerId, scheduledDate);

      return docRef.id;

    } catch (e) {
      NotificationManager().showSuccess('Error scheduling medical examination: $e');
      return null;
    }
  }

  /// Complete a medical examination with results
  Future<void> completeMedicalExamination({
    required String examinationId,
    required Map<String, dynamic> vitalSigns,
    required Map<String, dynamic> neurologyTests,
    required Map<String, dynamic> circulationTests,
    required int havsStageAssessment,
    required bool havsProgression,
    required List<String> recommendations,
    required bool fitForWork,
    required bool restrictionsRecommended,
    List<String>? workRestrictions,
    DateTime? nextExamDue,
    String? diagnosticCodes,
    List<String>? attachmentUrls,
    String? overallNotes,
  }) async {
    try {
      final updateData = {
        'vitalSigns': vitalSigns,
        'neurologyTests': neurologyTests,
        'circulationTests': circulationTests,
        'havsStageAssessment': havsStageAssessment,
        'havsProgression': havsProgression,
        'recommendations': recommendations,
        'fitForWork': fitForWork,
        'restrictionsRecommended': restrictionsRecommended,
        'workRestrictions': workRestrictions ?? [],
        'nextExamDue': nextExamDue != null ? Timestamp.fromDate(nextExamDue) : null,
        'diagnosticCodes': diagnosticCodes,
        'attachmentUrls': attachmentUrls ?? [],
        'overallNotes': overallNotes ?? '',
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore
          .collection('medical_examinations')
          .doc(examinationId)
          .update(updateData);

      // Get examination to update health profile
      final examDoc = await _firestore
          .collection('medical_examinations')
          .doc(examinationId)
          .get();

      if (examDoc.exists) {
        final examination = MedicalExamination.fromFirestore(examDoc.data()!, examDoc.id);
        await _updateHealthProfileFromExamination(examination);
        
        // Schedule next examination based on risk level
        if (nextExamDue != null) {
          await _updateNextExamDate(examination.workerId, nextExamDue);
        }

        // Send notifications if restrictions or concerns identified
        if (restrictionsRecommended || !fitForWork || havsProgression) {
          await _sendExaminationAlerts(examination);
        }
      }

      NotificationManager().showSuccess('Medical examination completed successfully');

    } catch (e) {
      NotificationManager().showSuccess('Error completing medical examination: $e');
    }
  }

  /// Get medical examinations for a worker
  Stream<List<MedicalExamination>> getWorkerExaminations({
    required String workerId,
    int? limit,
  }) {
    Query query = _firestore
        .collection('medical_examinations')
        .where('workerId', isEqualTo: workerId)
        .orderBy('examinationDate', descending: true);

    if (limit != null) {
      query = query.limit(limit);
    }

    return query.snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => MedicalExamination.fromFirestore(doc.data() as Map<String, dynamic>, doc.id)).toList());
  }

  /// Get workers with overdue medical examinations
  Future<List<WorkerExaminationStatus>> getOverdueExaminations({String? companyId}) async {
    try {
      Query query = _firestore.collection('health_profiles');
      
      // In a full implementation, would filter by company
      
      final profilesSnapshot = await query.get();
      final overdueWorkers = <WorkerExaminationStatus>[];

      for (final doc in profilesSnapshot.docs) {
        final profile = HealthProfile.fromFirestore(doc.data() as Map<String, dynamic>, doc.id);
        
        if (profile.isMedicalExamOverdue) {
          final daysPastDue = profile.daysUntilMedicalExam != null 
              ? -profile.daysUntilMedicalExam! 
              : 0;
          
          overdueWorkers.add(WorkerExaminationStatus(
            workerId: profile.workerId,
            workerName: '${profile.workerId}', // Would get actual name from user service
            lastExamDate: profile.lastHealthAssessment,
            nextExamDue: profile.nextMedicalExamDue,
            daysPastDue: daysPastDue,
            riskLevel: _getRiskLevelFromHealthProfile(profile),
            havsStage: profile.havsStage.index,
            hasSymptoms: profile.hasHAVSSymptoms,
          ));
        }
      }

      return overdueWorkers;

    } catch (e) {
      NotificationManager().showSuccess('Error retrieving overdue examinations: $e');
      return [];
    }
  }

  /// Calculate recommended examination frequency based on risk
  int getRecommendedExaminationFrequency(ExposureRiskLevel riskLevel) {
    switch (riskLevel) {
      case ExposureRiskLevel.veryLow:
      case ExposureRiskLevel.low:
        return baselineExamFrequency;
      case ExposureRiskLevel.moderate:
        return moderateRiskFrequency;
      case ExposureRiskLevel.high:
      case ExposureRiskLevel.veryHigh:
        return highRiskFrequency;
      case ExposureRiskLevel.critical:
        return criticalRiskFrequency;
    }
  }

  /// Schedule periodic reminder checks
  Future<void> _scheduleReminderChecks() async {
    _reminderTimer?.cancel();
    
    // Check daily for overdue examinations
    _reminderTimer = Timer.periodic(
      const Duration(days: 1),
      (timer) => _checkOverdueExaminations(),
    );

    // Also check immediately
    await _checkOverdueExaminations();
  }

  /// Check for overdue examinations and send reminders
  Future<void> _checkOverdueExaminations() async {
    try {
      final overdueWorkers = await getOverdueExaminations();
      
      for (final worker in overdueWorkers) {
        await _sendOverdueExaminationReminder(worker);
      }

      // Also check for upcoming examinations (within 30 days)
      await _checkUpcomingExaminations();

    } catch (e) {
      // Silent fail for background checks
    }
  }

  /// Check for upcoming examinations
  Future<void> _checkUpcomingExaminations() async {
    try {
      final in30Days = DateTime.now().add(const Duration(days: 30));
      final in7Days = DateTime.now().add(const Duration(days: 7));

      final profilesSnapshot = await _firestore.collection('health_profiles').get();

      for (final doc in profilesSnapshot.docs) {
        final profile = HealthProfile.fromFirestore(doc.data() as Map<String, dynamic>, doc.id);
        
        if (profile.nextMedicalExamDue != null) {
          final daysUntilExam = profile.daysUntilMedicalExam ?? 0;
          
          if (daysUntilExam <= 7 && daysUntilExam > 0) {
            await _sendUpcomingExaminationReminder(profile, urgent: true);
          } else if (daysUntilExam <= 30 && daysUntilExam > 7) {
            await _sendUpcomingExaminationReminder(profile, urgent: false);
          }
        }
      }

    } catch (e) {
      // Silent fail for background checks
    }
  }

  /// Send overdue examination reminder
  Future<void> _sendOverdueExaminationReminder(WorkerExaminationStatus worker) async {
    await _notificationService.showSafetyWarning(
      title: '🏥 Medical Examination OVERDUE',
      body: 'Worker medical examination is ${worker.daysPastDue} days overdue. '
            'Risk level: ${worker.riskLevel.displayName}. Schedule immediately.',
      level: ExposureLevel.critical,
      payload: {
        'type': 'medical_exam_overdue',
        'workerId': worker.workerId,
        'daysPastDue': worker.daysPastDue.toString(),
      },
    );
  }

  /// Send upcoming examination reminder
  Future<void> _sendUpcomingExaminationReminder(HealthProfile profile, {required bool urgent}) async {
    final daysUntil = profile.daysUntilMedicalExam ?? 0;
    final level = urgent ? ExposureLevel.high : ExposureLevel.medium;
    final urgencyText = urgent ? 'URGENT: ' : '';

    await _notificationService.showSafetyWarning(
      title: '📅 ${urgencyText}Medical Examination Due Soon',
      body: 'Worker medical examination due in $daysUntil days. '
            'Current HAVS stage: ${profile.havsStage.index}. Please schedule appointment.',
      level: level,
      payload: {
        'type': 'medical_exam_upcoming',
        'workerId': profile.workerId,
        'daysUntil': daysUntil.toString(),
      },
    );
  }

  /// Update health profile from examination results
  Future<void> _updateHealthProfileFromExamination(MedicalExamination examination) async {
    try {
      final profileQuery = await _firestore
          .collection('health_profiles')
          .where('workerId', isEqualTo: examination.workerId)
          .limit(1)
          .get();

      if (profileQuery.docs.isNotEmpty) {
        final profileDoc = profileQuery.docs.first;
        
        // Update health profile with examination results
        await profileDoc.reference.update({
          'havsStage': examination.havsStageAssessment,
          'hasHAVSSymptoms': examination.havsStageAssessment > 0,
          'lastHealthAssessment': Timestamp.fromDate(examination.examinationDate),
          'nextMedicalExamDue': examination.nextExamDue != null 
              ? Timestamp.fromDate(examination.nextExamDue!) 
              : null,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

    } catch (e) {
      NotificationManager().showSuccess('Error updating health profile from examination: $e');
    }
  }

  /// Update next examination date in health profile
  Future<void> _updateNextExamDate(String workerId, DateTime nextExamDate) async {
    try {
      final profileQuery = await _firestore
          .collection('health_profiles')
          .where('workerId', isEqualTo: workerId)
          .limit(1)
          .get();

      if (profileQuery.docs.isNotEmpty) {
        await profileQuery.docs.first.reference.update({
          'nextMedicalExamDue': Timestamp.fromDate(nextExamDate),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

    } catch (e) {
      NotificationManager().showSuccess('Error updating next exam date: $e');
    }
  }

  /// Send examination alerts for concerning results
  Future<void> _sendExaminationAlerts(MedicalExamination examination) async {
    if (!examination.fitForWork) {
      await _notificationService.showSafetyWarning(
        title: '🚨 Worker Not Fit for Work',
        body: 'Medical examination indicates worker is not fit for work. '
              'Immediate action required.',
        level: ExposureLevel.critical,
        payload: {
          'type': 'not_fit_for_work',
          'workerId': examination.workerId,
          'examinationId': examination.id ?? '',
        },
      );
    }

    if (examination.restrictionsRecommended) {
      await _notificationService.showSafetyWarning(
        title: '⚠️ Work Restrictions Recommended',
        body: 'Medical examination recommends work restrictions. '
              'Review and implement restrictions immediately.',
        level: ExposureLevel.high,
        payload: {
          'type': 'work_restrictions',
          'workerId': examination.workerId,
          'examinationId': examination.id ?? '',
        },
      );
    }

    if (examination.havsProgression) {
      await _notificationService.showSafetyWarning(
        title: '📈 HAVS Progression Detected',
        body: 'Medical examination shows HAVS progression to stage ${examination.havsStageAssessment}. '
              'Enhanced monitoring required.',
        level: ExposureLevel.high,
        payload: {
          'type': 'havs_progression',
          'workerId': examination.workerId,
          'newStage': examination.havsStageAssessment.toString(),
        },
      );
    }
  }

  /// Get risk level from health profile
  ExposureRiskLevel _getRiskLevelFromHealthProfile(HealthProfile profile) {
    // Simplified risk assessment based on HAVS stage and symptoms
    if (profile.havsStage.index >= 3) return ExposureRiskLevel.critical;
    if (profile.havsStage.index >= 2) return ExposureRiskLevel.high;
    if (profile.havsStage.index >= 1 || profile.hasHAVSSymptoms) return ExposureRiskLevel.moderate;
    return ExposureRiskLevel.low;
  }

  /// Generate examination report
  Future<ExaminationReport> generateExaminationReport({
    required String workerId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      Query query = _firestore
          .collection('medical_examinations')
          .where('workerId', isEqualTo: workerId)
          .orderBy('examinationDate', descending: true);

      if (startDate != null) {
        query = query.where('examinationDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }

      if (endDate != null) {
        query = query.where('examinationDate', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
      }

      final examinationsSnapshot = await query.get();
      final examinations = examinationsSnapshot.docs
          .map((doc) => MedicalExamination.fromFirestore(doc.data() as Map<String, dynamic>, doc.id))
          .toList();

      return ExaminationReport(
        workerId: workerId,
        reportStartDate: startDate ?? DateTime.now().subtract(const Duration(days: 365)),
        reportEndDate: endDate ?? DateTime.now(),
        examinations: examinations,
        havsProgression: _analyzeHAVSProgression(examinations),
        riskLevelChanges: _analyzeRiskLevelChanges(examinations),
        recommendations: _generateReportRecommendations(examinations),
        nextExamRecommendation: _calculateNextExamRecommendation(examinations),
      );

    } catch (e) {
      NotificationManager().showSuccess('Error generating examination report: $e');
      rethrow;
    }
  }

  /// Analyze HAVS progression from examinations
  HAVSProgressionAnalysis _analyzeHAVSProgression(List<MedicalExamination> examinations) {
    if (examinations.isEmpty) {
      return HAVSProgressionAnalysis(
        hasProgressed: false,
        initialStage: 0,
        currentStage: 0,
        progressionRate: 0.0,
        timeToProgression: null,
      );
    }

    final sorted = examinations.toList()
      ..sort((a, b) => a.examinationDate.compareTo(b.examinationDate));

    final initialStage = sorted.first.havsStageAssessment;
    final currentStage = sorted.last.havsStageAssessment;
    final hasProgressed = currentStage > initialStage;

    double progressionRate = 0.0;
    Duration? timeToProgression;

    if (hasProgressed && sorted.length >= 2) {
      final timeSpan = sorted.last.examinationDate.difference(sorted.first.examinationDate);
      final stageChange = currentStage - initialStage;
      progressionRate = stageChange / (timeSpan.inDays / 365.25); // Stages per year

      // Find when progression first occurred
      for (int i = 1; i < sorted.length; i++) {
        if (sorted[i].havsStageAssessment > initialStage) {
          timeToProgression = sorted[i].examinationDate.difference(sorted.first.examinationDate);
          break;
        }
      }
    }

    return HAVSProgressionAnalysis(
      hasProgressed: hasProgressed,
      initialStage: initialStage,
      currentStage: currentStage,
      progressionRate: progressionRate,
      timeToProgression: timeToProgression,
    );
  }

  /// Analyze risk level changes
  List<String> _analyzeRiskLevelChanges(List<MedicalExamination> examinations) {
    final changes = <String>[];
    
    // This would analyze changes in risk factors, restrictions, etc.
    // For now, return basic analysis
    
    if (examinations.any((e) => !e.fitForWork)) {
      changes.add('Worker declared unfit for work');
    }
    
    if (examinations.any((e) => e.restrictionsRecommended)) {
      changes.add('Work restrictions recommended');
    }
    
    if (examinations.any((e) => e.havsProgression)) {
      changes.add('HAVS progression detected');
    }
    
    return changes;
  }

  /// Generate report recommendations
  List<String> _generateReportRecommendations(List<MedicalExamination> examinations) {
    final recommendations = <String>[];
    
    if (examinations.isEmpty) {
      recommendations.add('Schedule initial medical examination');
      return recommendations;
    }

    final latest = examinations.first;
    
    if (latest.havsStageAssessment >= 2) {
      recommendations.add('Increase examination frequency to quarterly');
      recommendations.add('Consider work restrictions or job rotation');
    }
    
    if (latest.restrictionsRecommended) {
      recommendations.add('Implement recommended work restrictions immediately');
    }
    
    if (!latest.fitForWork) {
      recommendations.add('Remove from vibration exposure work immediately');
    }
    
    return recommendations;
  }

  /// Calculate next examination recommendation
  DateTime _calculateNextExamRecommendation(List<MedicalExamination> examinations) {
    if (examinations.isEmpty) {
      return DateTime.now().add(const Duration(days: 30)); // Initial exam soon
    }

    final latest = examinations.first;
    int monthsUntilNext = baselineExamFrequency;

    // Adjust frequency based on HAVS stage
    if (latest.havsStageAssessment >= 3) {
      monthsUntilNext = criticalRiskFrequency;
    } else if (latest.havsStageAssessment >= 2) {
      monthsUntilNext = highRiskFrequency;
    } else if (latest.havsStageAssessment >= 1) {
      monthsUntilNext = moderateRiskFrequency;
    }

    return latest.examinationDate.add(Duration(days: monthsUntilNext * 30));
  }

  /// Dispose service
  void dispose() {
    _reminderTimer?.cancel();
  }
}

// Data models for examination system

class WorkerExaminationStatus {
  final String workerId;
  final String workerName;
  final DateTime lastExamDate;
  final DateTime? nextExamDue;
  final int daysPastDue;
  final ExposureRiskLevel riskLevel;
  final int havsStage;
  final bool hasSymptoms;

  WorkerExaminationStatus({
    required this.workerId,
    required this.workerName,
    required this.lastExamDate,
    this.nextExamDue,
    required this.daysPastDue,
    required this.riskLevel,
    required this.havsStage,
    required this.hasSymptoms,
  });
}

class ExaminationReport {
  final String workerId;
  final DateTime reportStartDate;
  final DateTime reportEndDate;
  final List<MedicalExamination> examinations;
  final HAVSProgressionAnalysis havsProgression;
  final List<String> riskLevelChanges;
  final List<String> recommendations;
  final DateTime nextExamRecommendation;

  ExaminationReport({
    required this.workerId,
    required this.reportStartDate,
    required this.reportEndDate,
    required this.examinations,
    required this.havsProgression,
    required this.riskLevelChanges,
    required this.recommendations,
    required this.nextExamRecommendation,
  });
}

class HAVSProgressionAnalysis {
  final bool hasProgressed;
  final int initialStage;
  final int currentStage;
  final double progressionRate;
  final Duration? timeToProgression;

  HAVSProgressionAnalysis({
    required this.hasProgressed,
    required this.initialStage,
    required this.currentStage,
    required this.progressionRate,
    this.timeToProgression,
  });
}