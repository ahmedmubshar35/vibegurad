import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/base_model.dart';

enum Gender { male, female, other }
enum HAVSStage { none, mild, moderate, severe }

/// Comprehensive health profile for HAVS monitoring and risk assessment
class HealthProfile extends BaseModel {
  // Basic health information
  final String workerId;
  final DateTime dateOfBirth;
  final Gender gender;
  final double? height; // cm
  final double? weight; // kg
  final String dominantHand;
  
  // Medical history
  final bool hasPreExistingConditions;
  final List<String> medicalConditions;
  final List<String> currentMedications;
  final bool smokingStatus;
  final String alcoholConsumption; // none, light, moderate, heavy
  
  // Work history
  final DateTime workStartDate;
  final List<String> previousJobsWithVibration;
  final int yearsExperienceWithVibratingTools;
  
  // Current health metrics
  final double currentHealthRiskScore;
  final DateTime lastHealthAssessment;
  final DateTime? nextMedicalExamDue;
  final bool hasHAVSSymptoms;
  final HAVSStage havsStage;
  
  // Lifestyle factors
  final String exerciseLevel; // none, light, moderate, heavy
  final int hoursOfSleep;
  final String stressLevel; // low, moderate, high
  final bool usesPPE;
  
  // Emergency contacts
  final String emergencyContactName;
  final String emergencyContactPhone;
  final String? doctorName;
  final String? doctorPhone;

  const HealthProfile({
    super.id,
    required this.workerId,
    required this.dateOfBirth,
    required this.gender,
    this.height,
    this.weight,
    required this.dominantHand,
    required this.hasPreExistingConditions,
    required this.medicalConditions,
    required this.currentMedications,
    required this.smokingStatus,
    required this.alcoholConsumption,
    required this.workStartDate,
    required this.previousJobsWithVibration,
    required this.yearsExperienceWithVibratingTools,
    required this.currentHealthRiskScore,
    required this.lastHealthAssessment,
    this.nextMedicalExamDue,
    required this.hasHAVSSymptoms,
    required this.havsStage,
    required this.exerciseLevel,
    required this.hoursOfSleep,
    required this.stressLevel,
    required this.usesPPE,
    required this.emergencyContactName,
    required this.emergencyContactPhone,
    this.doctorName,
    this.doctorPhone,
    super.createdAt,
    super.updatedAt,
    super.isActive,
  });

  // Calculate age from date of birth
  int get age {
    final today = DateTime.now();
    int age = today.year - dateOfBirth.year;
    if (today.month < dateOfBirth.month || 
        (today.month == dateOfBirth.month && today.day < dateOfBirth.day)) {
      age--;
    }
    return age;
  }

  // Calculate BMI if height and weight are available
  double? get bmi {
    if (height != null && weight != null && height! > 0) {
      final heightInMeters = height! / 100;
      return weight! / (heightInMeters * heightInMeters);
    }
    return null;
  }

  // Get BMI category
  String? get bmiCategory {
    final bmiValue = bmi;
    if (bmiValue == null) return null;
    
    if (bmiValue < 18.5) return 'Underweight';
    if (bmiValue < 25.0) return 'Normal';
    if (bmiValue < 30.0) return 'Overweight';
    return 'Obese';
  }

  // Check if medical exam is overdue
  bool get isMedicalExamOverdue {
    if (nextMedicalExamDue == null) return false;
    return DateTime.now().isAfter(nextMedicalExamDue!);
  }

  // Get days until next medical exam
  int? get daysUntilMedicalExam {
    if (nextMedicalExamDue == null) return null;
    return nextMedicalExamDue!.difference(DateTime.now()).inDays;
  }

