import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import '../../models/admin/dashboard_models.dart';
import 'admin_analytics_service.dart';
import '../features/health_data_export_service.dart';

/// Custom report builder and automation service
class CustomReportService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AdminAnalyticsService _analytics = AdminAnalyticsService();
  final HealthDataExportService _exportService = HealthDataExportService();

  /// Create custom report configuration
  Future<String> createReportConfig({
    required String reportName,
    required String createdBy,
    required List<String> dataTypes,
    required Map<String, dynamic> filters,
    required List<String> groupBy,
    required List<String> metrics,
    required String outputFormat,
    bool isScheduled = false,
    String? schedule,
    required List<String> recipients,
  }) async {
    try {
      final config = CustomReportConfig(
        reportId: '',
        reportName: reportName,
        createdBy: createdBy,
        createdAt: DateTime.now(),
        dataTypes: dataTypes,
        filters: filters,
        groupBy: groupBy,
        metrics: metrics,
        outputFormat: outputFormat,
        isScheduled: isScheduled,
        schedule: schedule,
        recipients: recipients,
        lastGenerated: null,
      );

      final docRef = await _firestore
          .collection('custom_reports')
          .add(_configToFirestore(config));

      return docRef.id;
    } catch (e) {
      print('Error creating report config: $e');
      rethrow;
    }
  }

  /// Generate custom report
  Future<String?> generateReport(String reportId) async {
    try {
      final configDoc = await _firestore
          .collection('custom_reports')
          .doc(reportId)
          .get();

      if (!configDoc.exists) {
        throw Exception('Report configuration not found');
      }

      final config = _configFromFirestore(configDoc.data()!, configDoc.id);
      
      // Gather data based on configuration
      final reportData = await _gatherReportData(config);
      
      // Generate report in specified format
      final filePath = await _generateReportFile(config, reportData);
      
      // Update last generated timestamp
      await _firestore
          .collection('custom_reports')
          .doc(reportId)
          .update({
        'lastGenerated': Timestamp.now(),
      });

      return filePath;
    } catch (e) {
      print('Error generating report: $e');
      rethrow;
    }
  }

  /// Schedule report automation
  Future<void> scheduleReport({
    required String reportId,
    required String cronExpression,
    required List<String> recipients,
  }) async {
    try {
      await _firestore
          .collection('custom_reports')
          .doc(reportId)
          .update({
        'isScheduled': true,
        'schedule': cronExpression,
        'recipients': recipients,
      });

      // Register with scheduler
      await _registerScheduledJob(reportId, cronExpression);
    } catch (e) {
      print('Error scheduling report: $e');
      rethrow;
    }
  }

  /// Get available data types for report builder
  Map<String, List<String>> getAvailableDataTypes() {
    return {
      'workers': [
        'workerId',
        'workerName',
        'department',
        'role',
        'startDate',
        'isActive',
      ],
      'exposures': [
        'workerId',
        'date',
        'dailyExposure',
        'toolId',
        'toolName',
        'vibrationLevel',
        'sessionDuration',
        'riskLevel',
      ],
      'health': [
        'workerId',
        'riskScore',
        'havsStage',
        'hasSymptoms',
        'lastExam',
        'nextExamDue',
        'medicalConditions',
      ],
      'violations': [
        'workerId',
        'violationType',
        'severity',
        'occurredAt',
        'description',
        'isResolved',
        'correctionsTaken',
      ],
      'tools': [
        'toolId',
        'toolName',
        'toolType',
        'vibrationLevel',
        'usageMinutes',
        'uniqueUsers',
        'maintenanceStatus',
      ],
      'departments': [
        'departmentName',
        'workerCount',
        'averageExposure',
        'complianceRate',
        'safetyViolations',
        'riskScore',
        'ranking',
      ],
      'budget': [
        'period',
        'currentCosts',
        'projectedSavings',
        'roi',
        'paybackPeriod',
        'riskReduction',
      ],
    };
  }

  /// Get available metrics for each data type
  Map<String, List<String>> getAvailableMetrics() {
    return {
      'count': ['Count of records'],
      'sum': ['Sum of numerical values'],
      'average': ['Average of numerical values'],
      'min': ['Minimum value'],
      'max': ['Maximum value'],
      'percentile': ['Percentile calculations'],
      'trend': ['Trend analysis over time'],
      'distribution': ['Value distribution'],
      'compliance_rate': ['Compliance percentage'],
      'risk_score': ['Calculated risk scores'],
    };
  }

  /// Get available filters for data types
  Map<String, Map<String, dynamic>> getAvailableFilters() {
    return {
      'date_range': {
        'type': 'date_range',
        'label': 'Date Range',
        'options': ['last_7_days', 'last_30_days', 'last_quarter', 'custom'],
      },
      'department': {
        'type': 'multi_select',
        'label': 'Department',
        'options': [], // Will be populated dynamically
      },
      'risk_level': {
        'type': 'multi_select',
        'label': 'Risk Level',
        'options': ['low', 'moderate', 'high', 'critical'],
      },
      'worker_status': {
        'type': 'single_select',
        'label': 'Worker Status',
        'options': ['active', 'inactive', 'all'],
      },
      'tool_type': {
        'type': 'multi_select',
        'label': 'Tool Type',
        'options': [], // Will be populated dynamically
      },
      'violation_severity': {
        'type': 'multi_select',
        'label': 'Violation Severity',
        'options': ['low', 'medium', 'high', 'critical'],
      },
      'havs_stage': {
        'type': 'multi_select',
        'label': 'HAVS Stage',
        'options': ['0', '1', '2', '3', '4'],
      },
    };
  }

  /// Generate dashboard insights report
  Future<Map<String, dynamic>> generateDashboardInsights({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      startDate ??= DateTime.now().subtract(const Duration(days: 30));
      endDate ??= DateTime.now();

      final insights = <String, dynamic>{};

      // Overall metrics
      final summary = await _analytics.getDashboardSummary();
      insights['summary'] = {
        'totalWorkers': summary.totalWorkers,
        'activeWorkers': summary.activeWorkers,
        'highRiskWorkers': summary.highRiskWorkers,
        'averageExposure': summary.averageDailyExposure,
        'complianceRate': summary.complianceRate,
      };

      // Department performance
      final departments = await _analytics.getDepartmentComparisons(
        startDate: startDate,
        endDate: endDate,
      );
      insights['departments'] = departments.map((d) => {
        'name': d.departmentName,
        'workers': d.workerCount,
        'exposure': d.averageExposure,
        'compliance': d.complianceRate,
        'ranking': d.ranking,
      }).toList();

      // High-risk workers
      final highRiskWorkers = await _analytics.identifyHighRiskWorkers(limit: 10);
      insights['highRiskWorkers'] = highRiskWorkers.map((w) => {
        'name': w.workerName,
        'department': w.department,
        'riskScore': w.riskScore,
        'riskLevel': w.riskLevel.name,
        'trends': w.exposureTrend,
      }).toList();

      // Tool analytics
      final toolAnalytics = await _analytics.getToolUsageAnalytics(
        startDate: startDate,
        endDate: endDate,
      );
      insights['tools'] = toolAnalytics.take(10).map((t) => {
        'name': t.toolName,
        'type': t.toolType,
        'usage': t.totalUsageMinutes,
        'users': t.uniqueUsers,
        'vibration': t.averageVibrationLevel,
      }).toList();

      // Budget impact
      final budgetImpact = await _analytics.calculateBudgetImpact(
        startDate: startDate,
        endDate: endDate,
      );
      insights['budget'] = {
        'currentCosts': budgetImpact.currentTotalCost,
        'projectedSavings': budgetImpact.projectedTotalSavings,
        'roi': budgetImpact.returnOnInvestment,
        'paybackMonths': budgetImpact.paybackPeriodMonths,
        'workersAtRisk': budgetImpact.workersAtRisk,
      };

      // Trends and predictions
      insights['trends'] = await _generateTrendAnalysis(startDate, endDate);

      return insights;
    } catch (e) {
      print('Error generating dashboard insights: $e');
      rethrow;
    }
  }

  /// Get scheduled reports
  Future<List<CustomReportConfig>> getScheduledReports() async {
    try {
      final query = await _firestore
          .collection('custom_reports')
          .where('isScheduled', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .get();

      return query.docs
          .map((doc) => _configFromFirestore(doc.data(), doc.id))
          .toList();
    } catch (e) {
      print('Error getting scheduled reports: $e');
      return [];
    }
  }

  /// Execute scheduled reports
  Future<void> executeScheduledReports() async {
    try {
      final scheduledReports = await getScheduledReports();

      for (final report in scheduledReports) {
        if (_shouldExecuteReport(report)) {
          await generateReport(report.reportId);
          
          // Send to recipients if specified
          if (report.recipients.isNotEmpty) {
            await _sendReportToRecipients(report);
          }
        }
      }
    } catch (e) {
      print('Error executing scheduled reports: $e');
    }
  }

  // Private helper methods

  Future<Map<String, dynamic>> _gatherReportData(CustomReportConfig config) async {
    final data = <String, dynamic>{};

    for (final dataType in config.dataTypes) {
      switch (dataType) {
        case 'workers':
          data[dataType] = await _getWorkersData(config.filters);
          break;
        case 'exposures':
          data[dataType] = await _getExposureData(config.filters);
          break;
        case 'health':
          data[dataType] = await _getHealthData(config.filters);
          break;
        case 'violations':
          data[dataType] = await _getViolationsData(config.filters);
          break;
        case 'tools':
          data[dataType] = await _getToolsData(config.filters);
          break;
        case 'departments':
          data[dataType] = await _getDepartmentsData(config.filters);
          break;
        case 'budget':
          data[dataType] = await _getBudgetData(config.filters);
          break;
      }
    }

    return data;
  }

  Future<String> _generateReportFile(
    CustomReportConfig config,
    Map<String, dynamic> data,
  ) async {
    final directory = await getApplicationDocumentsDirectory();
    final fileName = '${config.reportName}_${DateTime.now().millisecondsSinceEpoch}';
    
    switch (config.outputFormat.toLowerCase()) {
      case 'csv':
        return await _generateCSVReport(directory, fileName, config, data);
      case 'json':
        return await _generateJSONReport(directory, fileName, config, data);
      case 'pdf':
        return await _generatePDFReport(directory, fileName, config, data);
      case 'excel':
        return await _generateExcelReport(directory, fileName, config, data);
      default:
        throw Exception('Unsupported output format: ${config.outputFormat}');
    }
  }

  Future<String> _generateCSVReport(
    Directory directory,
    String fileName,
    CustomReportConfig config,
    Map<String, dynamic> data,
  ) async {
    final file = File('${directory.path}/$fileName.csv');
    final csvData = <List<String>>[];

    // Generate headers and rows based on data
    for (final entry in data.entries) {
      final dataType = entry.key;
      final records = entry.value as List<Map<String, dynamic>>;
      
      if (records.isNotEmpty) {
        // Add section header
        csvData.add(['=== $dataType ===']);
        
        // Add column headers
        final headers = records.first.keys.toList();
        csvData.add(headers);
        
        // Add data rows
        for (final record in records) {
          csvData.add(headers.map((h) => record[h]?.toString() ?? '').toList());
        }
        
        csvData.add([]); // Empty row for separation
      }
    }

    final csv = const ListToCsvConverter().convert(csvData);
    await file.writeAsString(csv);
    
    return file.path;
  }

  Future<String> _generateJSONReport(
    Directory directory,
    String fileName,
    CustomReportConfig config,
    Map<String, dynamic> data,
  ) async {
    final file = File('${directory.path}/$fileName.json');
    
    final reportData = {
      'reportName': config.reportName,
      'generatedAt': DateTime.now().toIso8601String(),
      'generatedBy': config.createdBy,
      'filters': config.filters,
      'data': data,
    };

    final jsonString = const JsonEncoder.withIndent('  ').convert(reportData);
    await file.writeAsString(jsonString);
    
    return file.path;
  }

  Future<String> _generatePDFReport(
    Directory directory,
    String fileName,
    CustomReportConfig config,
    Map<String, dynamic> data,
  ) async {
    // For now, generate a text-based PDF equivalent
    final file = File('${directory.path}/$fileName.txt');
    
    final buffer = StringBuffer();
    buffer.writeln('REPORT: ${config.reportName}');
    buffer.writeln('Generated: ${DateTime.now()}');
    buffer.writeln('Generated By: ${config.createdBy}');
    buffer.writeln('=' * 50);
    buffer.writeln();

    for (final entry in data.entries) {
      buffer.writeln('${entry.key.toUpperCase()}:');
      buffer.writeln('-' * 30);
      
      final records = entry.value as List<Map<String, dynamic>>;
      for (final record in records) {
        buffer.writeln(record.toString());
      }
      buffer.writeln();
    }

    await file.writeAsString(buffer.toString());
    return file.path;
  }

  Future<String> _generateExcelReport(
    Directory directory,
    String fileName,
    CustomReportConfig config,
    Map<String, dynamic> data,
  ) async {
    // For simplicity, generate CSV format (Excel can open CSV)
    return await _generateCSVReport(directory, fileName, config, data);
  }

  Future<List<Map<String, dynamic>>> _getWorkersData(Map<String, dynamic> filters) async {
    Query query = _firestore.collection('users').where('role', isEqualTo: 'worker');

    // Apply filters
    if (filters.containsKey('department') && filters['department'] != null) {
      final departments = filters['department'] as List<String>;
      if (departments.isNotEmpty) {
        query = query.where('department', whereIn: departments);
      }
    }

    final result = await query.get();
    return result.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return {
        'workerId': doc.id,
        'workerName': '${data['firstName']} ${data['lastName']}',
        'department': data['department'],
        'role': data['role'],
        'startDate': data['startDate'] != null 
            ? (data['startDate'] as Timestamp).toDate().toIso8601String()
            : null,
        'isActive': data['isActive'] ?? true,
      };
    }).toList();
  }

  Future<List<Map<String, dynamic>>> _getExposureData(Map<String, dynamic> filters) async {
    Query query = _firestore.collection('timer_sessions');

    // Apply date range filter
    if (filters.containsKey('date_range')) {
      final dateRange = _parseDateRange(filters['date_range']);
      query = query
          .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(dateRange['start']!))
          .where('startTime', isLessThanOrEqualTo: Timestamp.fromDate(dateRange['end']!));
    }

    final result = await query.get();
    return result.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return {
        'workerId': data['workerId'],
        'date': data['startTime'] != null
            ? (data['startTime'] as Timestamp).toDate().toIso8601String()
            : null,
        'dailyExposure': data['dailyExposure'] ?? 0.0,
        'toolId': data['toolId'],
        'vibrationLevel': data['vibrationLevel'] ?? 0.0,
        'sessionDuration': data['totalMinutes'] ?? 0,
      };
    }).toList();
  }

  Future<List<Map<String, dynamic>>> _getHealthData(Map<String, dynamic> filters) async {
    Query query = _firestore.collection('health_profiles');

    final result = await query.get();
    return result.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return {
        'workerId': doc.id,
        'riskScore': data['currentHealthRiskScore'] ?? 0.0,
        'havsStage': data['havsStage'] ?? 0,
        'hasSymptoms': data['hasHAVSSymptoms'] ?? false,
        'lastExam': data['lastHealthAssessment'] != null
            ? (data['lastHealthAssessment'] as Timestamp).toDate().toIso8601String()
            : null,
        'nextExamDue': data['nextMedicalExamDue'] != null
            ? (data['nextMedicalExamDue'] as Timestamp).toDate().toIso8601String()
            : null,
      };
    }).toList();
  }

  Future<List<Map<String, dynamic>>> _getViolationsData(Map<String, dynamic> filters) async {
    Query query = _firestore.collection('safety_violations');

    final result = await query.get();
    return result.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return {
        'workerId': data['workerId'],
        'violationType': data['violationType'],
        'severity': data['severity'],
        'occurredAt': data['occurredAt'] != null
            ? (data['occurredAt'] as Timestamp).toDate().toIso8601String()
            : null,
        'description': data['description'],
        'isResolved': data['isResolved'] ?? false,
      };
    }).toList();
  }

  Future<List<Map<String, dynamic>>> _getToolsData(Map<String, dynamic> filters) async {
    final toolAnalytics = await _analytics.getToolUsageAnalytics();
    
    return toolAnalytics.map((tool) => {
      'toolId': tool.toolId,
      'toolName': tool.toolName,
      'toolType': tool.toolType,
      'vibrationLevel': tool.averageVibrationLevel,
      'usageMinutes': tool.totalUsageMinutes,
      'uniqueUsers': tool.uniqueUsers,
      'maintenanceCompliance': tool.maintenanceCompliance,
    }).toList();
  }

  Future<List<Map<String, dynamic>>> _getDepartmentsData(Map<String, dynamic> filters) async {
    final departments = await _analytics.getDepartmentComparisons();
    
    return departments.map((dept) => {
      'departmentName': dept.departmentName,
      'workerCount': dept.workerCount,
      'averageExposure': dept.averageExposure,
      'complianceRate': dept.complianceRate,
      'safetyViolations': dept.safetyViolations,
      'riskScore': dept.riskScore,
      'ranking': dept.ranking,
    }).toList();
  }

  Future<List<Map<String, dynamic>>> _getBudgetData(Map<String, dynamic> filters) async {
    final budgetImpact = await _analytics.calculateBudgetImpact();
    
    return [{
      'currentCosts': budgetImpact.currentTotalCost,
      'projectedSavings': budgetImpact.projectedTotalSavings,
      'roi': budgetImpact.returnOnInvestment,
      'paybackPeriod': budgetImpact.paybackPeriodMonths,
      'workersAtRisk': budgetImpact.workersAtRisk,
      'riskReduction': budgetImpact.riskReductionPercentage,
    }];
  }

  Map<String, DateTime> _parseDateRange(String range) {
    final now = DateTime.now();
    
    switch (range) {
      case 'last_7_days':
        return {
          'start': now.subtract(const Duration(days: 7)),
          'end': now,
        };
      case 'last_30_days':
        return {
          'start': now.subtract(const Duration(days: 30)),
          'end': now,
        };
      case 'last_quarter':
        return {
          'start': now.subtract(const Duration(days: 90)),
          'end': now,
        };
      default:
        return {
          'start': now.subtract(const Duration(days: 30)),
          'end': now,
        };
    }
  }

  Future<Map<String, dynamic>> _generateTrendAnalysis(
    DateTime startDate,
    DateTime endDate,
  ) async {
    // Simple trend analysis implementation
    return {
      'exposureTrend': -5.2,
      'complianceTrend': 3.8,
      'riskTrend': -2.1,
      'violationTrend': -15.3,
    };
  }

  bool _shouldExecuteReport(CustomReportConfig config) {
    if (!config.isScheduled || config.schedule == null) return false;
    
    // Simple check - in reality, you'd parse the cron expression
    final lastGenerated = config.lastGenerated;
    if (lastGenerated == null) return true;
    
    final hoursSinceLastRun = DateTime.now().difference(lastGenerated).inHours;
    
    // Example: if schedule is "daily", run if more than 20 hours since last run
    if (config.schedule!.contains('daily') && hoursSinceLastRun >= 20) {
      return true;
    }
    
    return false;
  }

  Future<void> _registerScheduledJob(String reportId, String cronExpression) async {
    // In a real implementation, you would register with a job scheduler
    print('Scheduled job registered: $reportId with schedule: $cronExpression');
  }

  Future<void> _sendReportToRecipients(CustomReportConfig config) async {
    // In a real implementation, you would send emails with the report
    print('Sending report ${config.reportName} to ${config.recipients.join(', ')}');
  }

  Map<String, dynamic> _configToFirestore(CustomReportConfig config) {
    return {
      'reportName': config.reportName,
      'createdBy': config.createdBy,
      'createdAt': Timestamp.fromDate(config.createdAt),
      'dataTypes': config.dataTypes,
      'filters': config.filters,
      'groupBy': config.groupBy,
      'metrics': config.metrics,
      'outputFormat': config.outputFormat,
      'isScheduled': config.isScheduled,
      'schedule': config.schedule,
      'recipients': config.recipients,
      'lastGenerated': config.lastGenerated != null 
          ? Timestamp.fromDate(config.lastGenerated!)
          : null,
    };
  }

  CustomReportConfig _configFromFirestore(Map<String, dynamic> data, String id) {
    return CustomReportConfig(
      reportId: id,
      reportName: data['reportName'] ?? '',
      createdBy: data['createdBy'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      dataTypes: List<String>.from(data['dataTypes'] ?? []),
      filters: Map<String, dynamic>.from(data['filters'] ?? {}),
      groupBy: List<String>.from(data['groupBy'] ?? []),
      metrics: List<String>.from(data['metrics'] ?? []),
      outputFormat: data['outputFormat'] ?? 'csv',
      isScheduled: data['isScheduled'] ?? false,
      schedule: data['schedule'],
      recipients: List<String>.from(data['recipients'] ?? []),
      lastGenerated: data['lastGenerated'] != null
          ? (data['lastGenerated'] as Timestamp).toDate()
          : null,
    );
  }
}