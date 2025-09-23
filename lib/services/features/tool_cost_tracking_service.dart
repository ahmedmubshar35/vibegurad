import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';
import 'package:stacked_services/stacked_services.dart';
import 'package:get_it/get_it.dart';
import 'dart:math' as math;

import '../../models/tool/advanced_tool_models.dart';
import '../core/notification_manager.dart';

@lazySingleton
class ToolCostTrackingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  SnackbarService get _snackbarService => GetIt.instance<SnackbarService>();

  static const String _collection = 'tool_cost_records';

  // Get all cost records for a company
  Stream<List<ToolCostRecord>> getCompanyCostRecords(String companyId) {
    return _firestore
        .collection(_collection)
        .where('companyId', isEqualTo: companyId)
        .where('isActive', isEqualTo: true)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ToolCostRecord.fromFirestore(doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  // Get cost records for a specific tool
  Stream<List<ToolCostRecord>> getToolCostHistory(String toolId) {
    return _firestore
        .collection(_collection)
        .where('toolId', isEqualTo: toolId)
        .where('isActive', isEqualTo: true)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ToolCostRecord.fromFirestore(doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  // Get cost records by type
  Stream<List<ToolCostRecord>> getCostRecordsByType(String companyId, CostType costType) {
    return _firestore
        .collection(_collection)
        .where('companyId', isEqualTo: companyId)
        .where('costType', isEqualTo: costType)
        .where('isActive', isEqualTo: true)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ToolCostRecord.fromFirestore(doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  // Get cost records by category
  Stream<List<ToolCostRecord>> getCostRecordsByCategory(String companyId, CostCategory category) {
    return _firestore
        .collection(_collection)
        .where('companyId', isEqualTo: companyId)
        .where('category', isEqualTo: category)
        .where('isActive', isEqualTo: true)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ToolCostRecord.fromFirestore(doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  // Get cost records within date range
  Stream<List<ToolCostRecord>> getCostRecordsByDateRange(
    String companyId, 
    DateTime startDate, 
    DateTime endDate
  ) {
    return _firestore
        .collection(_collection)
        .where('companyId', isEqualTo: companyId)
        .where('date', isGreaterThanOrEqualTo: startDate.toIso8601String())
        .where('date', isLessThanOrEqualTo: endDate.toIso8601String())
        .where('isActive', isEqualTo: true)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ToolCostRecord.fromFirestore(doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  // Get recent high-cost records
  Stream<List<ToolCostRecord>> getHighCostRecords(String companyId, {double threshold = 1000.0}) {
    return _firestore
        .collection(_collection)
        .where('companyId', isEqualTo: companyId)
        .where('amount', isGreaterThan: threshold)
        .where('isActive', isEqualTo: true)
        .orderBy('amount', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ToolCostRecord.fromFirestore(doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  // Get specific cost record
  Future<ToolCostRecord?> getCostRecord(String recordId) async {
    try {
      final doc = await _firestore
          .collection(_collection)
          .doc(recordId)
          .get();

      if (doc.exists && doc.data() != null) {
        return ToolCostRecord.fromFirestore(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      print('Error getting cost record: $e');
      return null;
    }
  }

  // Create cost record
  Future<bool> createCostRecord({
    required String companyId,
    required String toolId,
    required CostType costType,
    required CostCategory category,
    required double amount,
    required DateTime date,
    required String description,
    String? vendor,
    String? invoiceNumber,
    String? receiptUrl,
    String? approvedBy,
    String? jobSiteId,
    String? workOrderId,
    String? notes,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final record = ToolCostRecord(
        id: '',
        costId: _generateRecordId(),
        toolId: toolId,
        date: date,
        costType: costType,
        category: category.name,
        description: description,
        amount: amount,
        vendor: vendor,
        invoiceNumber: invoiceNumber,
        receiptPath: receiptUrl,
        approvedBy: approvedBy,
        metadata: {
          'companyId': companyId,
          if (jobSiteId != null) 'jobSiteId': jobSiteId,
          if (workOrderId != null) 'workOrderId': workOrderId,
          if (notes != null) 'notes': notes,
          ...metadata ?? {},
        },
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isActive: true,
      );

      await _firestore
          .collection(_collection)
          .add(record.toJson());

      NotificationManager().showSuccess('Cost record created successfully!');
      
      print('✅ Cost record created: ${record.costId}');
      return true;
    } catch (e) {
      print('❌ Error creating cost record: $e');
      NotificationManager().showError('Failed to create cost record: ${e.toString()}');
      return false;
    }
  }

  // Update cost record
  Future<bool> updateCostRecord(String recordId, ToolCostRecord record) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(recordId)
          .update(record.toJson());

      NotificationManager().showSuccess('Cost record updated successfully!');
      
      print('✅ Cost record updated: $recordId');
      return true;
    } catch (e) {
      print('❌ Error updating cost record: $e');
      NotificationManager().showError('Failed to update cost record: ${e.toString()}');
      return false;
    }
  }

  // Delete cost record (soft delete)
  Future<bool> deleteCostRecord(String recordId) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(recordId)
          .update({
        'isActive': false,
        'updatedAt': DateTime.now().toIso8601String(),
      });

      NotificationManager().showSuccess('Cost record deleted successfully!');
      
      print('✅ Cost record deleted (soft): $recordId');
      return true;
    } catch (e) {
      print('❌ Error deleting cost record: $e');
      NotificationManager().showError('Failed to delete cost record: ${e.toString()}');
      return false;
    }
  }

  // Bulk create cost records
  Future<bool> bulkCreateCostRecords(List<ToolCostRecord> records) async {
    try {
      final batch = _firestore.batch();

      for (final record in records) {
        final docRef = _firestore.collection(_collection).doc();
        batch.set(docRef, record.toJson());
      }

      await batch.commit();

      NotificationManager().showSuccess('Bulk cost records created: ${records.length} items');
      
      print('✅ Bulk cost records created: ${records.length} items');
      return true;
    } catch (e) {
      print('❌ Error bulk creating cost records: $e');
      NotificationManager().showError('Failed to bulk create cost records: ${e.toString()}');
      return false;
    }
  }

  // Get tool total cost of ownership
  Future<Map<String, dynamic>> getToolTotalCostOfOwnership(String toolId) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('toolId', isEqualTo: toolId)
          .where('isActive', isEqualTo: true)
          .get();

      final records = snapshot.docs
          .map((doc) => ToolCostRecord.fromFirestore(doc.data() as Map<String, dynamic>, doc.id))
          .toList();

      if (records.isEmpty) {
        return {'hasData': false};
      }

      final totalCost = records.fold<double>(0.0, (sum, record) => sum + record.amount);
      
      // Group costs by type
      final costsByType = <String, double>{};
      final costsByCategory = <String, double>{};
      final recordsByYear = <int, List<ToolCostRecord>>{};

      for (final record in records) {
        // By type
        costsByType[record.costType.name] = 
            (costsByType[record.costType.name] ?? 0.0) + record.amount;
        
        // By category
        costsByCategory[record.category] = 
            (costsByCategory[record.category] ?? 0.0) + record.amount;
        
        // By year
        final year = record.date.year;
        recordsByYear[year] ??= [];
        recordsByYear[year]!.add(record);
      }

      // Calculate yearly costs
      final yearlyCosts = <int, double>{};
      for (final entry in recordsByYear.entries) {
        yearlyCosts[entry.key] = entry.value.fold<double>(0.0, (sum, r) => sum + r.amount);
      }

      // Calculate depreciation (assuming 5-year life cycle)
      final purchaseCost = costsByType[CostType.acquisition] ?? 0.0;
      final toolAge = records.isEmpty ? 0 : DateTime.now().difference(
          records.where((r) => r.costType == CostType.acquisition).isNotEmpty
              ? records.where((r) => r.costType == CostType.acquisition).first.date
              : records.first.date
      ).inDays;
      
      final depreciationRate = 0.20; // 20% per year
      final currentValue = purchaseCost * (1 - (depreciationRate * (toolAge / 365)));
      final depreciation = purchaseCost - math.max(currentValue, purchaseCost * 0.1); // Min 10% residual

      return {
        'hasData': true,
        'totalCost': totalCost,
        'purchaseCost': purchaseCost,
        'operationalCost': totalCost - purchaseCost,
        'currentValue': math.max(currentValue, 0),
        'depreciation': depreciation,
        'toolAgeInDays': toolAge,
        'costsByType': costsByType,
        'costsByCategory': costsByCategory,
        'yearlyCosts': yearlyCosts,
        'averageYearlyCost': yearlyCosts.isNotEmpty 
            ? yearlyCosts.values.reduce((a, b) => a + b) / yearlyCosts.length 
            : 0.0,
        'lastRecordDate': records.first.date.toIso8601String(),
        'totalRecords': records.length,
      };
    } catch (e) {
      print('❌ Error getting tool total cost of ownership: $e');
      return {'hasData': false};
    }
  }

  // Get cost analytics for company
  Future<Map<String, dynamic>> getCompanyCostAnalytics(String companyId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      Query query = _firestore
          .collection(_collection)
          .where('companyId', isEqualTo: companyId)
          .where('isActive', isEqualTo: true);

      if (startDate != null) {
        query = query.where('date', isGreaterThanOrEqualTo: startDate.toIso8601String());
      }
      if (endDate != null) {
        query = query.where('date', isLessThanOrEqualTo: endDate.toIso8601String());
      }

      final snapshot = await query.get();
      final records = snapshot.docs
          .map((doc) => ToolCostRecord.fromFirestore(doc.data() as Map<String, dynamic>, doc.id))
          .toList();

      if (records.isEmpty) {
        return {'hasData': false};
      }

      final totalCost = records.fold<double>(0.0, (sum, record) => sum + record.amount);
      
      // Group by various dimensions
      final costsByType = <String, double>{};
      final costsByCategory = <String, double>{};
      final costsByTool = <String, double>{};
      final costsByMonth = <String, double>{};
      final costsByVendor = <String, double>{};

      for (final record in records) {
        // By type
        costsByType[record.costType.name] = 
            (costsByType[record.costType.name] ?? 0.0) + record.amount;
        
        // By category
        costsByCategory[record.category] = 
            (costsByCategory[record.category] ?? 0.0) + record.amount;
        
        // By tool
        costsByTool[record.toolId] = 
            (costsByTool[record.toolId] ?? 0.0) + record.amount;
        
        // By month
        final monthKey = '${record.date.year}-${record.date.month.toString().padLeft(2, '0')}';
        costsByMonth[monthKey] = 
            (costsByMonth[monthKey] ?? 0.0) + record.amount;
        
        // By vendor
        if (record.vendor?.isNotEmpty == true) {
          costsByVendor[record.vendor!] = 
              (costsByVendor[record.vendor!] ?? 0.0) + record.amount;
        }
      }

      // Calculate trends
      final monthlyEntries = costsByMonth.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key));
      
      double? trend;
      if (monthlyEntries.length >= 2) {
        final lastMonth = monthlyEntries.last.value;
        final previousMonth = monthlyEntries[monthlyEntries.length - 2].value;
        trend = previousMonth > 0 ? ((lastMonth - previousMonth) / previousMonth * 100) : 0;
      }

      // Top cost categories
      final topCostTools = costsByTool.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value))
        ..take(10);

      return {
        'hasData': true,
        'totalCost': totalCost,
        'totalRecords': records.length,
        'averageCostPerRecord': totalCost / records.length,
        'costsByType': costsByType,
        'costsByCategory': costsByCategory,
        'costsByMonth': costsByMonth,
        'costsByVendor': costsByVendor,
        'topCostTools': Map.fromEntries(topCostTools),
        'monthlyTrend': trend,
        'dateRange': {
          'start': records.map((r) => r.date).reduce((a, b) => a.isBefore(b) ? a : b).toIso8601String(),
          'end': records.map((r) => r.date).reduce((a, b) => a.isAfter(b) ? a : b).toIso8601String(),
        }
      };
    } catch (e) {
      print('❌ Error getting company cost analytics: $e');
      return {'hasData': false};
    }
  }

  // Get budget vs actual analysis
  Future<Map<String, dynamic>> getBudgetAnalysis(String companyId, {
    required double annualBudget,
    int? year,
  }) async {
    try {
      final currentYear = year ?? DateTime.now().year;
      final yearStart = DateTime(currentYear, 1, 1);
      final yearEnd = DateTime(currentYear, 12, 31, 23, 59, 59);

      final snapshot = await _firestore
          .collection(_collection)
          .where('companyId', isEqualTo: companyId)
          .where('date', isGreaterThanOrEqualTo: yearStart.toIso8601String())
          .where('date', isLessThanOrEqualTo: yearEnd.toIso8601String())
          .where('isActive', isEqualTo: true)
          .get();

      final records = snapshot.docs
          .map((doc) => ToolCostRecord.fromFirestore(doc.data() as Map<String, dynamic>, doc.id))
          .toList();

      final actualSpend = records.fold<double>(0.0, (sum, record) => sum + record.amount);
      
      // Calculate monthly breakdown
      final monthlyBudget = annualBudget / 12;
      final monthlyActual = <int, double>{};
      
      for (final record in records) {
        final month = record.date.month;
        monthlyActual[month] = (monthlyActual[month] ?? 0.0) + record.amount;
      }

      // Calculate variance
      final variance = actualSpend - annualBudget;
      final variancePercentage = annualBudget > 0 ? (variance / annualBudget * 100) : 0;

      // Project year-end spend
      final currentMonth = DateTime.now().month;
      final spendToDate = monthlyActual.entries
          .where((entry) => entry.key <= currentMonth)
          .fold<double>(0.0, (sum, entry) => sum + entry.value);
      
      final averageMonthlySpend = currentMonth > 0 ? spendToDate / currentMonth : 0;
      final projectedYearEndSpend = averageMonthlySpend * 12;

      return {
        'year': currentYear,
        'annualBudget': annualBudget,
        'actualSpend': actualSpend,
        'variance': variance,
        'variancePercentage': variancePercentage,
        'budgetUtilization': annualBudget > 0 ? (actualSpend / annualBudget * 100) : 0,
        'monthlyBudget': monthlyBudget,
        'monthlyActual': monthlyActual,
        'projectedYearEndSpend': projectedYearEndSpend,
        'projectedVariance': projectedYearEndSpend - annualBudget,
        'onTrack': projectedYearEndSpend <= annualBudget * 1.05, // Within 5% tolerance
        'remainingBudget': annualBudget - actualSpend,
        'monthsRemaining': 12 - currentMonth,
      };
    } catch (e) {
      print('❌ Error getting budget analysis: $e');
      return {};
    }
  }

  // Search cost records
  Future<List<ToolCostRecord>> searchCostRecords(String companyId, String query) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('companyId', isEqualTo: companyId)
          .where('isActive', isEqualTo: true)
          .get();

      final records = snapshot.docs
          .map((doc) => ToolCostRecord.fromFirestore(doc.data() as Map<String, dynamic>, doc.id))
          .where((record) =>
              record.costId.toLowerCase().contains(query.toLowerCase()) ||
              record.description.toLowerCase().contains(query.toLowerCase()) ||
              (record.vendor?.toLowerCase() ?? '').contains(query.toLowerCase()) ||
              (record.invoiceNumber?.toLowerCase() ?? '').contains(query.toLowerCase()) ||
              (record.metadata?['notes']?.toString().toLowerCase() ?? '').contains(query.toLowerCase()))
          .toList();

      return records;
    } catch (e) {
      print('❌ Error searching cost records: $e');
      return [];
    }
  }

  // Export cost data (returns data for export)
  Future<List<Map<String, dynamic>>> exportCostData({
    required String companyId,
    String? toolId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      Query query = _firestore
          .collection(_collection)
          .where('companyId', isEqualTo: companyId)
          .where('isActive', isEqualTo: true);

      if (toolId != null) {
        query = query.where('toolId', isEqualTo: toolId);
      }

      if (startDate != null) {
        query = query.where('date', isGreaterThanOrEqualTo: startDate.toIso8601String());
      }

      if (endDate != null) {
        query = query.where('date', isLessThanOrEqualTo: endDate.toIso8601String());
      }

      final snapshot = await query.orderBy('date', descending: true).get();

      return snapshot.docs
          .map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return {
                'recordId': data['costId'], // Updated field name
                'toolId': data['toolId'],
                'costType': data['costType'],
                'category': data['category'],
                'amount': data['amount'],
                'date': data['date'],
                'description': data['description'],
                'vendor': data['vendor'],
                'invoiceNumber': data['invoiceNumber'],
                'approvedBy': data['approvedBy'],
                'jobSiteId': data['metadata']?['jobSiteId'],
                'workOrderId': data['metadata']?['workOrderId'],
                'notes': data['metadata']?['notes'],
              };
            })
          .toList();
    } catch (e) {
      print('❌ Error exporting cost data: $e');
      return [];
    }
  }

  // Generate cost report
  Future<Map<String, dynamic>> generateCostReport({
    required String companyId,
    required DateTime startDate,
    required DateTime endDate,
    String? toolId,
  }) async {
    try {
      final records = toolId != null
          ? await getToolCostHistory(toolId).first
          : await getCostRecordsByDateRange(companyId, startDate, endDate).first;

      final filteredRecords = records.where((record) =>
          record.date.isAfter(startDate.subtract(const Duration(days: 1))) &&
          record.date.isBefore(endDate.add(const Duration(days: 1)))
      ).toList();

      if (filteredRecords.isEmpty) {
        return {'hasData': false, 'message': 'No cost data found for the specified period'};
      }

      final totalCost = filteredRecords.fold<double>(0.0, (sum, record) => sum + record.amount);
      
      // Summary by type and category
      final costsByType = <String, double>{};
      final costsByCategory = <String, double>{};
      
      for (final record in filteredRecords) {
        costsByType[record.costType.name] = 
            (costsByType[record.costType.name] ?? 0.0) + record.amount;
        costsByCategory[record.category] = 
            (costsByCategory[record.category] ?? 0.0) + record.amount;
      }

      return {
        'hasData': true,
        'reportPeriod': {
          'start': startDate.toIso8601String(),
          'end': endDate.toIso8601String(),
        },
        'toolId': toolId,
        'summary': {
          'totalCost': totalCost,
          'recordCount': filteredRecords.length,
          'averageCost': totalCost / filteredRecords.length,
        },
        'breakdowns': {
          'byType': costsByType,
          'byCategory': costsByCategory,
        },
        'records': filteredRecords.map((record) => {
          'date': record.date.toIso8601String(),
          'type': record.costType,
          'category': record.category,
          'amount': record.amount,
          'description': record.description,
          'vendor': record.vendor,
        }).toList(),
        'generatedAt': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      print('❌ Error generating cost report: $e');
      return {'hasData': false, 'error': e.toString()};
    }
  }

  // Generate record ID
  String _generateRecordId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'CST${timestamp.toString().substring(6)}';
  }
}

// Add missing Math import for Dart
