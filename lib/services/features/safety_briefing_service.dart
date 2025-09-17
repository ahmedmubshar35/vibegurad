import 'dart:async';
import 'package:injectable/injectable.dart';
import 'package:stacked_services/stacked_services.dart';
import 'package:get_it/get_it.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../enums/exposure_level.dart';
import '../features/notification_service.dart';

@lazySingleton
class SafetyBriefingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = GetIt.instance<NotificationService>();
  final SnackbarService _snackbarService = GetIt.instance<SnackbarService>();
  
  SharedPreferences? _prefs;
  Timer? _reminderTimer;

  // Briefing schedule constants
  static const int dailyBriefingHour = 7; // 7 AM daily briefing
  static const int weeklyBriefingDay = 1; // Monday weekly briefing
  static const int monthlyBriefingDay = 1; // First day of month
  static const int newWorkerBriefingDays = 7; // 7 days for new workers

  SafetyBriefingService();

  // Initialize the service
  Future<void> initialize() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      await _scheduleReminderChecks();
    } catch (e) {
      _snackbarService.showSnackbar(
        message: 'Failed to initialize safety briefing service: $e',
      );
    }
  }

  // Schedule periodic reminder checks
  Future<void> _scheduleReminderChecks() async {
    _reminderTimer?.cancel();
    
    // Check every hour for due briefings
    _reminderTimer = Timer.periodic(
      const Duration(hours: 1),
      (timer) => _checkDueBriefings(),
    );

    // Also check immediately
    await _checkDueBriefings();
  }

  // Check for due briefings and send reminders
  Future<void> _checkDueBriefings() async {
    try {
      final now = DateTime.now();
      
      // Check daily briefings (only at the scheduled hour)
      if (now.hour == dailyBriefingHour) {
        await _checkDailyBriefings();
      }
      
      // Check weekly briefings (Monday at briefing hour)
      if (now.weekday == weeklyBriefingDay && now.hour == dailyBriefingHour) {
        await _checkWeeklyBriefings();
      }
      
      // Check monthly briefings (first day of month)
      if (now.day == monthlyBriefingDay && now.hour == dailyBriefingHour) {
        await _checkMonthlyBriefings();
      }
      
      // Check new worker briefings (daily check)
      await _checkNewWorkerBriefings();
      
      // Check overdue briefings
      await _checkOverdueBriefings();
      
    } catch (e) {
      // Silent fail for background checks
    }
  }

  // Check daily briefings
  Future<void> _checkDailyBriefings() async {
    if (!await _isDailyBriefingEnabled()) return;

    final today = DateTime.now();
    final todayKey = '${today.year}-${today.month}-${today.day}';
    
    final lastDailyBriefing = _prefs?.getString('last_daily_briefing');
    
    if (lastDailyBriefing != todayKey) {
      await _sendDailyBriefingReminder();
      await _prefs?.setString('last_daily_briefing', todayKey);
    }
  }

  // Check weekly briefings
  Future<void> _checkWeeklyBriefings() async {
    if (!await _isWeeklyBriefingEnabled()) return;

    final now = DateTime.now();
    final weekKey = '${now.year}-${_getWeekOfYear(now)}';
    
    final lastWeeklyBriefing = _prefs?.getString('last_weekly_briefing');
    
    if (lastWeeklyBriefing != weekKey) {
      await _sendWeeklyBriefingReminder();
      await _prefs?.setString('last_weekly_briefing', weekKey);
    }
  }

  // Check monthly briefings
  Future<void> _checkMonthlyBriefings() async {
    if (!await _isMonthlyBriefingEnabled()) return;

    final now = DateTime.now();
    final monthKey = '${now.year}-${now.month}';
    
    final lastMonthlyBriefing = _prefs?.getString('last_monthly_briefing');
    
    if (lastMonthlyBriefing != monthKey) {
      await _sendMonthlyBriefingReminder();
      await _prefs?.setString('last_monthly_briefing', monthKey);
    }
  }

  // Check new worker briefings
  Future<void> _checkNewWorkerBriefings() async {
    try {
      final query = await _firestore
          .collection('safety_briefings')
          .where('briefingType', isEqualTo: 'new_worker')
          .where('isCompleted', isEqualTo: false)
          .where('dueDate', isLessThanOrEqualTo: DateTime.now())
          .get();

      for (final doc in query.docs) {
        final briefing = SafetyBriefingRecord.fromFirestore(doc);
        await _sendNewWorkerBriefingReminder(briefing);
      }
    } catch (e) {
      // Silent fail
    }
  }

  // Check overdue briefings
  Future<void> _checkOverdueBriefings() async {
    try {
      final threeDaysAgo = DateTime.now().subtract(const Duration(days: 3));
      
      final query = await _firestore
          .collection('safety_briefings')
          .where('isCompleted', isEqualTo: false)
          .where('dueDate', isLessThan: threeDaysAgo)
          .get();

      for (final doc in query.docs) {
        final briefing = SafetyBriefingRecord.fromFirestore(doc);
        await _sendOverdueBriefingNotification(briefing);
      }
    } catch (e) {
      // Silent fail
    }
  }

  // Send daily briefing reminder
  Future<void> _sendDailyBriefingReminder() async {
    await _notificationService.showSafetyWarning(
      title: '📋 Daily Safety Briefing',
      body: 'Time for your daily safety briefing. Review today\'s safety priorities and hazards.',
      level: ExposureLevel.low,
      payload: {
        'type': 'safety_briefing',
        'briefingType': 'daily',
        'scheduled': 'true',
      },
    );
  }

  // Send weekly briefing reminder
  Future<void> _sendWeeklyBriefingReminder() async {
    await _notificationService.showSafetyWarning(
      title: '📊 Weekly Safety Review',
      body: 'Weekly safety briefing due. Review this week\'s incidents, best practices, and safety updates.',
      level: ExposureLevel.medium,
      payload: {
        'type': 'safety_briefing',
        'briefingType': 'weekly',
        'scheduled': 'true',
      },
    );
  }

  // Send monthly briefing reminder
  Future<void> _sendMonthlyBriefingReminder() async {
    await _notificationService.showSafetyWarning(
      title: '🗓️ Monthly Safety Meeting',
      body: 'Monthly safety briefing required. Review policy updates, training requirements, and safety metrics.',
      level: ExposureLevel.medium,
      payload: {
        'type': 'safety_briefing',
        'briefingType': 'monthly',
        'scheduled': 'true',
      },
    );
  }

  // Send new worker briefing reminder
  Future<void> _sendNewWorkerBriefingReminder(SafetyBriefingRecord briefing) async {
    await _notificationService.showSafetyWarning(
      title: '👷 New Worker Safety Briefing',
      body: 'Safety briefing required for new worker: ${briefing.workerName}. '
             'Complete orientation and HAVS training.',
      level: ExposureLevel.high,
      payload: {
        'type': 'safety_briefing',
        'briefingType': 'new_worker',
        'workerId': briefing.workerId,
        'briefingId': briefing.id,
      },
    );
  }

  // Send overdue briefing notification
  Future<void> _sendOverdueBriefingNotification(SafetyBriefingRecord briefing) async {
    final daysPastDue = DateTime.now().difference(briefing.dueDate).inDays;
    
    await _notificationService.showSafetyWarning(
      title: '🚨 Overdue Safety Briefing',
      body: '${briefing.title} is $daysPastDue days overdue for ${briefing.workerName}. '
             'Complete immediately to maintain compliance.',
      level: ExposureLevel.critical,
      payload: {
        'type': 'safety_briefing',
        'briefingType': 'overdue',
        'briefingId': briefing.id,
        'daysPastDue': daysPastDue.toString(),
      },
    );
  }

  // Create safety briefing record
  Future<String?> createSafetyBriefing({
    required String workerId,
    required String workerName,
    required String title,
    required SafetyBriefingType briefingType,
    required DateTime dueDate,
    String? description,
    List<String>? requiredTopics,
    String? assignedBy,
  }) async {
    try {
      final briefing = SafetyBriefingRecord(
        id: '',
        workerId: workerId,
        workerName: workerName,
        title: title,
        description: description ?? '',
        briefingType: briefingType,
        dueDate: dueDate,
        requiredTopics: requiredTopics ?? [],
        isCompleted: false,
        assignedBy: assignedBy ?? '',
        assignedAt: DateTime.now(),
        completedAt: null,
        completedBy: null,
        notes: '',
      );

      final docRef = await _firestore
          .collection('safety_briefings')
          .add(briefing.toFirestore());

      return docRef.id;
    } catch (e) {
      _snackbarService.showSnackbar(
        message: 'Failed to create safety briefing: $e',
      );
      return null;
    }
  }

  // Complete safety briefing
  Future<void> completeSafetyBriefing({
    required String briefingId,
    required String completedBy,
    String? notes,
    List<String>? topicsCovered,
  }) async {
    try {
      final updateData = {
        'isCompleted': true,
        'completedAt': FieldValue.serverTimestamp(),
        'completedBy': completedBy,
        'notes': notes ?? '',
      };

      if (topicsCovered != null) {
        updateData['topicsCovered'] = topicsCovered;
      }

      await _firestore
          .collection('safety_briefings')
          .doc(briefingId)
          .update(updateData);

      _snackbarService.showSnackbar(
        message: 'Safety briefing completed successfully',
      );
    } catch (e) {
      _snackbarService.showSnackbar(
        message: 'Failed to complete safety briefing: $e',
      );
    }
  }

  // Schedule new worker briefings
  Future<void> scheduleNewWorkerBriefings({
    required String workerId,
    required String workerName,
    required DateTime startDate,
  }) async {
    final briefings = [
      {
        'title': 'HAVS Awareness Training',
        'description': 'Introduction to Hand-Arm Vibration Syndrome risks and prevention',
        'daysOffset': 1,
        'topics': ['HAVS basics', 'Risk factors', 'Prevention methods', 'Recognition symptoms'],
      },
      {
        'title': 'Tool Safety & Maintenance',
        'description': 'Proper tool usage, maintenance schedules, and safety protocols',
        'daysOffset': 2,
        'topics': ['Tool inspection', 'Maintenance requirements', 'Safe operation', 'PPE usage'],
      },
      {
        'title': 'Emergency Procedures',
        'description': 'Emergency stop procedures and incident reporting',
        'daysOffset': 3,
        'topics': ['Emergency stops', 'Incident reporting', 'First aid', 'Emergency contacts'],
      },
      {
        'title': 'Compliance & Documentation',
        'description': 'Regulatory compliance and documentation requirements',
        'daysOffset': 5,
        'topics': ['HSE regulations', 'Documentation', 'Record keeping', 'Reporting requirements'],
      },
      {
        'title': 'Assessment & Certification',
        'description': 'Final assessment and safety certification',
        'daysOffset': 7,
        'topics': ['Safety assessment', 'Knowledge test', 'Practical demonstration', 'Certification'],
      },
    ];

    for (final briefingData in briefings) {
      final dueDate = startDate.add(Duration(days: briefingData['daysOffset'] as int));
      
      await createSafetyBriefing(
        workerId: workerId,
        workerName: workerName,
        title: briefingData['title'] as String,
        description: briefingData['description'] as String,
        briefingType: SafetyBriefingType.newWorker,
        dueDate: dueDate,
        requiredTopics: briefingData['topics'] as List<String>,
        assignedBy: 'System',
      );
    }
  }

  // Get briefing records
  Stream<List<SafetyBriefingRecord>> getBriefingRecords({
    String? workerId,
    SafetyBriefingType? briefingType,
    bool? isCompleted,
  }) {
    Query query = _firestore.collection('safety_briefings');

    if (workerId != null) {
      query = query.where('workerId', isEqualTo: workerId);
    }
    if (briefingType != null) {
      query = query.where('briefingType', isEqualTo: briefingType.name);
    }
    if (isCompleted != null) {
      query = query.where('isCompleted', isEqualTo: isCompleted);
    }

    return query.orderBy('dueDate', descending: true).snapshots().map(
      (snapshot) => snapshot.docs.map((doc) => SafetyBriefingRecord.fromFirestore(doc)).toList(),
    );
  }

  // Settings management
  Future<void> setDailyBriefingEnabled(bool enabled) async {
    await _prefs?.setBool('daily_briefing_enabled', enabled);
  }

  Future<bool> _isDailyBriefingEnabled() async {
    return _prefs?.getBool('daily_briefing_enabled') ?? true;
  }

  Future<void> setWeeklyBriefingEnabled(bool enabled) async {
    await _prefs?.setBool('weekly_briefing_enabled', enabled);
  }

  Future<bool> _isWeeklyBriefingEnabled() async {
    return _prefs?.getBool('weekly_briefing_enabled') ?? true;
  }

  Future<void> setMonthlyBriefingEnabled(bool enabled) async {
    await _prefs?.setBool('monthly_briefing_enabled', enabled);
  }

  Future<bool> _isMonthlyBriefingEnabled() async {
    return _prefs?.getBool('monthly_briefing_enabled') ?? true;
  }

  // Helper methods
  int _getWeekOfYear(DateTime date) {
    final startOfYear = DateTime(date.year, 1, 1);
    final dayOfYear = date.difference(startOfYear).inDays + 1;
    return ((dayOfYear - date.weekday + 10) / 7).floor();
  }

  // Dispose service
  void dispose() {
    _reminderTimer?.cancel();
  }
}

