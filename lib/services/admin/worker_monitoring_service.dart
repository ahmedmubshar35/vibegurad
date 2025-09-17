import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../../models/admin/dashboard_models.dart';
import '../../models/health/lifetime_exposure.dart';
import '../../models/tool/tool.dart';
import '../features/health_analytics_service.dart';

/// Service for real-time worker monitoring and map display
class WorkerMonitoringService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final HealthAnalyticsService _healthAnalytics = HealthAnalyticsService();
  
  // Stream controllers for real-time updates
  final _monitoringStreamController = StreamController<List<WorkerMonitoringData>>.broadcast();
  final _alertStreamController = StreamController<WorkerAlert>.broadcast();
  
  // Cache for performance
  final Map<String, WorkerMonitoringData> _workerCache = {};
  Timer? _updateTimer;

  // Getters for streams
  Stream<List<WorkerMonitoringData>> get monitoringStream => _monitoringStreamController.stream;
  Stream<WorkerAlert> get alertStream => _alertStreamController.stream;

  /// Initialize monitoring service
  Future<void> initialize() async {
    await _startRealtimeMonitoring();
    _startPeriodicUpdates();
  }

  /// Start real-time monitoring of all workers
  Future<void> _startRealtimeMonitoring() async {
    // Monitor active timer sessions
    _firestore
        .collection('timer_sessions')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .listen((snapshot) async {
      for (final doc in snapshot.docChanges) {
        if (doc.type == DocumentChangeType.added || 
            doc.type == DocumentChangeType.modified) {
          await _updateWorkerMonitoring(doc.doc);
        } else if (doc.type == DocumentChangeType.removed) {
          _removeWorkerFromMonitoring(doc.doc.id);
        }
      }
      _broadcastMonitoringUpdate();
    });

    // Monitor worker locations
    _firestore
        .collection('worker_locations')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .listen((snapshot) {
      for (final doc in snapshot.docs) {
        _updateWorkerLocation(doc);
      }
      _broadcastMonitoringUpdate();
    });
  }

  /// Update worker monitoring data from session
  Future<void> _updateWorkerMonitoring(DocumentSnapshot sessionDoc) async {
    try {
      final sessionData = sessionDoc.data() as Map<String, dynamic>;
      final workerId = sessionData['workerId'] as String;

      // Get worker details
      final workerDoc = await _firestore
          .collection('users')
          .doc(workerId)
          .get();

      if (!workerDoc.exists) return;

      final workerData = workerDoc.data()!;
      
      // Get tool details if using one
      Tool? tool;
      if (sessionData['toolId'] != null) {
        final toolDoc = await _firestore
            .collection('tools')
            .doc(sessionData['toolId'])
            .get();
        if (toolDoc.exists) {
          tool = Tool.fromFirestore(toolDoc.data()!, toolDoc.id);
        }
      }

      // Get current exposure
      final exposureDoc = await _firestore
          .collection('lifetime_exposures')
          .doc(workerId)
          .get();

      ExposureRiskLevel riskLevel = ExposureRiskLevel.low;
      double dailyExposure = 0.0;

      if (exposureDoc.exists) {
        final exposure = exposureDoc.data()!;
        riskLevel = ExposureRiskLevel.fromString(exposure['currentRiskLevel'] ?? 'low');
        dailyExposure = await _calculateDailyExposure(workerId);
      }

      // Check for active alerts
      final hasAlert = await _checkForActiveAlerts(workerId, dailyExposure, riskLevel);

      // Create monitoring data
      final monitoringData = WorkerMonitoringData(
        workerId: workerId,
        workerName: '${workerData['firstName']} ${workerData['lastName']}',
        department: workerData['department'] ?? 'Unknown',
        projectId: sessionData['projectId'],
        currentLocation: _workerCache[workerId]?.currentLocation,
        isActive: true,
        currentToolId: tool?.id,
        currentToolName: tool?.name,
        currentVibrationLevel: tool?.vibrationLevel,
        sessionStartTime: (sessionData['startTime'] as Timestamp).toDate(),
        currentDailyExposure: dailyExposure,
        riskLevel: riskLevel,
        hasActiveAlert: hasAlert,
        lastUpdated: DateTime.now(),
      );

      _workerCache[workerId] = monitoringData;
    } catch (e) {
      print('Error updating worker monitoring: $e');
    }
  }

  /// Update worker location
  void _updateWorkerLocation(DocumentSnapshot locationDoc) {
    try {
      final data = locationDoc.data() as Map<String, dynamic>;
      final workerId = locationDoc.id;

      if (_workerCache.containsKey(workerId)) {
        final location = GeoLocation(
          latitude: data['latitude'] as double,
          longitude: data['longitude'] as double,
          accuracy: data['accuracy'] as double?,
          address: data['address'] as String?,
        );

        _workerCache[workerId] = WorkerMonitoringData(
          workerId: _workerCache[workerId]!.workerId,
          workerName: _workerCache[workerId]!.workerName,
          department: _workerCache[workerId]!.department,
          projectId: _workerCache[workerId]!.projectId,
          currentLocation: location,
          isActive: _workerCache[workerId]!.isActive,
          currentToolId: _workerCache[workerId]!.currentToolId,
          currentToolName: _workerCache[workerId]!.currentToolName,
          currentVibrationLevel: _workerCache[workerId]!.currentVibrationLevel,
          sessionStartTime: _workerCache[workerId]!.sessionStartTime,
          currentDailyExposure: _workerCache[workerId]!.currentDailyExposure,
          riskLevel: _workerCache[workerId]!.riskLevel,
          hasActiveAlert: _workerCache[workerId]!.hasActiveAlert,
          lastUpdated: DateTime.now(),
        );
      }
    } catch (e) {
      print('Error updating worker location: $e');
    }
  }

  /// Remove worker from monitoring
  void _removeWorkerFromMonitoring(String sessionId) {
    _workerCache.removeWhere((key, value) => 
        value.sessionStartTime?.toIso8601String() == sessionId);
  }

  /// Calculate daily exposure for worker
  Future<double> _calculateDailyExposure(String workerId) async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);

      final sessions = await _firestore
          .collection('timer_sessions')
          .where('workerId', isEqualTo: workerId)
          .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .get();

      double totalA8 = 0.0;
      for (final doc in sessions.docs) {
        final data = doc.data();
        totalA8 += (data['dailyExposure'] ?? 0.0) as double;
      }

      return totalA8;
    } catch (e) {
      print('Error calculating daily exposure: $e');
      return 0.0;
    }
  }

  /// Check for active alerts
  Future<bool> _checkForActiveAlerts(
    String workerId, 
    double dailyExposure, 
    ExposureRiskLevel riskLevel,
  ) async {
    // Check exposure limits
    if (dailyExposure > 5.0) {
      _alertStreamController.add(WorkerAlert(
        workerId: workerId,
        alertType: 'exposure_limit',
        severity: 'critical',
        message: 'Daily exposure limit exceeded',
        timestamp: DateTime.now(),
      ));
      return true;
    }

    // Check risk level
    if (riskLevel == ExposureRiskLevel.critical || 
        riskLevel == ExposureRiskLevel.veryHigh) {
      _alertStreamController.add(WorkerAlert(
        workerId: workerId,
        alertType: 'high_risk',
        severity: 'high',
        message: 'Worker at high risk level',
        timestamp: DateTime.now(),
      ));
      return true;
    }

    return false;
  }

  /// Broadcast monitoring update
  void _broadcastMonitoringUpdate() {
    final workers = _workerCache.values.toList()
      ..sort((a, b) => b.riskLevel.index.compareTo(a.riskLevel.index));
    _monitoringStreamController.add(workers);
  }

  /// Start periodic updates
  void _startPeriodicUpdates() {
    _updateTimer?.cancel();
    _updateTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _refreshMonitoringData();
    });
  }

  /// Refresh all monitoring data
  Future<void> _refreshMonitoringData() async {
    for (final workerId in _workerCache.keys) {
      final dailyExposure = await _calculateDailyExposure(workerId);
      final worker = _workerCache[workerId]!;
      
      _workerCache[workerId] = WorkerMonitoringData(
        workerId: worker.workerId,
        workerName: worker.workerName,
        department: worker.department,
        projectId: worker.projectId,
        currentLocation: worker.currentLocation,
        isActive: worker.isActive,
        currentToolId: worker.currentToolId,
        currentToolName: worker.currentToolName,
        currentVibrationLevel: worker.currentVibrationLevel,
        sessionStartTime: worker.sessionStartTime,
        currentDailyExposure: dailyExposure,
        riskLevel: worker.riskLevel,
        hasActiveAlert: worker.hasActiveAlert,
        lastUpdated: DateTime.now(),
      );
    }
    _broadcastMonitoringUpdate();
  }

  /// Get workers by location radius
  Future<List<WorkerMonitoringData>> getWorkersInRadius(
    double centerLat,
    double centerLng,
    double radiusKm,
  ) async {
    final workers = <WorkerMonitoringData>[];
    
    for (final worker in _workerCache.values) {
      if (worker.currentLocation != null) {
        final distance = Geolocator.distanceBetween(
          centerLat,
          centerLng,
          worker.currentLocation!.latitude,
          worker.currentLocation!.longitude,
        ) / 1000; // Convert to km
        
        if (distance <= radiusKm) {
          workers.add(worker);
        }
      }
    }
    
    return workers;
  }

  /// Get workers by department
  List<WorkerMonitoringData> getWorkersByDepartment(String department) {
    return _workerCache.values
        .where((worker) => worker.department == department)
        .toList();
  }

  /// Get high-risk workers
  List<WorkerMonitoringData> getHighRiskWorkers() {
    return _workerCache.values
        .where((worker) => 
            worker.riskLevel == ExposureRiskLevel.high ||
            worker.riskLevel == ExposureRiskLevel.veryHigh ||
            worker.riskLevel == ExposureRiskLevel.critical)
        .toList();
  }

  /// Update worker location manually
  Future<void> updateWorkerLocation(
    String workerId,
    double latitude,
    double longitude,
  ) async {
    await _firestore.collection('worker_locations').doc(workerId).set({
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': 10.0,
      'isActive': true,
      'updatedAt': Timestamp.now(),
    }, SetOptions(merge: true));
  }

  /// Clean up resources
  void dispose() {
    _updateTimer?.cancel();
    _monitoringStreamController.close();
    _alertStreamController.close();
    _workerCache.clear();
  }
}

/// Worker alert model
class WorkerAlert {
  final String workerId;
  final String alertType;
  final String severity;
  final String message;
  final DateTime timestamp;

  WorkerAlert({
    required this.workerId,
    required this.alertType,
    required this.severity,
    required this.message,
    required this.timestamp,
  });
}