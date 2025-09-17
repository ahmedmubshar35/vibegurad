import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';
import 'package:stacked_services/stacked_services.dart';
import 'package:get_it/get_it.dart';

import '../../models/tool/advanced_tool_models.dart';

@lazySingleton
class ToolServiceHistoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  SnackbarService get _snackbarService => GetIt.instance<SnackbarService>();

  static const String _collection = 'tool_service_records';

  // Get all service records for a company
  Stream<List<ToolServiceRecord>> getCompanyServiceRecords(String companyId) {
    return _firestore
        .collection(_collection)
        .where('companyId', isEqualTo: companyId)
        .where('isActive', isEqualTo: true)
        .orderBy('serviceDate', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ToolServiceRecord.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  // Get service records for a specific tool
  Stream<List<ToolServiceRecord>> getToolServiceHistory(String toolId) {
    return _firestore
        .collection(_collection)
        .where('toolId', isEqualTo: toolId)
        .where('isActive', isEqualTo: true)
        .orderBy('serviceDate', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ToolServiceRecord.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  // Get service records by type
  Stream<List<ToolServiceRecord>> getServiceRecordsByType(String companyId, ServiceType serviceType) {
    return _firestore
        .collection(_collection)
        .where('companyId', isEqualTo: companyId)
        .where('serviceType', isEqualTo: serviceType.name)
        .where('isActive', isEqualTo: true)
        .orderBy('serviceDate', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ToolServiceRecord.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  // Get service records by status
  Stream<List<ToolServiceRecord>> getServiceRecordsByStatus(String companyId, ServiceStatus status) {
    return _firestore
        .collection(_collection)
        .where('companyId', isEqualTo: companyId)
        .where('status', isEqualTo: status.name)
        .where('isActive', isEqualTo: true)
        .orderBy('serviceDate', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ToolServiceRecord.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  // Get pending service records
  Stream<List<ToolServiceRecord>> getPendingServiceRecords(String companyId) {
    return _firestore
        .collection(_collection)
        .where('companyId', isEqualTo: companyId)
        .where('status', whereIn: [ServiceStatus.scheduled.name, ServiceStatus.inProgress.name])
        .where('isActive', isEqualTo: true)
        .orderBy('scheduledDate')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ToolServiceRecord.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  // Get overdue service records
  Stream<List<ToolServiceRecord>> getOverdueServiceRecords(String companyId) {
    final now = DateTime.now();
    return _firestore
        .collection(_collection)
        .where('companyId', isEqualTo: companyId)
        .where('status', isEqualTo: ServiceStatus.scheduled.name)
        .where('scheduledDate', isLessThan: now.toIso8601String())
        .where('isActive', isEqualTo: true)
        .orderBy('scheduledDate')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ToolServiceRecord.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  // Get service records by provider
  Stream<List<ToolServiceRecord>> getServiceRecordsByProvider(String companyId, String provider) {
    return _firestore
        .collection(_collection)
        .where('companyId', isEqualTo: companyId)
        .where('serviceProvider', isEqualTo: provider)
        .where('isActive', isEqualTo: true)
        .orderBy('serviceDate', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ToolServiceRecord.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  // Get specific service record
  Future<ToolServiceRecord?> getServiceRecord(String recordId) async {
    try {
      final doc = await _firestore
          .collection(_collection)
          .doc(recordId)
          .get();

      if (doc.exists && doc.data() != null) {
        return ToolServiceRecord.fromFirestore(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      print('Error getting service record: $e');
      return null;
    }
  }

  // Get latest service record for a tool
  Future<ToolServiceRecord?> getLatestServiceRecord(String toolId) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('toolId', isEqualTo: toolId)
          .where('isActive', isEqualTo: true)
          .orderBy('serviceDate', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return ToolServiceRecord.fromFirestore(
          snapshot.docs.first.data(),
          snapshot.docs.first.id,
        );
      }
      return null;
    } catch (e) {
      print('Error getting latest service record: $e');
      return null;
    }
  }

  // Create service record
  Future<bool> createServiceRecord({
    required String companyId,
    required String toolId,
    required ServiceType serviceType,
    required DateTime scheduledDate,
    required String serviceProvider,
    String? description,
    List<String> workPerformed = const [],
    List<String> partsReplaced = const [],
    double cost = 0.0,
    String? notes,
    List<String> documentUrls = const [],
    String? technician,
    Map<String, dynamic>? serviceDetails,
    DateTime? nextServiceDate,
  }) async {
    try {
      final record = ToolServiceRecord(
        id: '',
        serviceId: _generateRecordId(),
        toolId: toolId,
        serviceDate: DateTime.now(),
        serviceType: serviceType,
        serviceProvider: serviceProvider,
        technicianName: technician,
        description: description ?? '',
        workPerformed: workPerformed,
        partsReplaced: partsReplaced,
        laborCost: cost * 0.7,
        partsCost: cost * 0.3,
        totalCost: cost,
        nextServiceDue: nextServiceDate,
        documents: documentUrls,
        metadata: {
          'companyId': companyId,
          'scheduledDate': scheduledDate.toIso8601String(),
          'status': ServiceStatus.scheduled.name,
          'notes': notes ?? '',
          'serviceDetails': serviceDetails ?? {},
        },
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isActive: true,
      );

      await _firestore
          .collection(_collection)
          .add(record.toJson());

      _snackbarService.showSnackbar(
        message: 'Service record created successfully!',
      );
      
      print('✅ Service record created: ${record.serviceId}');
      return true;
    } catch (e) {
      print('❌ Error creating service record: $e');
      _snackbarService.showSnackbar(
        message: 'Failed to create service record: ${e.toString()}',
      );
      return false;
    }
  }

  // Update service record
  Future<bool> updateServiceRecord(String recordId, ToolServiceRecord record) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(recordId)
          .update(record.toJson());

      _snackbarService.showSnackbar(
        message: 'Service record updated successfully!',
      );
      
      print('✅ Service record updated: $recordId');
      return true;
    } catch (e) {
      print('❌ Error updating service record: $e');
      _snackbarService.showSnackbar(
        message: 'Failed to update service record: ${e.toString()}',
      );
      return false;
    }
  }

  // Start service
  Future<bool> startService(String recordId, String technician) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(recordId)
          .update({
        'status': ServiceStatus.inProgress.name,
        'serviceDate': DateTime.now().toIso8601String(),
        'technician': technician,
        'updatedAt': DateTime.now().toIso8601String(),
      });

      _snackbarService.showSnackbar(
        message: 'Service started!',
      );
      
      print('✅ Service started: $recordId');
      return true;
    } catch (e) {
      print('❌ Error starting service: $e');
      _snackbarService.showSnackbar(
        message: 'Failed to start service: ${e.toString()}',
      );
      return false;
    }
  }

  // Complete service
  Future<bool> completeService({
    required String recordId,
    required List<String> workPerformed,
    required List<String> partsReplaced,
    required double cost,
    String? notes,
    List<String> documentUrls = const [],
    Map<String, dynamic>? serviceDetails,
    DateTime? nextServiceDate,
  }) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(recordId)
          .update({
        'status': ServiceStatus.completed.name,
        'completedDate': DateTime.now().toIso8601String(),
        'workPerformed': workPerformed,
        'partsReplaced': partsReplaced,
        'cost': cost,
        'notes': notes ?? '',
        'documentUrls': documentUrls,
        'serviceDetails': serviceDetails ?? {},
        'nextServiceDate': nextServiceDate?.toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      });

      _snackbarService.showSnackbar(
        message: 'Service completed successfully!',
      );
      
      print('✅ Service completed: $recordId');
      return true;
    } catch (e) {
      print('❌ Error completing service: $e');
      _snackbarService.showSnackbar(
        message: 'Failed to complete service: ${e.toString()}',
      );
      return false;
    }
  }

  // Cancel service
  Future<bool> cancelService(String recordId, String reason) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(recordId)
          .update({
        'status': ServiceStatus.cancelled.name,
        'notes': reason,
        'updatedAt': DateTime.now().toIso8601String(),
      });

      _snackbarService.showSnackbar(
        message: 'Service cancelled',
      );
      
      print('✅ Service cancelled: $recordId');
      return true;
    } catch (e) {
      print('❌ Error cancelling service: $e');
      _snackbarService.showSnackbar(
        message: 'Failed to cancel service: ${e.toString()}',
      );
      return false;
    }
  }

  // Reschedule service
  Future<bool> rescheduleService(String recordId, DateTime newDate, String reason) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(recordId)
          .update({
        'scheduledDate': newDate.toIso8601String(),
        'notes': reason,
        'updatedAt': DateTime.now().toIso8601String(),
      });

      _snackbarService.showSnackbar(
        message: 'Service rescheduled!',
      );
      
      print('✅ Service rescheduled: $recordId');
      return true;
    } catch (e) {
      print('❌ Error rescheduling service: $e');
      _snackbarService.showSnackbar(
        message: 'Failed to reschedule service: ${e.toString()}',
      );
      return false;
    }
  }

  // Schedule next service based on previous record
  Future<bool> scheduleNextService({
    required String previousRecordId,
    required DateTime nextServiceDate,
    ServiceType? serviceType,
    String? description,
  }) async {
    try {
      final previousRecord = await getServiceRecord(previousRecordId);
      if (previousRecord == null) {
        _snackbarService.showSnackbar(
          message: 'Previous service record not found',
        );
        return false;
      }

      return await createServiceRecord(
        companyId: previousRecord.metadata['companyId'] as String? ?? '',
        toolId: previousRecord.toolId,
        serviceType: serviceType ?? previousRecord.serviceType,
        scheduledDate: nextServiceDate,
        serviceProvider: previousRecord.serviceProvider,
        description: description ?? 'Scheduled ${serviceType?.name ?? previousRecord.serviceType.name}',
        technician: previousRecord.technicianName,
      );
    } catch (e) {
      print('❌ Error scheduling next service: $e');
      _snackbarService.showSnackbar(
        message: 'Failed to schedule next service: ${e.toString()}',
      );
      return false;
    }
  }

  // Get service statistics
  Future<Map<String, dynamic>> getServiceStats(String companyId) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('companyId', isEqualTo: companyId)
          .where('isActive', isEqualTo: true)
          .get();

      final records = snapshot.docs
          .map((doc) => ToolServiceRecord.fromFirestore(doc.data(), doc.id))
          .toList();

      final totalCost = records.fold<double>(0.0, (sum, r) => sum + r.totalCost);

      final statusCounts = <String, int>{};
      final typeCounts = <String, int>{};
      final providerCounts = <String, int>{};

      for (final record in records) {
        final status = record.metadata['status'] as String? ?? 'unknown';
        statusCounts[status] = (statusCounts[status] ?? 0) + 1;
        typeCounts[record.serviceType.name] = (typeCounts[record.serviceType.name] ?? 0) + 1;
        providerCounts[record.serviceProvider] = (providerCounts[record.serviceProvider] ?? 0) + 1;
      }

      // Calculate average service interval
      final completedRecords = records.where((r) => 
          (r.metadata['status'] as String?) == ServiceStatus.completed.name).toList();
      double averageServiceInterval = 0.0;
      
      if (completedRecords.length >= 2) {
        completedRecords.sort((a, b) => a.serviceDate.compareTo(b.serviceDate));
        final intervals = <int>[];
        
        for (int i = 1; i < completedRecords.length; i++) {
          final interval = completedRecords[i].serviceDate
              .difference(completedRecords[i-1].serviceDate)
              .inDays;
          intervals.add(interval);
        }
        
        if (intervals.isNotEmpty) {
          averageServiceInterval = intervals.reduce((a, b) => a + b) / intervals.length;
        }
      }

      // Overdue services
      final now = DateTime.now();
      final overdueServices = records.where((r) {
        final status = r.metadata['status'] as String?;
        final scheduledDateStr = r.metadata['scheduledDate'] as String?;
        if (status == ServiceStatus.scheduled.name && scheduledDateStr != null) {
          final scheduledDate = DateTime.parse(scheduledDateStr);
          return scheduledDate.isBefore(now);
        }
        return false;
      }).length;

      return {
        'totalRecords': records.length,
        'totalCost': totalCost,
        'averageCostPerService': completedRecords.isNotEmpty 
            ? (totalCost / completedRecords.length) 
            : 0.0,
        'statusBreakdown': statusCounts,
        'typeBreakdown': typeCounts,
        'providerBreakdown': providerCounts,
        'completedServices': statusCounts[ServiceStatus.completed.name] ?? 0,
        'pendingServices': (statusCounts[ServiceStatus.scheduled.name] ?? 0) + 
                          (statusCounts[ServiceStatus.inProgress.name] ?? 0),
        'overdueServices': overdueServices,
        'averageServiceInterval': averageServiceInterval,
      };
    } catch (e) {
      print('❌ Error getting service stats: $e');
      return {};
    }
  }

  // Get tools needing service (based on last service date and intervals)
  Future<List<Map<String, dynamic>>> getToolsNeedingService(String companyId) async {
    try {
      // Get all tools in the company
      final toolsSnapshot = await _firestore
          .collection('tool_inventory')
          .where('companyId', isEqualTo: companyId)
          .where('isActive', isEqualTo: true)
          .get();

      final toolsNeedingService = <Map<String, dynamic>>[];

      for (final toolDoc in toolsSnapshot.docs) {
        final toolData = toolDoc.data();
        final toolId = toolData['toolId'];

        // Get latest service record for this tool
        final latestService = await getLatestServiceRecord(toolId);

        // Determine if service is needed based on:
        // 1. Never serviced tools
        // 2. Tools past their recommended service interval
        // 3. Tools with scheduled next service date

        DateTime? lastServiceDate = latestService?.serviceDate;
        DateTime? nextServiceDate = latestService?.nextServiceDue;

        bool needsService = false;
        String reason = '';
        int daysSinceLastService = 0;

        if (lastServiceDate == null) {
          needsService = true;
          reason = 'Never serviced';
        } else {
          daysSinceLastService = DateTime.now().difference(lastServiceDate).inDays;
          
          if (nextServiceDate != null && DateTime.now().isAfter(nextServiceDate)) {
            needsService = true;
            reason = 'Scheduled service overdue';
          } else if (daysSinceLastService > 90) { // Default 90-day service interval
            needsService = true;
            reason = 'Service interval exceeded';
          }
        }

        if (needsService) {
          toolsNeedingService.add({
            'toolId': toolId,
            'toolName': toolData['toolName'],
            'category': toolData['category'],
            'lastServiceDate': lastServiceDate?.toIso8601String(),
            'nextServiceDate': nextServiceDate?.toIso8601String(),
            'daysSinceLastService': daysSinceLastService,
            'reason': reason,
            'priority': daysSinceLastService > 180 ? 'high' : 
                       daysSinceLastService > 120 ? 'medium' : 'low',
          });
        }
      }

      // Sort by priority and days since last service
      toolsNeedingService.sort((a, b) {
        final priorityOrder = {'high': 3, 'medium': 2, 'low': 1};
        final aPriority = priorityOrder[a['priority']] ?? 0;
        final bPriority = priorityOrder[b['priority']] ?? 0;
        
        if (aPriority != bPriority) {
          return bPriority.compareTo(aPriority);
        }
        
        return (b['daysSinceLastService'] as int).compareTo(a['daysSinceLastService'] as int);
      });

      return toolsNeedingService;
    } catch (e) {
      print('❌ Error getting tools needing service: $e');
      return [];
    }
  }

  // Search service records
  Future<List<ToolServiceRecord>> searchServiceRecords(String companyId, String query) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('companyId', isEqualTo: companyId)
          .where('isActive', isEqualTo: true)
          .get();

      final records = snapshot.docs
          .map((doc) => ToolServiceRecord.fromFirestore(doc.data(), doc.id))
          .where((record) =>
              record.serviceId.toLowerCase().contains(query.toLowerCase()) ||
              record.serviceProvider.toLowerCase().contains(query.toLowerCase()) ||
              (record.technicianName ?? '').toLowerCase().contains(query.toLowerCase()) ||
              record.description.toLowerCase().contains(query.toLowerCase()) ||
              (record.metadata['notes'] as String? ?? '').toLowerCase().contains(query.toLowerCase()) ||
              record.workPerformed.any((work) => work.toLowerCase().contains(query.toLowerCase())) ||
              record.partsReplaced.any((part) => part.toLowerCase().contains(query.toLowerCase())))
          .toList();

      return records;
    } catch (e) {
      print('❌ Error searching service records: $e');
      return [];
    }
  }

  // Export service history (returns data for export)
  Future<List<Map<String, dynamic>>> exportServiceHistory({
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
        query = query.where('serviceDate', isGreaterThanOrEqualTo: startDate.toIso8601String());
      }

      if (endDate != null) {
        query = query.where('serviceDate', isLessThanOrEqualTo: endDate.toIso8601String());
      }

      final snapshot = await query.orderBy('serviceDate', descending: true).get();

      return snapshot.docs
          .map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final metadata = data['metadata'] as Map<String, dynamic>? ?? {};
            return {
              'serviceId': data['serviceId'],
              'toolId': data['toolId'],
              'serviceType': data['serviceType'],
              'description': data['description'],
              'scheduledDate': metadata['scheduledDate'],
              'serviceDate': data['serviceDate'],
              'serviceProvider': data['serviceProvider'],
              'technicianName': data['technicianName'],
              'workPerformed': data['workPerformed'],
              'partsReplaced': data['partsReplaced'],
              'laborCost': data['laborCost'],
              'partsCost': data['partsCost'],
              'totalCost': data['totalCost'],
              'status': metadata['status'],
              'notes': metadata['notes'],
            };
          })
          .toList();
    } catch (e) {
      print('❌ Error exporting service history: $e');
      return [];
    }
  }

  // Generate record ID
  String _generateRecordId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'SRV${timestamp.toString().substring(6)}';
  }

  // Delete service record (soft delete)
  Future<bool> deleteServiceRecord(String recordId) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(recordId)
          .update({
        'isActive': false,
        'updatedAt': DateTime.now().toIso8601String(),
      });

      _snackbarService.showSnackbar(
        message: 'Service record deleted successfully!',
      );
      
      print('✅ Service record deleted (soft): $recordId');
      return true;
    } catch (e) {
      print('❌ Error deleting service record: $e');
      _snackbarService.showSnackbar(
        message: 'Failed to delete service record: ${e.toString()}',
      );
      return false;
    }
  }
}