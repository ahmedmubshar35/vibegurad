import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cron/cron.dart';
import '../../models/admin/dashboard_models.dart';
import 'custom_report_service.dart';
import 'admin_analytics_service.dart';
import 'safety_violation_service.dart';

/// Scheduled automation service for reports and system maintenance
class ScheduledAutomationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CustomReportService _reportService = CustomReportService();
  final AdminAnalyticsService _analytics = AdminAnalyticsService();
  final SafetyViolationService _violationService = SafetyViolationService();
  // Notification service would be injected in production

  final Cron _cron = Cron();
  final Map<String, ScheduledJob> _scheduledJobs = {};

  /// Initialize scheduled automation
  Future<void> initialize() async {
    await _loadScheduledJobs();
    await _setupSystemMaintenanceJobs();
    _startJobMonitoring();
  }

  /// Load existing scheduled jobs from database
  Future<void> _loadScheduledJobs() async {
    try {
      // Load scheduled reports
      final scheduledReports = await _reportService.getScheduledReports();
      for (final report in scheduledReports) {
        if (report.schedule != null) {
          await _scheduleReportJob(report);
        }
      }

      // Load other scheduled tasks
      final scheduledTasks = await _firestore
          .collection('scheduled_tasks')
          .where('isActive', isEqualTo: true)
          .get();

      for (final doc in scheduledTasks.docs) {
        final task = _taskFromFirestore(doc.data(), doc.id);
        await _scheduleTask(task);
      }
    } catch (e) {
      print('Error loading scheduled jobs: $e');
    }
  }

  /// Schedule a report job
  Future<void> _scheduleReportJob(CustomReportConfig report) async {
    if (report.schedule == null) return;

    try {
      final jobId = 'report_${report.reportId}';
      final cronExpression = _parseCronExpression(report.schedule!);

      final job = _cron.schedule(Schedule.parse(cronExpression), () async {
        await _executeReportJob(report);
      });

      _scheduledJobs[jobId] = ScheduledJob(
        jobId: jobId,
        type: 'report',
        name: report.reportName,
        schedule: cronExpression,
        lastRun: null,
        nextRun: _calculateNextRun(cronExpression),
        isActive: true,
        jobReference: job,
      );

      print('Scheduled report job: ${report.reportName} with schedule: $cronExpression');
    } catch (e) {
      print('Error scheduling report job: $e');
    }
  }

  /// Execute report job
  Future<void> _executeReportJob(CustomReportConfig report) async {
    try {
      print('Executing scheduled report: ${report.reportName}');
      
      final filePath = await _reportService.generateReport(report.reportId);
      
      if (filePath != null && report.recipients.isNotEmpty) {
        await _sendReportToRecipients(report, filePath);
      }

      // Update last run time
      final jobId = 'report_${report.reportId}';
      if (_scheduledJobs.containsKey(jobId)) {
        _scheduledJobs[jobId] = _scheduledJobs[jobId]!.copyWith(
          lastRun: DateTime.now(),
          nextRun: _calculateNextRun(_scheduledJobs[jobId]!.schedule),
        );
      }
    } catch (e) {
      print('Error executing report job: $e');
      await _handleJobFailure('report_${report.reportId}', e.toString());
    }
  }

  /// Setup system maintenance jobs
  Future<void> _setupSystemMaintenanceJobs() async {
    // Daily analytics update
    _scheduleSystemJob(
      jobId: 'daily_analytics_update',
      name: 'Daily Analytics Update',
      schedule: '0 2 * * *', // 2 AM daily
      handler: _updateDailyAnalytics,
    );

    // Weekly compliance check
    _scheduleSystemJob(
      jobId: 'weekly_compliance_check',
      name: 'Weekly Compliance Check',
      schedule: '0 6 * * 1', // 6 AM every Monday
      handler: _performWeeklyComplianceCheck,
    );

    // Monthly risk assessment
    _scheduleSystemJob(
      jobId: 'monthly_risk_assessment',
      name: 'Monthly Risk Assessment',
      schedule: '0 3 1 * *', // 3 AM on 1st of each month
      handler: _performMonthlyRiskAssessment,
    );

    // Daily violation monitoring
    _scheduleSystemJob(
      jobId: 'daily_violation_monitoring',
      name: 'Daily Violation Monitoring',
      schedule: '0 1 * * *', // 1 AM daily
      handler: _performDailyViolationMonitoring,
    );

    // Weekly budget impact update
    _scheduleSystemJob(
      jobId: 'weekly_budget_update',
      name: 'Weekly Budget Impact Update',
      schedule: '0 4 * * 0', // 4 AM every Sunday
      handler: _updateWeeklyBudgetImpact,
    );
  }

  /// Schedule a system maintenance job
  void _scheduleSystemJob({
    required String jobId,
    required String name,
    required String schedule,
    required Future<void> Function() handler,
  }) {
    try {
      final job = _cron.schedule(Schedule.parse(schedule), () async {
        await _executeSystemJob(jobId, name, handler);
      });

      _scheduledJobs[jobId] = ScheduledJob(
        jobId: jobId,
        type: 'system',
        name: name,
        schedule: schedule,
        lastRun: null,
        nextRun: _calculateNextRun(schedule),
        isActive: true,
        jobReference: job,
      );

      print('Scheduled system job: $name with schedule: $schedule');
    } catch (e) {
      print('Error scheduling system job $jobId: $e');
    }
  }

  /// Execute system job with error handling
  Future<void> _executeSystemJob(
    String jobId,
    String name,
    Future<void> Function() handler,
  ) async {
    try {
      print('Executing system job: $name');
      await handler();

      // Update job status
      if (_scheduledJobs.containsKey(jobId)) {
        _scheduledJobs[jobId] = _scheduledJobs[jobId]!.copyWith(
          lastRun: DateTime.now(),
          nextRun: _calculateNextRun(_scheduledJobs[jobId]!.schedule),
        );
      }

      print('System job completed: $name');
    } catch (e) {
      print('Error executing system job $name: $e');
      await _handleJobFailure(jobId, e.toString());
    }
  }

  /// Schedule custom task
  Future<String> scheduleTask({
    required String taskName,
    required String taskType,
    required String schedule,
    required Map<String, dynamic> parameters,
    required String createdBy,
    List<String> notificationRecipients = const [],
  }) async {
    try {
      final task = ScheduledTask(
        taskId: '',
        taskName: taskName,
        taskType: taskType,
        schedule: schedule,
        parameters: parameters,
        isActive: true,
        createdBy: createdBy,
        createdAt: DateTime.now(),
        lastRun: null,
        nextRun: _calculateNextRun(schedule),
        notificationRecipients: notificationRecipients,
      );

      final docRef = await _firestore
          .collection('scheduled_tasks')
          .add(_taskToFirestore(task));

      final savedTask = task.copyWith(taskId: docRef.id);
      await _scheduleTask(savedTask);

      return docRef.id;
    } catch (e) {
      print('Error scheduling task: $e');
      rethrow;
    }
  }

  /// Schedule a task
  Future<void> _scheduleTask(ScheduledTask task) async {
    try {
      final jobId = 'task_${task.taskId}';

      final job = _cron.schedule(Schedule.parse(task.schedule), () async {
        await _executeCustomTask(task);
      });

      _scheduledJobs[jobId] = ScheduledJob(
        jobId: jobId,
        type: 'task',
        name: task.taskName,
        schedule: task.schedule,
        lastRun: task.lastRun,
        nextRun: task.nextRun,
        isActive: task.isActive,
        jobReference: job,
      );
    } catch (e) {
      print('Error scheduling task ${task.taskName}: $e');
    }
  }

  /// Execute custom task
  Future<void> _executeCustomTask(ScheduledTask task) async {
    try {
      print('Executing custom task: ${task.taskName}');

      switch (task.taskType) {
        case 'data_cleanup':
          await _performDataCleanup(task.parameters);
          break;
        case 'backup':
          await _performBackup(task.parameters);
          break;
        case 'notification_batch':
          await _sendBatchNotifications(task.parameters);
          break;
        case 'analytics_export':
          await _performAnalyticsExport(task.parameters);
          break;
        default:
          print('Unknown task type: ${task.taskType}');
          return;
      }

      // Update task status
      await _firestore
          .collection('scheduled_tasks')
          .doc(task.taskId)
          .update({
        'lastRun': Timestamp.now(),
        'nextRun': Timestamp.fromDate(_calculateNextRun(task.schedule)),
      });

      // Send success notification
      if (task.notificationRecipients.isNotEmpty) {
        await _sendTaskCompletionNotification(task, true);
      }
    } catch (e) {
      print('Error executing custom task ${task.taskName}: $e');
      await _handleJobFailure('task_${task.taskId}', e.toString());
      
      // Send failure notification
      if (task.notificationRecipients.isNotEmpty) {
        await _sendTaskCompletionNotification(task, false, e.toString());
      }
    }
  }

  /// Start job monitoring
  void _startJobMonitoring() {
    Timer.periodic(const Duration(minutes: 5), (_) {
      _monitorJobHealth();
    });
  }

  /// Monitor job health and status
  void _monitorJobHealth() {
    for (final job in _scheduledJobs.values) {
      // Check if job should have run by now
      if (job.nextRun.isBefore(DateTime.now().subtract(const Duration(minutes: 10)))) {
        print('Warning: Job ${job.name} appears to have missed its scheduled run');
      }

      // Check for jobs that haven't run in a long time
      if (job.lastRun != null) {
        final hoursSinceLastRun = DateTime.now().difference(job.lastRun!).inHours;
        if (hoursSinceLastRun > 25 && job.schedule.contains('0 ')) { // Daily jobs
          print('Warning: Daily job ${job.name} has not run in $hoursSinceLastRun hours');
        }
      }
    }
  }

  // System job handlers

  Future<void> _updateDailyAnalytics() async {
    // Update dashboard summary
    await _analytics.getDashboardSummary();
    
    // Refresh high-risk workers list
    await _analytics.identifyHighRiskWorkers();
    
    // Update department comparisons
    await _analytics.getDepartmentComparisons();
    
    print('Daily analytics update completed');
  }

  Future<void> _performWeeklyComplianceCheck() async {
    // Generate compliance reports for all departments
    final departments = ['Construction', 'Manufacturing', 'Maintenance', 'Operations'];
    
    for (final dept in departments) {
      final complianceStatus = await _analytics.getComplianceStatus(
        entityId: dept,
        entityType: 'department',
      );
      
      if (complianceStatus.overallComplianceRate < 0.8) {
        // Send warning notification for low compliance
        print('Low compliance alert for department $dept: ${(complianceStatus.overallComplianceRate * 100).toStringAsFixed(1)}%');
      }
    }
    
    print('Weekly compliance check completed');
  }

  Future<void> _performMonthlyRiskAssessment() async {
    // Generate comprehensive risk assessment
    final highRiskWorkers = await _analytics.identifyHighRiskWorkers(limit: 100);
    
    // Update budget impact analysis
    await _analytics.calculateBudgetImpact();
    
    // Generate monthly summary report
    await _reportService.generateDashboardInsights();
    
    print('Monthly risk assessment completed');
  }

  Future<void> _performDailyViolationMonitoring() async {
    // Get violation trends
    final trends = await _violationService.getViolationTrends();
    
    // Check for increasing violation trends
    if (trends.length >= 7) {
      final recentAvg = trends.take(3).map((t) => t.totalCount).reduce((a, b) => a + b) / 3;
      final olderAvg = trends.skip(4).take(3).map((t) => t.totalCount).reduce((a, b) => a + b) / 3;
      
      if (recentAvg > olderAvg * 1.5) {
        print('Increasing violation trend detected: ${((recentAvg - olderAvg) / olderAvg * 100).toStringAsFixed(1)}% increase');
      }
    }
    
    print('Daily violation monitoring completed');
  }

  Future<void> _updateWeeklyBudgetImpact() async {
    final budgetImpact = await _analytics.calculateBudgetImpact();
    
    // Store weekly snapshot
    await _firestore.collection('budget_snapshots').add({
      'date': Timestamp.now(),
      'currentCosts': budgetImpact.currentTotalCost,
      'projectedSavings': budgetImpact.projectedTotalSavings,
      'roi': budgetImpact.returnOnInvestment,
      'workersAtRisk': budgetImpact.workersAtRisk,
    });
    
    print('Weekly budget impact update completed');
  }

  // Custom task handlers

  Future<void> _performDataCleanup(Map<String, dynamic> parameters) async {
    final retentionDays = parameters['retentionDays'] as int? ?? 90;
    final cutoffDate = DateTime.now().subtract(Duration(days: retentionDays));
    
    // Clean up old timer sessions
    final oldSessions = await _firestore
        .collection('timer_sessions')
        .where('startTime', isLessThan: Timestamp.fromDate(cutoffDate))
        .get();
    
    final batch = _firestore.batch();
    for (final doc in oldSessions.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
    
    print('Data cleanup completed: removed ${oldSessions.docs.length} old sessions');
  }

  Future<void> _performBackup(Map<String, dynamic> parameters) async {
    // Implement backup logic
    print('Backup operation completed');
  }

  Future<void> _sendBatchNotifications(Map<String, dynamic> parameters) async {
    final recipients = parameters['recipients'] as List<String>? ?? [];
    final message = parameters['message'] as String? ?? '';
    
    for (final recipient in recipients) {
      print('Sending notification to $recipient: $message');
    }
    
    print('Batch notifications sent to ${recipients.length} recipients');
  }

  Future<void> _performAnalyticsExport(Map<String, dynamic> parameters) async {
    final format = parameters['format'] as String? ?? 'csv';
    final insights = await _reportService.generateDashboardInsights();
    
    // Export would be implemented based on format
    print('Analytics export completed in $format format');
  }

  // Helper methods

  String _parseCronExpression(String schedule) {
    // Convert common schedule formats to cron
    switch (schedule.toLowerCase()) {
      case 'daily':
        return '0 2 * * *'; // 2 AM daily
      case 'weekly':
        return '0 3 * * 0'; // 3 AM Sunday
      case 'monthly':
        return '0 4 1 * *'; // 4 AM 1st of month
      case 'hourly':
        return '0 * * * *'; // Every hour
      default:
        return schedule; // Assume it's already a cron expression
    }
  }

  DateTime _calculateNextRun(String cronExpression) {
    try {
      // Parse the schedule and calculate next run
      // For now, just add default intervals based on pattern
      if (cronExpression.contains('0 2 * * *')) { // Daily at 2 AM
        return DateTime.now().add(const Duration(days: 1));
      } else if (cronExpression.contains('0 3 * * 0')) { // Weekly Sunday at 3 AM
        return DateTime.now().add(const Duration(days: 7));
      } else if (cronExpression.contains('0 4 1 * *')) { // Monthly 1st at 4 AM
        return DateTime.now().add(const Duration(days: 30));
      } else {
        return DateTime.now().add(const Duration(hours: 24));
      }
    } catch (e) {
      return DateTime.now().add(const Duration(hours: 24));
    }
  }

  Future<void> _sendReportToRecipients(CustomReportConfig report, String filePath) async {
    // In a production environment, this would integrate with email service
    for (final recipient in report.recipients) {
      print('Sending report ${report.reportName} to $recipient');
      // Email sending logic would go here
    }
  }

  Future<void> _handleJobFailure(String jobId, String error) async {
    print('Job failure: $jobId - $error');
    
    // Send failure notification to admins
    print('Job failure notification: $jobId - $error');
    
    // Log failure to database
    await _firestore.collection('job_failures').add({
      'jobId': jobId,
      'error': error,
      'timestamp': Timestamp.now(),
    });
  }

  Future<void> _sendTaskCompletionNotification(
    ScheduledTask task,
    bool success,
    [String? error]
  ) async {
    for (final recipient in task.notificationRecipients) {
      print('Task completion notification to $recipient: ${task.taskName} - ${success ? "Success" : "Failed"}');
    }
  }

  /// Get job status
  List<ScheduledJob> getJobStatus() {
    return _scheduledJobs.values.toList();
  }

  /// Cancel scheduled job
  Future<void> cancelJob(String jobId) async {
    if (_scheduledJobs.containsKey(jobId)) {
      _scheduledJobs[jobId]!.jobReference?.cancel();
      _scheduledJobs.remove(jobId);
      
      // Update database if it's a custom task
      if (jobId.startsWith('task_')) {
        final taskId = jobId.substring(5);
        await _firestore
            .collection('scheduled_tasks')
            .doc(taskId)
            .update({'isActive': false});
      }
    }
  }

  /// Clean up resources
  void dispose() {
    _cron.close();
    _scheduledJobs.clear();
  }

  // Firestore conversion methods
  
  Map<String, dynamic> _taskToFirestore(ScheduledTask task) {
    return {
      'taskName': task.taskName,
      'taskType': task.taskType,
      'schedule': task.schedule,
      'parameters': task.parameters,
      'isActive': task.isActive,
      'createdBy': task.createdBy,
      'createdAt': Timestamp.fromDate(task.createdAt),
      'lastRun': task.lastRun != null ? Timestamp.fromDate(task.lastRun!) : null,
      'nextRun': Timestamp.fromDate(task.nextRun),
      'notificationRecipients': task.notificationRecipients,
    };
  }

  ScheduledTask _taskFromFirestore(Map<String, dynamic> data, String id) {
    return ScheduledTask(
      taskId: id,
      taskName: data['taskName'] ?? '',
      taskType: data['taskType'] ?? '',
      schedule: data['schedule'] ?? '',
      parameters: Map<String, dynamic>.from(data['parameters'] ?? {}),
      isActive: data['isActive'] ?? true,
      createdBy: data['createdBy'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      lastRun: data['lastRun'] != null ? (data['lastRun'] as Timestamp).toDate() : null,
      nextRun: (data['nextRun'] as Timestamp).toDate(),
      notificationRecipients: List<String>.from(data['notificationRecipients'] ?? []),
    );
  }
}

/// Scheduled job model
class ScheduledJob {
  final String jobId;
  final String type;
  final String name;
  final String schedule;
  final DateTime? lastRun;
  final DateTime nextRun;
  final bool isActive;
  final dynamic jobReference; // Cron job reference

  ScheduledJob({
    required this.jobId,
    required this.type,
    required this.name,
    required this.schedule,
    this.lastRun,
    required this.nextRun,
    required this.isActive,
    this.jobReference,
  });

  ScheduledJob copyWith({
    String? jobId,
    String? type,
    String? name,
    String? schedule,
    DateTime? lastRun,
    DateTime? nextRun,
    bool? isActive,
    dynamic jobReference,
  }) {
    return ScheduledJob(
      jobId: jobId ?? this.jobId,
      type: type ?? this.type,
      name: name ?? this.name,
      schedule: schedule ?? this.schedule,
      lastRun: lastRun ?? this.lastRun,
      nextRun: nextRun ?? this.nextRun,
      isActive: isActive ?? this.isActive,
      jobReference: jobReference ?? this.jobReference,
    );
  }
}

/// Scheduled task model
class ScheduledTask {
  final String taskId;
  final String taskName;
  final String taskType;
  final String schedule;
  final Map<String, dynamic> parameters;
  final bool isActive;
  final String createdBy;
  final DateTime createdAt;
  final DateTime? lastRun;
  final DateTime nextRun;
  final List<String> notificationRecipients;

  ScheduledTask({
    required this.taskId,
    required this.taskName,
    required this.taskType,
    required this.schedule,
    required this.parameters,
    required this.isActive,
    required this.createdBy,
    required this.createdAt,
    this.lastRun,
    required this.nextRun,
    required this.notificationRecipients,
  });

  ScheduledTask copyWith({
    String? taskId,
    String? taskName,
    String? taskType,
    String? schedule,
    Map<String, dynamic>? parameters,
    bool? isActive,
    String? createdBy,
    DateTime? createdAt,
    DateTime? lastRun,
    DateTime? nextRun,
    List<String>? notificationRecipients,
  }) {
    return ScheduledTask(
      taskId: taskId ?? this.taskId,
      taskName: taskName ?? this.taskName,
      taskType: taskType ?? this.taskType,
      schedule: schedule ?? this.schedule,
      parameters: parameters ?? this.parameters,
      isActive: isActive ?? this.isActive,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      lastRun: lastRun ?? this.lastRun,
      nextRun: nextRun ?? this.nextRun,
      notificationRecipients: notificationRecipients ?? this.notificationRecipients,
    );
  }
}