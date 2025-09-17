import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';
import 'package:stacked_services/stacked_services.dart';
import 'package:get_it/get_it.dart';

import '../../models/tool/advanced_tool_models.dart';

@lazySingleton
class ToolPerformanceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  SnackbarService get _snackbarService => GetIt.instance<SnackbarService>();

  static const String _collection = 'tool_performance_metrics';

  // Get all performance metrics for a company
  Stream<List<ToolPerformanceMetric>> getCompanyMetrics(String companyId) {
    return _firestore
        .collection(_collection)
        .where('companyId', isEqualTo: companyId)
        .orderBy('recordedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ToolPerformanceMetric.fromFirestore(doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  // Get performance metrics for a specific tool
  Stream<List<ToolPerformanceMetric>> getToolMetrics(String toolId) {
    return _firestore
        .collection(_collection)
        .where('toolId', isEqualTo: toolId)
        .orderBy('recordedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ToolPerformanceMetric.fromFirestore(doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  // Get metrics by performance type
  Stream<List<ToolPerformanceMetric>> getMetricsByType(String companyId, PerformanceMetricType type) {
    return _firestore
        .collection(_collection)
        .where('companyId', isEqualTo: companyId)
        .where('metricType', isEqualTo: type.name)
        .orderBy('recordedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ToolPerformanceMetric.fromFirestore(doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  // Get declining performance alerts
  Stream<List<ToolPerformanceMetric>> getDecliningPerformanceAlerts(String companyId) {
    return _firestore
        .collection(_collection)
        .where('companyId', isEqualTo: companyId)
        .orderBy('recordedDate', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ToolPerformanceMetric.fromFirestore(doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  // Get recent metrics for dashboard
  Stream<List<ToolPerformanceMetric>> getRecentMetrics(String companyId, {int days = 7}) {
    final cutoffDate = DateTime.now().subtract(Duration(days: days));
    return _firestore
        .collection(_collection)
        .where('companyId', isEqualTo: companyId)
        .where('recordedAt', isGreaterThan: cutoffDate.toIso8601String())
        .orderBy('recordedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ToolPerformanceMetric.fromFirestore(doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  // Get specific performance metric
  Future<ToolPerformanceMetric?> getPerformanceMetric(String metricId) async {
    try {
      final doc = await _firestore
          .collection(_collection)
          .doc(metricId)
          .get();

      if (doc.exists && doc.data() != null) {
        return ToolPerformanceMetric.fromFirestore(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      print('Error getting performance metric: $e');
      return null;
    }
  }

  // Record performance metric
  Future<bool> recordPerformanceMetric({
    required String companyId,
    required String toolId,
    required PerformanceMetricType metricType,
    required double value,
    required String unit,
    String? recordedBy,
    String? recordedByName,
    String? jobSiteId,
    String? workSession,
    String? notes,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      // Get baseline for comparison
      final baseline = await _getBaselineValue(toolId, metricType);
      
      // Calculate degradation percentage
      double? degradationPercentage;
      bool isDecline = false;

      if (baseline != null && baseline > 0) {
        degradationPercentage = ((baseline - value) / baseline) * 100;
        isDecline = degradationPercentage > 10; // Consider >10% degradation as decline
      }

      final metric = ToolPerformanceMetric(
        id: '',
        metricId: _generateMetricId(),
        toolId: toolId,
        metricType: metricType.name,
        value: value,
        unit: unit,
        recordedDate: DateTime.now(),
        recordedByWorkerId: recordedBy,
        sessionId: workSession,
        context: {
          if (baseline != null) 'baselineValue': baseline,
          if (degradationPercentage != null) 'degradationPercentage': degradationPercentage,
          'isDecline': isDecline,
        },
        metadata: {
          'companyId': companyId,
          if (jobSiteId != null) 'jobSiteId': jobSiteId,
          if (recordedByName != null) 'recordedByName': recordedByName,
          if (notes != null) 'notes': notes,
          'alertGenerated': false,
          ...metadata ?? {},
        },
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isActive: true,
      );

      await _firestore
          .collection(_collection)
          .add(metric.toJson());

      // Update baseline if this is a better value
      if (baseline == null || (metricType == PerformanceMetricType.efficiency && value > baseline)) {
        await _updateBaseline(toolId, metricType, value);
      }

      _snackbarService.showSnackbar(
        message: 'Performance metric recorded successfully!',
      );
      
      print('✅ Performance metric recorded: ${metric.metricId}');
      return true;
    } catch (e) {
      print('❌ Error recording performance metric: $e');
      _snackbarService.showSnackbar(
        message: 'Failed to record performance metric: ${e.toString()}',
      );
      return false;
    }
  }

  // Bulk record metrics (for batch processing)
  Future<bool> bulkRecordMetrics(List<ToolPerformanceMetric> metrics) async {
    try {
      final batch = _firestore.batch();

      for (final metric in metrics) {
        final docRef = _firestore.collection(_collection).doc();
        batch.set(docRef, metric.toJson());
      }

      await batch.commit();

      _snackbarService.showSnackbar(
        message: 'Bulk performance metrics recorded: ${metrics.length} items',
      );
      
      print('✅ Bulk metrics recorded: ${metrics.length} items');
      return true;
    } catch (e) {
      print('❌ Error bulk recording metrics: $e');
      _snackbarService.showSnackbar(
        message: 'Failed to bulk record metrics: ${e.toString()}',
      );
      return false;
    }
  }

  // Mark alert as generated
  Future<bool> markAlertGenerated(String metricId) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(metricId)
          .update({
        'alertGenerated': true,
        'updatedAt': DateTime.now().toIso8601String(),
      });

      print('✅ Alert marked as generated: $metricId');
      return true;
    } catch (e) {
      print('❌ Error marking alert as generated: $e');
      return false;
    }
  }

  // Get performance trends for a tool
  Future<Map<String, List<Map<String, dynamic>>>> getPerformanceTrends(
    String toolId, {
    int days = 30,
  }) async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: days));
      final snapshot = await _firestore
          .collection(_collection)
          .where('toolId', isEqualTo: toolId)
          .where('recordedAt', isGreaterThan: cutoffDate.toIso8601String())
          .orderBy('recordedAt')
          .get();

      final metrics = snapshot.docs
          .map((doc) => ToolPerformanceMetric.fromFirestore(doc.data() as Map<String, dynamic>, doc.id))
          .toList();

      final trends = <String, List<Map<String, dynamic>>>{};

      for (final metric in metrics) {
        final typeKey = metric.metricType;
        trends[typeKey] ??= [];
        trends[typeKey]!.add({
          'date': metric.recordedDate.toIso8601String(),
          'value': metric.value,
          'baseline': metric.context['baselineValue'],
          'degradation': metric.context['degradationPercentage'],
          'isDecline': metric.context['isDecline'],
        });
      }

      return trends;
    } catch (e) {
      print('❌ Error getting performance trends: $e');
      return {};
    }
  }

  // Get performance summary for a tool
  Future<Map<String, dynamic>> getToolPerformanceSummary(String toolId) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('toolId', isEqualTo: toolId)
          .orderBy('recordedAt', descending: true)
          .get();

      final metrics = snapshot.docs
          .map((doc) => ToolPerformanceMetric.fromFirestore(doc.data() as Map<String, dynamic>, doc.id))
          .toList();

      if (metrics.isEmpty) {
        return {'hasData': false};
      }

      // Group by metric type
      final metricGroups = <String, List<ToolPerformanceMetric>>{};
      for (final metric in metrics) {
        final typeKey = metric.metricType;
        metricGroups[typeKey] ??= [];
        metricGroups[typeKey]!.add(metric);
      }

      final summary = <String, dynamic>{
        'hasData': true,
        'totalRecords': metrics.length,
        'lastRecorded': metrics.first.recordedDate.toIso8601String(),
        'metricTypes': metricGroups.keys.toList(),
        'degradationAlerts': metrics.where((m) => m.context['isDecline'] == true).length,
      };

      // Calculate averages and trends for each metric type
      for (final entry in metricGroups.entries) {
        final typeMetrics = entry.value;
        final latest = typeMetrics.first;
        final average = typeMetrics.fold<double>(0, (sum, m) => sum + m.value) / typeMetrics.length;
        
        // Calculate trend (comparing last 5 vs previous 5 records)
        double? trend;
        if (typeMetrics.length >= 10) {
          final recent = typeMetrics.take(5).map((m) => m.value).reduce((a, b) => a + b) / 5;
          final previous = typeMetrics.skip(5).take(5).map((m) => m.value).reduce((a, b) => a + b) / 5;
          trend = ((recent - previous) / previous) * 100;
        }

        summary['${entry.key}_latest'] = latest.value;
        summary['${entry.key}_average'] = average;
        summary['${entry.key}_trend'] = trend;
        summary['${entry.key}_unit'] = latest.unit;
        summary['${entry.key}_baseline'] = latest.context['baselineValue'];
      }

      return summary;
    } catch (e) {
      print('❌ Error getting tool performance summary: $e');
      return {'hasData': false};
    }
  }

  // Get performance statistics for company
  Future<Map<String, dynamic>> getPerformanceStats(String companyId) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('companyId', isEqualTo: companyId)
          .get();

      final metrics = snapshot.docs
          .map((doc) => ToolPerformanceMetric.fromFirestore(doc.data() as Map<String, dynamic>, doc.id))
          .toList();

      final toolsWithDecline = metrics
          .where((m) => m.context['isDecline'] == true)
          .map((m) => m.toolId)
          .toSet()
          .length;

      final metricTypeCounts = <String, int>{};
      for (final metric in metrics) {
        metricTypeCounts[metric.metricType] = 
            (metricTypeCounts[metric.metricType] ?? 0) + 1;
      }

      // Calculate performance score (percentage of tools NOT in decline)
      final totalTools = metrics.map((m) => m.toolId).toSet().length;
      final performanceScore = totalTools > 0 
          ? ((totalTools - toolsWithDecline) / totalTools * 100)
          : 0.0;

      // Recent trends
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      final recentMetrics = metrics.where((m) => m.recordedDate.isAfter(thirtyDaysAgo)).toList();
      final recentDeclines = recentMetrics.where((m) => m.context['isDecline'] == true).length;

      return {
        'totalMetrics': metrics.length,
        'toolsWithDecline': toolsWithDecline,
        'totalToolsTracked': totalTools,
        'performanceScore': performanceScore,
        'metricTypeBreakdown': metricTypeCounts,
        'recentMetrics': recentMetrics.length,
        'recentDeclines': recentDeclines,
        'declineRate': recentMetrics.isNotEmpty 
            ? (recentDeclines / recentMetrics.length * 100) 
            : 0.0,
      };
    } catch (e) {
      print('❌ Error getting performance stats: $e');
      return {};
    }
  }

  // Search performance metrics
  Future<List<ToolPerformanceMetric>> searchMetrics(String companyId, String query) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('companyId', isEqualTo: companyId)
          .get();

      final metrics = snapshot.docs
          .map((doc) => ToolPerformanceMetric.fromFirestore(doc.data() as Map<String, dynamic>, doc.id))
          .where((metric) =>
              (metric.metadata?['recordedByName']?.toString().toLowerCase() ?? '').contains(query.toLowerCase()) ||
              metric.metricId.toLowerCase().contains(query.toLowerCase()) ||
              (metric.metadata?['notes']?.toString().toLowerCase() ?? '').contains(query.toLowerCase()) ||
              (metric.sessionId?.toLowerCase() ?? '').contains(query.toLowerCase()))
          .toList();

      return metrics;
    } catch (e) {
      print('❌ Error searching performance metrics: $e');
      return [];
    }
  }

  // Export performance data (returns data for export)
  Future<List<Map<String, dynamic>>> exportPerformanceData({
    required String companyId,
    String? toolId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      Query query = _firestore
          .collection(_collection)
          .where('companyId', isEqualTo: companyId);

      if (toolId != null) {
        query = query.where('toolId', isEqualTo: toolId);
      }

      if (startDate != null) {
        query = query.where('recordedAt', isGreaterThanOrEqualTo: startDate.toIso8601String());
      }

      if (endDate != null) {
        query = query.where('recordedAt', isLessThanOrEqualTo: endDate.toIso8601String());
      }

      final snapshot = await query.orderBy('recordedAt').get();

      return snapshot.docs
          .map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final context = data['context'] as Map<String, dynamic>? ?? {};
            final metadata = data['metadata'] as Map<String, dynamic>? ?? {};
            return {
                'metricId': data['metricId'],
                'toolId': data['toolId'],
                'metricType': data['metricType'],
                'value': data['value'],
                'unit': data['unit'],
                'baselineValue': context['baselineValue'],
                'degradationPercentage': context['degradationPercentage'],
                'isDecline': context['isDecline'],
                'recordedBy': metadata['recordedByName'],
                'recordedAt': data['recordedDate'],
                'jobSiteId': metadata['jobSiteId'],
                'notes': metadata['notes'],
              };
            })
          .toList();
    } catch (e) {
      print('❌ Error exporting performance data: $e');
      return [];
    }
  }

  // Generate metric ID
  String _generateMetricId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'PM${timestamp.toString().substring(6)}';
  }

  // Get baseline value for a metric type
  Future<double?> _getBaselineValue(String toolId, PerformanceMetricType metricType) async {
    try {
      final snapshot = await _firestore
          .collection('tool_baselines')
          .where('toolId', isEqualTo: toolId)
          .where('metricType', isEqualTo: metricType.name)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.first.data()['value']?.toDouble();
      }
      return null;
    } catch (e) {
      print('Error getting baseline value: $e');
      return null;
    }
  }

  // Update baseline value
  Future<bool> _updateBaseline(String toolId, PerformanceMetricType metricType, double value) async {
    try {
      final baselineDoc = {
        'toolId': toolId,
        'metricType': metricType.name,
        'value': value,
        'updatedAt': DateTime.now().toIso8601String(),
      };

      await _firestore
          .collection('tool_baselines')
          .doc('${toolId}_${metricType.name}')
          .set(baselineDoc, SetOptions(merge: true));

      return true;
    } catch (e) {
      print('Error updating baseline: $e');
      return false;
    }
  }

  // Process performance alerts (batch job)
  Future<List<String>> processPerformanceAlerts(String companyId) async {
    try {
      // Note: Querying by isDecline/alertGenerated requires filtering after retrieval
      // since they're stored in context/metadata maps
      final snapshot = await _firestore
          .collection(_collection)
          .where('metadata.companyId', isEqualTo: companyId)
          .get();

      final alerts = <String>[];
      final batch = _firestore.batch();

      for (final doc in snapshot.docs) {
        final metric = ToolPerformanceMetric.fromFirestore(doc.data() as Map<String, dynamic>, doc.id);
        
        // Create alert message
        final alertMessage = 'Tool ${metric.toolId} showing ${metric.context['degradationPercentage']?.toStringAsFixed(1)}% '
            'degradation in ${metric.metricType}';
        alerts.add(alertMessage);

        // Mark alert as generated
        batch.update(doc.reference, {
          'alertGenerated': true,
          'updatedAt': DateTime.now().toIso8601String(),
        });
      }

      if (alerts.isNotEmpty) {
        await batch.commit();
      }

      print('✅ Processed ${alerts.length} performance alerts');
      return alerts;
    } catch (e) {
      print('❌ Error processing performance alerts: $e');
      return [];
    }
  }
}