  // Get HAVS stage description
  String get havsStageDescription {
    switch (havsStage) {
      case HAVSStage.none:
        return 'No symptoms';
      case HAVSStage.mild:
        return 'Mild symptoms - occasional tingling';
      case HAVSStage.moderate:
        return 'Moderate symptoms - regular numbness';
      case HAVSStage.severe:
        return 'Severe symptoms - constant symptoms affecting work';
    }
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
      'dateOfBirth': Timestamp.fromDate(dateOfBirth),
      'gender': gender.name,
      'height': height,
      'weight': weight,
      'dominantHand': dominantHand,
      'hasPreExistingConditions': hasPreExistingConditions,
      'medicalConditions': medicalConditions,
      'currentMedications': currentMedications,
      'smokingStatus': smokingStatus,
      'alcoholConsumption': alcoholConsumption,
      'workStartDate': Timestamp.fromDate(workStartDate),
      'previousJobsWithVibration': previousJobsWithVibration,
      'yearsExperienceWithVibratingTools': yearsExperienceWithVibratingTools,
      'currentHealthRiskScore': currentHealthRiskScore,
      'lastHealthAssessment': Timestamp.fromDate(lastHealthAssessment),
      'nextMedicalExamDue': nextMedicalExamDue != null ? Timestamp.fromDate(nextMedicalExamDue!) : null,
      'hasHAVSSymptoms': hasHAVSSymptoms,
      'havsStage': havsStage.index,
      'exerciseLevel': exerciseLevel,
      'hoursOfSleep': hoursOfSleep,
      'stressLevel': stressLevel,
      'usesPPE': usesPPE,
      'emergencyContactName': emergencyContactName,
      'emergencyContactPhone': emergencyContactPhone,
      'doctorName': doctorName,
      'doctorPhone': doctorPhone,
    };
  }

  factory HealthProfile.fromFirestore(Map<String, dynamic> data, String id) {
    return HealthProfile(
      id: id,
      workerId: data['workerId'] ?? '',
      dateOfBirth: (data['dateOfBirth'] as Timestamp).toDate(),
      gender: Gender.values.firstWhere(
        (g) => g.name == data['gender'], 
        orElse: () => Gender.other,
      ),
      height: data['height']?.toDouble(),
      weight: data['weight']?.toDouble(),
      dominantHand: data['dominantHand'] ?? 'right',
      hasPreExistingConditions: data['hasPreExistingConditions'] ?? false,
      medicalConditions: List<String>.from(data['medicalConditions'] ?? []),
      currentMedications: List<String>.from(data['currentMedications'] ?? []),
      smokingStatus: data['smokingStatus'] ?? false,
      alcoholConsumption: data['alcoholConsumption'] ?? 'none',
      workStartDate: (data['workStartDate'] as Timestamp).toDate(),
      previousJobsWithVibration: List<String>.from(data['previousJobsWithVibration'] ?? []),
      yearsExperienceWithVibratingTools: data['yearsExperienceWithVibratingTools'] ?? 0,
      currentHealthRiskScore: (data['currentHealthRiskScore'] ?? 0.0).toDouble(),
      lastHealthAssessment: (data['lastHealthAssessment'] as Timestamp).toDate(),
      nextMedicalExamDue: data['nextMedicalExamDue'] != null 
          ? (data['nextMedicalExamDue'] as Timestamp).toDate() 
          : null,
      hasHAVSSymptoms: data['hasHAVSSymptoms'] ?? false,
      havsStage: HAVSStage.values[data['havsStage'] ?? 0],
      exerciseLevel: data['exerciseLevel'] ?? 'moderate',
      hoursOfSleep: data['hoursOfSleep'] ?? 8,
      stressLevel: data['stressLevel'] ?? 'moderate',
      usesPPE: data['usesPPE'] ?? false,
      emergencyContactName: data['emergencyContactName'] ?? '',
      emergencyContactPhone: data['emergencyContactPhone'] ?? '',
      doctorName: data['doctorName'],
      doctorPhone: data['doctorPhone'],
      createdAt: data['createdAt'] != null 
          ? (data['createdAt'] as Timestamp).toDate() 
          : DateTime.now(),
      updatedAt: data['updatedAt'] != null 
          ? (data['updatedAt'] as Timestamp).toDate() 
          : DateTime.now(),
      isActive: data['isActive'] ?? true,
    );
  }

  @override
  HealthProfile copyWith({
    String? id,
    String? workerId,
    DateTime? dateOfBirth,
    Gender? gender,
    double? height,
    double? weight,
    String? dominantHand,
    bool? hasPreExistingConditions,
    List<String>? medicalConditions,
    List<String>? currentMedications,
    bool? smokingStatus,
    String? alcoholConsumption,
    DateTime? workStartDate,
    List<String>? previousJobsWithVibration,
    int? yearsExperienceWithVibratingTools,
    double? currentHealthRiskScore,
    DateTime? lastHealthAssessment,
    DateTime? nextMedicalExamDue,
    bool? hasHAVSSymptoms,
    HAVSStage? havsStage,
    String? exerciseLevel,
    int? hoursOfSleep,
    String? stressLevel,
    bool? usesPPE,
    String? emergencyContactName,
    String? emergencyContactPhone,
    String? doctorName,
    String? doctorPhone,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
  }) {
    return HealthProfile(
      id: id ?? this.id,
      workerId: workerId ?? this.workerId,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      gender: gender ?? this.gender,
      height: height ?? this.height,
      weight: weight ?? this.weight,
      dominantHand: dominantHand ?? this.dominantHand,
      hasPreExistingConditions: hasPreExistingConditions ?? this.hasPreExistingConditions,
      medicalConditions: medicalConditions ?? this.medicalConditions,
      currentMedications: currentMedications ?? this.currentMedications,
      smokingStatus: smokingStatus ?? this.smokingStatus,
      alcoholConsumption: alcoholConsumption ?? this.alcoholConsumption,
      workStartDate: workStartDate ?? this.workStartDate,
      previousJobsWithVibration: previousJobsWithVibration ?? this.previousJobsWithVibration,
      yearsExperienceWithVibratingTools: yearsExperienceWithVibratingTools ?? this.yearsExperienceWithVibratingTools,
      currentHealthRiskScore: currentHealthRiskScore ?? this.currentHealthRiskScore,
      lastHealthAssessment: lastHealthAssessment ?? this.lastHealthAssessment,
      nextMedicalExamDue: nextMedicalExamDue ?? this.nextMedicalExamDue,
      hasHAVSSymptoms: hasHAVSSymptoms ?? this.hasHAVSSymptoms,
      havsStage: havsStage ?? this.havsStage,
      exerciseLevel: exerciseLevel ?? this.exerciseLevel,
      hoursOfSleep: hoursOfSleep ?? this.hoursOfSleep,
      stressLevel: stressLevel ?? this.stressLevel,
      usesPPE: usesPPE ?? this.usesPPE,
      emergencyContactName: emergencyContactName ?? this.emergencyContactName,
      emergencyContactPhone: emergencyContactPhone ?? this.emergencyContactPhone,
      doctorName: doctorName ?? this.doctorName,
      doctorPhone: doctorPhone ?? this.doctorPhone,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
    );
  }
}