// Data models
class SafetyBriefingRecord {
  final String id;
  final String workerId;
  final String workerName;
  final String title;
  final String description;
  final SafetyBriefingType briefingType;
  final DateTime dueDate;
  final List<String> requiredTopics;
  final bool isCompleted;
  final String assignedBy;
  final DateTime assignedAt;
  final DateTime? completedAt;
  final String? completedBy;
  final String notes;
  final List<String>? topicsCovered;

  SafetyBriefingRecord({
    required this.id,
    required this.workerId,
    required this.workerName,
    required this.title,
    required this.description,
    required this.briefingType,
    required this.dueDate,
    required this.requiredTopics,
    required this.isCompleted,
    required this.assignedBy,
    required this.assignedAt,
    this.completedAt,
    this.completedBy,
    required this.notes,
    this.topicsCovered,
  });

  factory SafetyBriefingRecord.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SafetyBriefingRecord(
      id: doc.id,
      workerId: data['workerId'] ?? '',
      workerName: data['workerName'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      briefingType: SafetyBriefingType.fromString(data['briefingType'] ?? 'general'),
      dueDate: (data['dueDate'] as Timestamp).toDate(),
      requiredTopics: List<String>.from(data['requiredTopics'] ?? []),
      isCompleted: data['isCompleted'] ?? false,
      assignedBy: data['assignedBy'] ?? '',
      assignedAt: (data['assignedAt'] as Timestamp).toDate(),
      completedAt: data['completedAt'] != null ? (data['completedAt'] as Timestamp).toDate() : null,
      completedBy: data['completedBy'],
      notes: data['notes'] ?? '',
      topicsCovered: data['topicsCovered'] != null ? List<String>.from(data['topicsCovered']) : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'workerId': workerId,
      'workerName': workerName,
      'title': title,
      'description': description,
      'briefingType': briefingType.name,
      'dueDate': Timestamp.fromDate(dueDate),
      'requiredTopics': requiredTopics,
      'isCompleted': isCompleted,
      'assignedBy': assignedBy,
      'assignedAt': Timestamp.fromDate(assignedAt),
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'completedBy': completedBy,
      'notes': notes,
      'topicsCovered': topicsCovered,
    };
  }
}

enum SafetyBriefingType {
  daily,
  weekly,
  monthly,
  newWorker,
  incident,
  general,
  emergency;

  static SafetyBriefingType fromString(String value) {
    return SafetyBriefingType.values.firstWhere(
      (type) => type.name == value.toLowerCase(),
      orElse: () => SafetyBriefingType.general,
    );
  }

  String get displayName {
    switch (this) {
      case SafetyBriefingType.daily:
        return 'Daily Briefing';
      case SafetyBriefingType.weekly:
        return 'Weekly Review';
      case SafetyBriefingType.monthly:
        return 'Monthly Meeting';
      case SafetyBriefingType.newWorker:
        return 'New Worker Training';
      case SafetyBriefingType.incident:
        return 'Incident Briefing';
      case SafetyBriefingType.general:
        return 'General Briefing';
      case SafetyBriefingType.emergency:
        return 'Emergency Briefing';
    }
  }
}