import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:injectable/injectable.dart';
import 'package:stacked_services/stacked_services.dart';
import 'package:get_it/get_it.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';

import '../../models/health/health_profile.dart';
import '../../models/health/lifetime_exposure.dart';
import '../../models/timer/timer_session.dart';
import '../features/lifetime_exposure_service.dart';
import '../features/health_questionnaire_service.dart';
import '../features/medical_examination_service.dart';
import '../features/health_analytics_service.dart';

@lazySingleton
class HealthDataExportService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final LifetimeExposureService _exposureService = GetIt.instance<LifetimeExposureService>();
  final HealthQuestionnaireService _questionnaireService = GetIt.instance<HealthQuestionnaireService>();
  final MedicalExaminationService _examinationService = GetIt.instance<MedicalExaminationService>();
  final HealthAnalyticsService _analyticsService = GetIt.instance<HealthAnalyticsService>();
  final SnackbarService _snackbarService = GetIt.instance<SnackbarService>();

  /// Export comprehensive health data for medical professionals
  Future<String?> exportHealthDataForDoctor({
    required String workerId,
    required ExportFormat format,
    DateTime? startDate,
    DateTime? endDate,
    bool includePersonalInfo = true,
    bool includeExposureHistory = true,
    bool includeSymptoms = true,
    bool includeExaminations = true,
    bool includeQuestionnaires = true,
    bool includeAnalytics = true,
  }) async {
    try {
      // Gather all health data
      final healthData = await _gatherComprehensiveHealthData(
        workerId: workerId,
        startDate: startDate,
        endDate: endDate,
        includePersonalInfo: includePersonalInfo,
        includeExposureHistory: includeExposureHistory,
        includeSymptoms: includeSymptoms,
        includeExaminations: includeExaminations,
        includeQuestionnaires: includeQuestionnaires,
        includeAnalytics: includeAnalytics,
      );

      // Export based on format
      String? filePath;
      switch (format) {
        case ExportFormat.pdf:
          filePath = await _exportToPDF(healthData);
          break;
        case ExportFormat.csv:
          filePath = await _exportToCSV(healthData);
          break;
        case ExportFormat.json:
          filePath = await _exportToJSON(healthData);
          break;
        case ExportFormat.xml:
          filePath = await _exportToXML(healthData);
          break;
        case ExportFormat.hl7:
          filePath = await _exportToHL7(healthData);
          break;
      }

      if (filePath != null) {
        _snackbarService.showSnackbar(
          message: 'Health data exported successfully',
        );
      }

      return filePath;

    } catch (e) {
      _snackbarService.showSnackbar(
        message: 'Error exporting health data: $e',
      );
      return null;
    }
  }

  /// Export exposure summary report
  Future<String?> exportExposureSummary({
    required String workerId,
    required ExportFormat format,
    int months = 12,
  }) async {
    try {
      final lifetimeExposure = await _exposureService.getLifetimeExposure(workerId);
      if (lifetimeExposure == null) {
        _snackbarService.showSnackbar(message: 'No exposure data found');
        return null;
      }

      final trendAnalysis = await _exposureService.getExposureTrendAnalysis(workerId, months);
      
      final summaryData = ExposureSummaryData(
        workerId: workerId,
        reportDate: DateTime.now(),
        reportPeriodMonths: months,
        lifetimeExposure: lifetimeExposure,
        trendAnalysis: trendAnalysis,
      );

      switch (format) {
        case ExportFormat.pdf:
          return await _exportExposureSummaryToPDF(summaryData);
        case ExportFormat.csv:
          return await _exportExposureSummaryToCSV(summaryData);
        case ExportFormat.json:
          return await _exportExposureSummaryToJSON(summaryData);
        default:
          return await _exportExposureSummaryToPDF(summaryData);
      }

    } catch (e) {
      _snackbarService.showSnackbar(
        message: 'Error exporting exposure summary: $e',
      );
      return null;
    }
  }

  /// Export HAVS assessment report
  Future<String?> exportHAVSAssessment({
    required String workerId,
    required ExportFormat format,
  }) async {
    try {
      // Gather data for HAVS assessment
      final healthProfile = await _getHealthProfile(workerId);
      final lifetimeExposure = await _exposureService.getLifetimeExposure(workerId);
      final symptomHistory = await _getSymptomHistory(workerId);
      
      if (healthProfile == null || lifetimeExposure == null) {
        _snackbarService.showSnackbar(message: 'Insufficient data for HAVS assessment');
        return null;
      }

      // Calculate HAVS risk assessment
      final havsAssessment = await _analyticsService.calculateHAVSRiskAssessment(
        healthProfile: healthProfile,
        lifetimeExposure: lifetimeExposure,
        symptomHistory: symptomHistory,
      );

      final assessmentData = HAVSAssessmentData(
        workerId: workerId,
        assessmentDate: DateTime.now(),
        healthProfile: healthProfile,
        lifetimeExposure: lifetimeExposure,
        havsAssessment: havsAssessment,
        symptomHistory: symptomHistory,
      );

      switch (format) {
        case ExportFormat.pdf:
          return await _exportHAVSAssessmentToPDF(assessmentData);
        case ExportFormat.json:
          return await _exportHAVSAssessmentToJSON(assessmentData);
        default:
          return await _exportHAVSAssessmentToPDF(assessmentData);
      }

    } catch (e) {
      _snackbarService.showSnackbar(
        message: 'Error exporting HAVS assessment: $e',
      );
      return null;
    }
  }

  /// Share exported data via system share dialog
  Future<void> shareExportedData(String filePath, String subject) async {
    try {
      await Share.shareXFiles(
        [XFile(filePath)],
        subject: subject,
        text: 'Health data export from Vibe Guard',
      );
    } catch (e) {
      _snackbarService.showSnackbar(
        message: 'Error sharing exported data: $e',
      );
    }
  }

  // Private helper methods

  Future<ComprehensiveHealthData> _gatherComprehensiveHealthData({
    required String workerId,
    DateTime? startDate,
    DateTime? endDate,
    required bool includePersonalInfo,
    required bool includeExposureHistory,
    required bool includeSymptoms,
    required bool includeExaminations,
    required bool includeQuestionnaires,
    required bool includeAnalytics,
  }) async {
    HealthProfile? healthProfile;
    LifetimeExposure? lifetimeExposure;
    List<SymptomReport> symptoms = [];
    List<MedicalExamination> examinations = [];
    List<HealthQuestionnaire> questionnaires = [];
    HAVSRiskAssessment? riskAssessment;

    if (includePersonalInfo) {
      healthProfile = await _getHealthProfile(workerId);
    }

    if (includeExposureHistory) {
      lifetimeExposure = await _exposureService.getLifetimeExposure(workerId);
    }

    if (includeSymptoms) {
      symptoms = await _getSymptomHistory(workerId, startDate, endDate);
    }

    if (includeExaminations) {
      examinations = await _getExaminationHistory(workerId, startDate, endDate);
    }

    if (includeQuestionnaires) {
      questionnaires = await _getQuestionnaireHistory(workerId, startDate, endDate);
    }

    if (includeAnalytics && healthProfile != null && lifetimeExposure != null) {
      riskAssessment = await _analyticsService.calculateHAVSRiskAssessment(
        healthProfile: healthProfile,
        lifetimeExposure: lifetimeExposure,
        symptomHistory: symptoms,
      );
    }

    return ComprehensiveHealthData(
      workerId: workerId,
      exportDate: DateTime.now(),
      startDate: startDate,
      endDate: endDate,
      healthProfile: healthProfile,
      lifetimeExposure: lifetimeExposure,
      symptoms: symptoms,
      examinations: examinations,
      questionnaires: questionnaires,
      riskAssessment: riskAssessment,
    );
  }

  Future<HealthProfile?> _getHealthProfile(String workerId) async {
    try {
      final query = await _firestore
          .collection('health_profiles')
          .where('workerId', isEqualTo: workerId)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        return HealthProfile.fromFirestore(query.docs.first.data(), query.docs.first.id);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<List<SymptomReport>> _getSymptomHistory(String workerId, [DateTime? startDate, DateTime? endDate]) async {
    try {
      final stream = _questionnaireService.getWorkerSymptomReports(
        workerId: workerId,
        startDate: startDate,
        endDate: endDate,
        limit: 100,
      );
      return await stream.first;
    } catch (e) {
      return [];
    }
  }

  Future<List<MedicalExamination>> _getExaminationHistory(String workerId, [DateTime? startDate, DateTime? endDate]) async {
    try {
      final stream = _examinationService.getWorkerExaminations(
        workerId: workerId,
        limit: 50,
      );
      final allExams = await stream.first;
      
      if (startDate != null || endDate != null) {
        return allExams.where((exam) {
          if (startDate != null && exam.examinationDate.isBefore(startDate)) return false;
          if (endDate != null && exam.examinationDate.isAfter(endDate)) return false;
          return true;
        }).toList();
      }
      
      return allExams;
    } catch (e) {
      return [];
    }
  }

  Future<List<HealthQuestionnaire>> _getQuestionnaireHistory(String workerId, [DateTime? startDate, DateTime? endDate]) async {
    try {
      final stream = _questionnaireService.getWorkerQuestionnaires(
        workerId: workerId,
        limit: 50,
      );
      final allQuestionnaires = await stream.first;
      
      if (startDate != null || endDate != null) {
        return allQuestionnaires.where((q) {
          if (startDate != null && q.completedAt.isBefore(startDate)) return false;
          if (endDate != null && q.completedAt.isAfter(endDate)) return false;
          return true;
        }).toList();
      }
      
      return allQuestionnaires;
    } catch (e) {
      return [];
    }
  }

  // Export format implementations

  Future<String?> _exportToPDF(ComprehensiveHealthData data) async {
    try {
      // This would use a PDF generation library like pdf package
      // For now, return a placeholder implementation
      
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'health_data_${data.workerId}_${DateFormat('yyyyMMdd').format(data.exportDate)}.pdf';
      final filePath = '${directory.path}/$fileName';
      
      // PDF generation would go here
      // This is a placeholder - actual implementation would create comprehensive PDF
      final file = File(filePath);
      await file.writeAsString('PDF Health Data Export Placeholder\n\n${_generateTextReport(data)}');
      
      return filePath;
    } catch (e) {
      return null;
    }
  }

  Future<String?> _exportToCSV(ComprehensiveHealthData data) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'health_data_${data.workerId}_${DateFormat('yyyyMMdd').format(data.exportDate)}.csv';
      final filePath = '${directory.path}/$fileName';
      
      final csvContent = _generateCSVContent(data);
      
      final file = File(filePath);
      await file.writeAsString(csvContent);
      
      return filePath;
    } catch (e) {
      return null;
    }
  }

  Future<String?> _exportToJSON(ComprehensiveHealthData data) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'health_data_${data.workerId}_${DateFormat('yyyyMMdd').format(data.exportDate)}.json';
      final filePath = '${directory.path}/$fileName';
      
      final jsonContent = _generateJSONContent(data);
      
      final file = File(filePath);
      await file.writeAsString(jsonContent);
      
      return filePath;
    } catch (e) {
      return null;
    }
  }

  Future<String?> _exportToXML(ComprehensiveHealthData data) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'health_data_${data.workerId}_${DateFormat('yyyyMMdd').format(data.exportDate)}.xml';
      final filePath = '${directory.path}/$fileName';
      
      final xmlContent = _generateXMLContent(data);
      
      final file = File(filePath);
      await file.writeAsString(xmlContent);
      
      return filePath;
    } catch (e) {
      return null;
    }
  }

  Future<String?> _exportToHL7(ComprehensiveHealthData data) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'health_data_${data.workerId}_${DateFormat('yyyyMMdd').format(data.exportDate)}.hl7';
      final filePath = '${directory.path}/$fileName';
      
      final hl7Content = _generateHL7Content(data);
      
      final file = File(filePath);
      await file.writeAsString(hl7Content);
      
      return filePath;
    } catch (e) {
      return null;
    }
  }

  // Specialized export methods

  Future<String?> _exportExposureSummaryToPDF(ExposureSummaryData data) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'exposure_summary_${data.workerId}_${DateFormat('yyyyMMdd').format(data.reportDate)}.pdf';
      final filePath = '${directory.path}/$fileName';
      
      final content = _generateExposureSummaryText(data);
      final file = File(filePath);
      await file.writeAsString('Exposure Summary PDF\n\n$content');
      
      return filePath;
    } catch (e) {
      return null;
    }
  }

  Future<String?> _exportExposureSummaryToCSV(ExposureSummaryData data) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'exposure_summary_${data.workerId}_${DateFormat('yyyyMMdd').format(data.reportDate)}.csv';
      final filePath = '${directory.path}/$fileName';
      
      final content = _generateExposureSummaryCSV(data);
      final file = File(filePath);
      await file.writeAsString(content);
      
      return filePath;
    } catch (e) {
      return null;
    }
  }

  Future<String?> _exportExposureSummaryToJSON(ExposureSummaryData data) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'exposure_summary_${data.workerId}_${DateFormat('yyyyMMdd').format(data.reportDate)}.json';
      final filePath = '${directory.path}/$fileName';
      
      // JSON serialization would go here
      final jsonContent = '{"workerId": "${data.workerId}", "reportDate": "${data.reportDate.toIso8601String()}", "summary": "JSON export"}';
      
      final file = File(filePath);
      await file.writeAsString(jsonContent);
      
      return filePath;
    } catch (e) {
      return null;
    }
  }

  Future<String?> _exportHAVSAssessmentToPDF(HAVSAssessmentData data) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'havs_assessment_${data.workerId}_${DateFormat('yyyyMMdd').format(data.assessmentDate)}.pdf';
      final filePath = '${directory.path}/$fileName';
      
      final content = _generateHAVSAssessmentText(data);
      final file = File(filePath);
      await file.writeAsString('HAVS Assessment PDF\n\n$content');
      
      return filePath;
    } catch (e) {
      return null;
    }
  }

  Future<String?> _exportHAVSAssessmentToJSON(HAVSAssessmentData data) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'havs_assessment_${data.workerId}_${DateFormat('yyyyMMdd').format(data.assessmentDate)}.json';
      final filePath = '${directory.path}/$fileName';
      
      // JSON serialization would go here
      final jsonContent = '{"workerId": "${data.workerId}", "assessmentDate": "${data.assessmentDate.toIso8601String()}", "assessment": "JSON export"}';
      
      final file = File(filePath);
      await file.writeAsString(jsonContent);
      
      return filePath;
    } catch (e) {
      return null;
    }
  }

  // Content generation methods

  String _generateTextReport(ComprehensiveHealthData data) {
    final buffer = StringBuffer();
    
    buffer.writeln('COMPREHENSIVE HEALTH DATA EXPORT');
    buffer.writeln('Worker ID: ${data.workerId}');
    buffer.writeln('Export Date: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(data.exportDate)}');
    buffer.writeln('');
    
    if (data.healthProfile != null) {
      buffer.writeln('HEALTH PROFILE:');
      buffer.writeln('Age: ${data.healthProfile!.age}');
      buffer.writeln('HAVS Stage: ${data.healthProfile!.havsStage}');
      buffer.writeln('Has Symptoms: ${data.healthProfile!.hasHAVSSymptoms}');
      buffer.writeln('');
    }
    
    if (data.lifetimeExposure != null) {
      buffer.writeln('LIFETIME EXPOSURE:');
      buffer.writeln('Total A(8): ${data.lifetimeExposure!.totalLifetimeA8.toStringAsFixed(2)} m/s²');
      buffer.writeln('Total Hours: ${data.lifetimeExposure!.totalLifetimeHours.toStringAsFixed(1)}');
      buffer.writeln('Risk Level: ${data.lifetimeExposure!.currentRiskLevel.displayName}');
      buffer.writeln('');
    }
    
    if (data.symptoms.isNotEmpty) {
      buffer.writeln('RECENT SYMPTOMS (${data.symptoms.length} reports):');
      for (final symptom in data.symptoms.take(5)) {
        buffer.writeln('${DateFormat('yyyy-MM-dd').format(symptom.reportedAt)}: Pain Level ${symptom.painLevel}/10');
      }
      buffer.writeln('');
    }
    
    return buffer.toString();
  }

  String _generateCSVContent(ComprehensiveHealthData data) {
    final buffer = StringBuffer();
    
    // Header
    buffer.writeln('Type,Date,Field,Value');
    
    // Health Profile
    if (data.healthProfile != null) {
      final profile = data.healthProfile!;
      buffer.writeln('Profile,${DateFormat('yyyy-MM-dd').format(data.exportDate)},Age,${profile.age}');
      buffer.writeln('Profile,${DateFormat('yyyy-MM-dd').format(data.exportDate)},HAVS Stage,${profile.havsStage}');
      buffer.writeln('Profile,${DateFormat('yyyy-MM-dd').format(data.exportDate)},Has Symptoms,${profile.hasHAVSSymptoms}');
    }
    
    // Symptoms
    for (final symptom in data.symptoms) {
      buffer.writeln('Symptom,${DateFormat('yyyy-MM-dd').format(symptom.reportedAt)},Pain Level,${symptom.painLevel}');
      buffer.writeln('Symptom,${DateFormat('yyyy-MM-dd').format(symptom.reportedAt)},Work Interference,${symptom.interferesWithWork}');
    }
    
    return buffer.toString();
  }

  String _generateJSONContent(ComprehensiveHealthData data) {
    // This would use proper JSON serialization
    // Simplified implementation for now
    return '''
{
  "workerId": "${data.workerId}",
  "exportDate": "${data.exportDate.toIso8601String()}",
  "healthProfile": ${data.healthProfile != null ? '"exists"' : 'null'},
  "lifetimeExposure": ${data.lifetimeExposure != null ? '"exists"' : 'null'},
  "symptomsCount": ${data.symptoms.length},
  "examinationsCount": ${data.examinations.length}
}''';
  }

  String _generateXMLContent(ComprehensiveHealthData data) {
    final buffer = StringBuffer();
    
    buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buffer.writeln('<HealthDataExport>');
    buffer.writeln('  <WorkerId>${data.workerId}</WorkerId>');
    buffer.writeln('  <ExportDate>${data.exportDate.toIso8601String()}</ExportDate>');
    
    if (data.healthProfile != null) {
      buffer.writeln('  <HealthProfile>');
      buffer.writeln('    <Age>${data.healthProfile!.age}</Age>');
      buffer.writeln('    <HAVSStage>${data.healthProfile!.havsStage}</HAVSStage>');
      buffer.writeln('  </HealthProfile>');
    }
    
    buffer.writeln('</HealthDataExport>');
    
    return buffer.toString();
  }

  String _generateHL7Content(ComprehensiveHealthData data) {
    // Simplified HL7 v2.x message format
    final now = DateFormat('yyyyMMddHHmmss').format(DateTime.now());
    
    final buffer = StringBuffer();
    buffer.writeln('MSH|^~\\&|VibeGuard|Construction|Doctor|Clinic|$now||ORU^R01|12345|P|2.4');
    buffer.writeln('PID|||${data.workerId}||Worker^Unknown||||||||||||||||||||||||||');
    buffer.writeln('OBR|1||${data.workerId}_HAVS|^HAVS Assessment^L|||$now||||||||||||||||F');
    
    if (data.healthProfile != null) {
      buffer.writeln('OBX|1|NM|HAVS_STAGE^HAVS Stage^L||${data.healthProfile!.havsStage}||||F');
      buffer.writeln('OBX|2|ST|HAS_SYMPTOMS^Has Symptoms^L||${data.healthProfile!.hasHAVSSymptoms ? "Y" : "N"}||||F');
    }
    
    return buffer.toString();
  }

  String _generateExposureSummaryText(ExposureSummaryData data) {
    final buffer = StringBuffer();
    
    buffer.writeln('EXPOSURE SUMMARY REPORT');
    buffer.writeln('Worker ID: ${data.workerId}');
    buffer.writeln('Report Date: ${DateFormat('yyyy-MM-dd').format(data.reportDate)}');
    buffer.writeln('Period: ${data.reportPeriodMonths} months');
    buffer.writeln('');
    
    buffer.writeln('LIFETIME TOTALS:');
    buffer.writeln('Total A(8): ${data.lifetimeExposure.totalLifetimeA8.toStringAsFixed(2)} m/s²');
    buffer.writeln('Total Hours: ${data.lifetimeExposure.totalLifetimeHours.toStringAsFixed(1)}');
    buffer.writeln('Current Risk Level: ${data.lifetimeExposure.currentRiskLevel.displayName}');
    
    return buffer.toString();
  }

  String _generateExposureSummaryCSV(ExposureSummaryData data) {
    final buffer = StringBuffer();
    
    buffer.writeln('Metric,Value,Unit');
    buffer.writeln('Total A(8),${data.lifetimeExposure.totalLifetimeA8.toStringAsFixed(2)},m/s²');
    buffer.writeln('Total Hours,${data.lifetimeExposure.totalLifetimeHours.toStringAsFixed(1)},hours');
    buffer.writeln('Risk Level,${data.lifetimeExposure.currentRiskLevel.displayName},category');
    
    return buffer.toString();
  }

  String _generateHAVSAssessmentText(HAVSAssessmentData data) {
    final buffer = StringBuffer();
    
    buffer.writeln('HAVS RISK ASSESSMENT REPORT');
    buffer.writeln('Worker ID: ${data.workerId}');
    buffer.writeln('Assessment Date: ${DateFormat('yyyy-MM-dd').format(data.assessmentDate)}');
    buffer.writeln('');
    
    buffer.writeln('CURRENT STATUS:');
    buffer.writeln('HAVS Stage: ${data.havsAssessment.currentStage}');
    buffer.writeln('Risk Score: ${data.havsAssessment.riskScore.toStringAsFixed(1)}/100');
    buffer.writeln('Onset Probability: ${data.havsAssessment.onsetProbability.probabilityPercent.toStringAsFixed(1)}%');
    
    buffer.writeln('');
    buffer.writeln('RECOMMENDATIONS:');
    for (final recommendation in data.havsAssessment.recommendedInterventions) {
      buffer.writeln('- $recommendation');
    }
    
    return buffer.toString();
  }
}