/// Health questionnaire response model
class HealthQuestionnaire {
  final String? id;
  final String workerId;
  final String questionnaireType; // 'initial', 'monthly', 'annual', 'symptom_check'
  final Map<String, dynamic> responses;
  final double calculatedRiskScore;
  final bool flaggedForReview;
  final String? reviewNotes;
  final DateTime completedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  HealthQuestionnaire({
    this.id,
    required this.workerId,
    required this.questionnaireType,
    required this.responses,
    required this.calculatedRiskScore,
    required this.flaggedForReview,
    this.reviewNotes,
    required this.completedAt,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return toFirestore();
  }
  
  Map<String, dynamic> toFirestore() {
    return {
      if (id != null) 'id': id,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
      'workerId': workerId,
      'questionnaireType': questionnaireType,
      'responses': responses,
      'calculatedRiskScore': calculatedRiskScore,
      'flaggedForReview': flaggedForReview,
      'reviewNotes': reviewNotes,
      'completedAt': Timestamp.fromDate(completedAt),
    };
  }

  factory HealthQuestionnaire.fromFirestore(Map<String, dynamic> data, String id) {
    return HealthQuestionnaire(
      id: id,
      workerId: data['workerId'] ?? '',
      questionnaireType: data['questionnaireType'] ?? '',
      responses: Map<String, dynamic>.from(data['responses'] ?? {}),
      calculatedRiskScore: (data['calculatedRiskScore'] ?? 0.0).toDouble(),
      flaggedForReview: data['flaggedForReview'] ?? false,
      reviewNotes: data['reviewNotes'],
      completedAt: (data['completedAt'] as Timestamp).toDate(),
      createdAt: data['createdAt'] != null 
          ? (data['createdAt'] as Timestamp).toDate() 
          : DateTime.now(),
      updatedAt: data['updatedAt'] != null 
          ? (data['updatedAt'] as Timestamp).toDate() 
          : DateTime.now(),
    );
  }
  
  HealthQuestionnaire copyWith({
    String? id,
    String? workerId,
    String? questionnaireType,
    Map<String, dynamic>? responses,
    double? calculatedRiskScore,
    bool? flaggedForReview,
    String? reviewNotes,
    DateTime? completedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return HealthQuestionnaire(
      id: id ?? this.id,
      workerId: workerId ?? this.workerId,
      questionnaireType: questionnaireType ?? this.questionnaireType,
      responses: responses ?? this.responses,
      calculatedRiskScore: calculatedRiskScore ?? this.calculatedRiskScore,
      flaggedForReview: flaggedForReview ?? this.flaggedForReview,
      reviewNotes: reviewNotes ?? this.reviewNotes,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Symptom tracking record
class SymptomReport {
  final String? id;
  final String workerId;
  final DateTime reportedAt;
  final Map<String, int> symptomSeverity; // symptom -> severity (0-10)
  final List<String> affectedAreas; // hands, wrists, arms, etc.
  final String? triggerActivity;
  final int painLevel; // 0-10
  final bool interferesWithWork;
  final bool interferesWithDaily;
  final String? additionalNotes;
  final bool reviewedByMedical;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  SymptomReport({
    this.id,
    required this.workerId,
    required this.reportedAt,
    required this.symptomSeverity,
    required this.affectedAreas,
    this.triggerActivity,
    required this.painLevel,
    required this.interferesWithWork,
    required this.interferesWithDaily,
    this.additionalNotes,
    required this.reviewedByMedical,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return toFirestore();
  }
  
  Map<String, dynamic> toFirestore() {
    return {
      if (id != null) 'id': id,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
      'workerId': workerId,
      'reportedAt': Timestamp.fromDate(reportedAt),
      'symptomSeverity': symptomSeverity,
      'affectedAreas': affectedAreas,
      'triggerActivity': triggerActivity,
      'painLevel': painLevel,
      'interferesWithWork': interferesWithWork,
      'interferesWithDaily': interferesWithDaily,
      'additionalNotes': additionalNotes,
      'reviewedByMedical': reviewedByMedical,
    };
  }

  factory SymptomReport.fromFirestore(Map<String, dynamic> data, String id) {
    return SymptomReport(
      id: id,
      workerId: data['workerId'] ?? '',
      reportedAt: (data['reportedAt'] as Timestamp).toDate(),
      symptomSeverity: Map<String, int>.from(data['symptomSeverity'] ?? {}),
      affectedAreas: List<String>.from(data['affectedAreas'] ?? []),
      triggerActivity: data['triggerActivity'],
      painLevel: data['painLevel'] ?? 0,
      interferesWithWork: data['interferesWithWork'] ?? false,
      interferesWithDaily: data['interferesWithDaily'] ?? false,
      additionalNotes: data['additionalNotes'],
      reviewedByMedical: data['reviewedByMedical'] ?? false,
      createdAt: data['createdAt'] != null 
          ? (data['createdAt'] as Timestamp).toDate() 
          : DateTime.now(),
      updatedAt: data['updatedAt'] != null 
          ? (data['updatedAt'] as Timestamp).toDate() 
          : DateTime.now(),
    );
  }
  
  SymptomReport copyWith({
    String? id,
    String? workerId,
    DateTime? reportedAt,
    Map<String, int>? symptomSeverity,
    List<String>? affectedAreas,
    String? triggerActivity,
    int? painLevel,
    bool? interferesWithWork,
    bool? interferesWithDaily,
    String? additionalNotes,
    bool? reviewedByMedical,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SymptomReport(
      id: id ?? this.id,
      workerId: workerId ?? this.workerId,
      reportedAt: reportedAt ?? this.reportedAt,
      symptomSeverity: symptomSeverity ?? this.symptomSeverity,
      affectedAreas: affectedAreas ?? this.affectedAreas,
      triggerActivity: triggerActivity ?? this.triggerActivity,
      painLevel: painLevel ?? this.painLevel,
      interferesWithWork: interferesWithWork ?? this.interferesWithWork,
      interferesWithDaily: interferesWithDaily ?? this.interferesWithDaily,
      additionalNotes: additionalNotes ?? this.additionalNotes,
      reviewedByMedical: reviewedByMedical ?? this.reviewedByMedical,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Medical examination record
class MedicalExamination {
  final String? id;
  final String workerId;
  final DateTime examinationDate;
  final String examinerName;
  final String facilityName;
  final String examinationType; // 'baseline', 'periodic', 'exit', 'targeted'
  
  // Examination results
  final Map<String, dynamic> vitalSigns;
  final Map<String, dynamic> neurologyTests;
  final Map<String, dynamic> circulationTests;
  final int havsStageAssessment;
  final bool havsProgression;
  final List<String> recommendations;
  final bool fitForWork;
  final bool restrictionsRecommended;
  final List<String> workRestrictions;
  final DateTime? nextExamDue;
  
  // Additional data
  final String? diagnosticCodes;
  final List<String> attachmentUrls;
  final String overallNotes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  MedicalExamination({
    this.id,
    required this.workerId,
    required this.examinationDate,
    required this.examinerName,
    required this.facilityName,
    required this.examinationType,
    required this.vitalSigns,
    required this.neurologyTests,
    required this.circulationTests,
    required this.havsStageAssessment,
    required this.havsProgression,
    required this.recommendations,
    required this.fitForWork,
    required this.restrictionsRecommended,
    required this.workRestrictions,
    this.nextExamDue,
    this.diagnosticCodes,
    required this.attachmentUrls,
    required this.overallNotes,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return toFirestore();
  }
  
  Map<String, dynamic> toFirestore() {
    return {
      if (id != null) 'id': id,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
      'workerId': workerId,
      'examinationDate': Timestamp.fromDate(examinationDate),
      'examinerName': examinerName,
      'facilityName': facilityName,
      'examinationType': examinationType,
      'vitalSigns': vitalSigns,
      'neurologyTests': neurologyTests,
      'circulationTests': circulationTests,
      'havsStageAssessment': havsStageAssessment,
      'havsProgression': havsProgression,
      'recommendations': recommendations,
      'fitForWork': fitForWork,
      'restrictionsRecommended': restrictionsRecommended,
      'workRestrictions': workRestrictions,
      'nextExamDue': nextExamDue != null ? Timestamp.fromDate(nextExamDue!) : null,
      'diagnosticCodes': diagnosticCodes,
      'attachmentUrls': attachmentUrls,
      'overallNotes': overallNotes,
    };
  }

  factory MedicalExamination.fromFirestore(Map<String, dynamic> data, String id) {
    return MedicalExamination(
      id: id,
      workerId: data['workerId'] ?? '',
      examinationDate: (data['examinationDate'] as Timestamp).toDate(),
      examinerName: data['examinerName'] ?? '',
      facilityName: data['facilityName'] ?? '',
      examinationType: data['examinationType'] ?? '',
      vitalSigns: Map<String, dynamic>.from(data['vitalSigns'] ?? {}),
      neurologyTests: Map<String, dynamic>.from(data['neurologyTests'] ?? {}),
      circulationTests: Map<String, dynamic>.from(data['circulationTests'] ?? {}),
      havsStageAssessment: data['havsStageAssessment'] ?? 0,
      havsProgression: data['havsProgression'] ?? false,
      recommendations: List<String>.from(data['recommendations'] ?? []),
      fitForWork: data['fitForWork'] ?? true,
      restrictionsRecommended: data['restrictionsRecommended'] ?? false,
      workRestrictions: List<String>.from(data['workRestrictions'] ?? []),
      nextExamDue: data['nextExamDue'] != null 
          ? (data['nextExamDue'] as Timestamp).toDate() 
          : null,
      diagnosticCodes: data['diagnosticCodes'],
      attachmentUrls: List<String>.from(data['attachmentUrls'] ?? []),
      overallNotes: data['overallNotes'] ?? '',
      createdAt: data['createdAt'] != null 
          ? (data['createdAt'] as Timestamp).toDate() 
          : DateTime.now(),
      updatedAt: data['updatedAt'] != null 
          ? (data['updatedAt'] as Timestamp).toDate() 
          : DateTime.now(),
    );
  }
}