// Export data models

class ComprehensiveHealthData {
  final String workerId;
  final DateTime exportDate;
  final DateTime? startDate;
  final DateTime? endDate;
  final HealthProfile? healthProfile;
  final LifetimeExposure? lifetimeExposure;
  final List<SymptomReport> symptoms;
  final List<MedicalExamination> examinations;
  final List<HealthQuestionnaire> questionnaires;
  final HAVSRiskAssessment? riskAssessment;

  ComprehensiveHealthData({
    required this.workerId,
    required this.exportDate,
    this.startDate,
    this.endDate,
    this.healthProfile,
    this.lifetimeExposure,
    required this.symptoms,
    required this.examinations,
    required this.questionnaires,
    this.riskAssessment,
  });
}

class ExposureSummaryData {
  final String workerId;
  final DateTime reportDate;
  final int reportPeriodMonths;
  final LifetimeExposure lifetimeExposure;
  final ExposureTrendAnalysis trendAnalysis;

  ExposureSummaryData({
    required this.workerId,
    required this.reportDate,
    required this.reportPeriodMonths,
    required this.lifetimeExposure,
    required this.trendAnalysis,
  });
}

class HAVSAssessmentData {
  final String workerId;
  final DateTime assessmentDate;
  final HealthProfile healthProfile;
  final LifetimeExposure lifetimeExposure;
  final HAVSRiskAssessment havsAssessment;
  final List<SymptomReport> symptomHistory;

  HAVSAssessmentData({
    required this.workerId,
    required this.assessmentDate,
    required this.healthProfile,
    required this.lifetimeExposure,
    required this.havsAssessment,
    required this.symptomHistory,
  });
}

enum ExportFormat {
  pdf,
  csv,
  json,
  xml,
  hl7,
}