import 'dart:async';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../../models/location/location_models.dart';
import 'location_history_service.dart';
import 'geofencing_service.dart';

/// Service for tracking worker locations during tool use
class WorkerLocationService {
  static const String _collection = 'worker_locations';
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  final LocationHistoryService _historyService = LocationHistoryService();
  final GeofencingService _geofencingService = GeofencingService();
  
  final StreamController<List<WorkerLocationData>> _locationStreamController = 
      StreamController<List<WorkerLocationData>>.broadcast();
  final StreamController<WorkerLocationData> _singleLocationStreamController = 
      StreamController<WorkerLocationData>.broadcast();
  final StreamController<WorkerLocationAlert> _alertStreamController = 
      StreamController<WorkerLocationAlert>.broadcast();

  // Cache for real-time location data
  final Map<String, WorkerLocationData> _locationCache = {};
  final Map<String, Timer> _trackingTimers = {};
  
  WorkerLocationService();

  /// Stream of all worker locations
  Stream<List<WorkerLocationData>> get locationStream => _locationStreamController.stream;
  
  /// Stream of single worker location updates
  Stream<WorkerLocationData> get singleLocationStream => _singleLocationStreamController.stream;
  
  /// Stream of location-based alerts
  Stream<WorkerLocationAlert> get alertStream => _alertStreamController.stream;

  /// Initialize worker location tracking
  Future<void> initialize() async {
    await _loadCachedLocations();
    await _geofencingService.initialize();
    _startRealtimeTracking();
  }

  /// Start real-time location tracking
  void _startRealtimeTracking() {
    _firestore
        .collection(_collection)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .listen((snapshot) {
      for (final change in snapshot.docChanges) {
        final data = WorkerLocationData.fromFirestore(change.doc.data()!, change.doc.id);
        
        switch (change.type) {
          case DocumentChangeType.added:
          case DocumentChangeType.modified:
            _locationCache[data.workerId] = data;
            _singleLocationStreamController.add(data);
            break;
          case DocumentChangeType.removed:
            _locationCache.remove(data.workerId);
            break;
        }
      }
      
      _locationStreamController.add(_locationCache.values.toList());
    });
  }

  /// Load cached location data
  Future<void> _loadCachedLocations() async {
    final snapshot = await _firestore
        .collection(_collection)
        .where('isActive', isEqualTo: true)
        .get();

    _locationCache.clear();
    for (final doc in snapshot.docs) {
      final location = WorkerLocationData.fromFirestore(doc.data() as Map<String, dynamic>, doc.id);
      _locationCache[location.workerId] = location;
    }
  }

  /// Start tracking a worker's location
  Future<void> startWorkerTracking({
    required String workerId,
    required String workerName,
    String? currentToolId,
    String? sessionId,
    Duration trackingInterval = const Duration(minutes: 2),
  }) async {
    // Stop existing tracking for this worker
    await stopWorkerTracking(workerId);

    // Start location monitoring for geofencing
    await _geofencingService.startMonitoring(
      entityId: workerId,
      entityType: 'worker',
      entityName: workerName,
    );

    // Start periodic location updates
    _trackingTimers[workerId] = Timer.periodic(trackingInterval, (_) async {
      await _updateWorkerLocationFromGPS(workerId, workerName, currentToolId, sessionId);
    });

    // Get initial location
    await _updateWorkerLocationFromGPS(workerId, workerName, currentToolId, sessionId);
  }

  /// Stop tracking a worker's location
  Future<void> stopWorkerTracking(String workerId) async {
    // Cancel tracking timer
    _trackingTimers[workerId]?.cancel();
    _trackingTimers.remove(workerId);

    // Stop geofencing monitoring
    _geofencingService.stopMonitoring(workerId);

    // Mark as inactive
    final currentLocation = await getWorkerLocation(workerId);
    if (currentLocation != null) {
      final updatedLocation = currentLocation.copyWith(
          isWorking: false,
          isActive: false,
      );
      
      await _firestore.collection(_collection).doc(currentLocation.id!).update(updatedLocation.toJson());
      _locationCache.remove(workerId);
    }
  }

  /// Update worker location manually
  Future<String> updateWorkerLocation({
    required String workerId,
    required String workerName,
    required double latitude,
    required double longitude,
    double? altitude,
    double accuracy = 10.0,
    String? address,
    String? jobSiteId,
    String? currentToolId,
    String? sessionId,
    bool isWorking = true,
    LocationSource source = LocationSource.gps,
    Map<String, dynamic>? metadata,
  }) async {
    final now = DateTime.now();
    
    final workerLocation = WorkerLocationData(
      workerId: workerId,
      workerName: workerName,
      latitude: latitude,
      longitude: longitude,
      altitude: altitude,
      accuracy: accuracy,
      timestamp: now,
      address: address,
      jobSiteId: jobSiteId,
      currentToolId: currentToolId,
      sessionId: sessionId,
      isWorking: isWorking,
      source: source,
      metadata: metadata,
      createdAt: now,
      updatedAt: now,
    );

    // Save to current locations
    final docRef = await _firestore.collection(_collection).add(workerLocation.toJson());
    final id = docRef.id;
    
    // Save to history
    await _saveLocationHistory(workerLocation);
    
    // Process geofencing events
    await _geofencingService.processLocationUpdate(
      entityId: workerId,
      entityType: 'worker',
      latitude: latitude,
      longitude: longitude,
      timestamp: now,
    );
    
    // Check for location-based alerts
    await _checkLocationAlerts(workerLocation);
    
    // Update cache
    _locationCache[workerId] = workerLocation.copyWith(id: id);
    _singleLocationStreamController.add(workerLocation.copyWith(id: id));
    
    return id;
  }

  /// Get current location of a specific worker
  Future<WorkerLocationData?> getWorkerLocation(String workerId) async {
    // Check cache first
    if (_locationCache.containsKey(workerId)) {
      return _locationCache[workerId];
    }

    // Query database
    final snapshot = await _firestore
        .collection(_collection)
        .where('workerId', isEqualTo: workerId)
        .where('isActive', isEqualTo: true)
        .orderBy('timestamp', descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      final location = WorkerLocationData.fromFirestore(
        snapshot.docs.first.data(),
        snapshot.docs.first.id,
      );
      _locationCache[workerId] = location;
      return location;
    }

    return null;
  }

  /// Get workers within a specific radius
  Future<List<WorkerLocationData>> getWorkersInRadius({
    required double centerLat,
    required double centerLng,
    required double radiusMeters,
    bool onlyWorking = true,
    List<String>? workerIds,
    DateTime? since,
  }) async {
    Query query = _firestore
        .collection(_collection)
        .where('isActive', isEqualTo: true);

    if (onlyWorking) {
      query = query.where('isWorking', isEqualTo: true);
    }

    if (workerIds != null && workerIds.isNotEmpty) {
      query = query.where('workerId', whereIn: workerIds);
    }

    if (since != null) {
      query = query.where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(since));
    }

    final snapshot = await query.get();
    final workers = <WorkerLocationData>[];

    for (final doc in snapshot.docs) {
      final location = WorkerLocationData.fromFirestore(doc.data() as Map<String, dynamic>, doc.id);
      final distance = Geolocator.distanceBetween(
        centerLat,
        centerLng,
        location.latitude,
        location.longitude,
      );

      if (distance <= radiusMeters) {
        workers.add(location);
      }
    }

    return workers;
  }

  /// Get workers currently using tools in a job site
  Future<List<WorkerLocationData>> getWorkersInJobSite(String jobSiteId) async {
    final snapshot = await _firestore
        .collection(_collection)
        .where('jobSiteId', isEqualTo: jobSiteId)
        .where('isWorking', isEqualTo: true)
        .where('isActive', isEqualTo: true)
        .get();

    return snapshot.docs
        .map((doc) => WorkerLocationData.fromFirestore(doc.data(), doc.id))
        .toList();
  }

  /// Get worker location history
  Future<List<LocationHistoryEntry>> getWorkerLocationHistory({
    required String workerId,
    DateTime? startTime,
    DateTime? endTime,
    int limit = 100,
  }) async {
    return await _historyService.getLocationHistory(
      entityId: workerId,
      entityType: 'worker',
      startTime: startTime,
      endTime: endTime,
      limit: limit,
    );
  }

  /// Get worker movement path during a session
  Future<List<LocationHistoryEntry>> getWorkerSessionPath({
    required String workerId,
    required String sessionId,
  }) async {
    final snapshot = await _firestore
        .collectionGroup('location_history')
        .where('entityId', isEqualTo: workerId)
        .where('entityType', isEqualTo: 'worker')
        .where('metadata.sessionId', isEqualTo: sessionId)
        .orderBy('timestamp', descending: false)
        .get();

    return snapshot.docs
        .map((doc) => LocationHistoryEntry.fromMap(doc.data()))
        .toList();
  }

  /// Calculate worker exposure by location
  Future<Map<String, double>> calculateExposureByLocation({
    required String workerId,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    final history = await getWorkerLocationHistory(
      workerId: workerId,
      startTime: startTime,
      endTime: endTime,
    );

    final exposureByLocation = <String, double>{};
    
    for (final entry in history) {
      if (entry.exposureLevel != null) {
        final locationKey = entry.jobSiteId ?? 'unknown';
        exposureByLocation[locationKey] = 
            (exposureByLocation[locationKey] ?? 0.0) + entry.exposureLevel!;
      }
    }

    return exposureByLocation;
  }

  /// Get workers who haven't updated location recently
  Future<List<WorkerLocationData>> getWorkersWithStaleLocation({
    Duration threshold = const Duration(minutes: 10),
  }) async {
    final cutoffTime = DateTime.now().subtract(threshold);
    
    final snapshot = await _firestore
        .collection(_collection)
        .where('isWorking', isEqualTo: true)
        .where('isActive', isEqualTo: true)
        .where('timestamp', isLessThan: Timestamp.fromDate(cutoffTime))
        .get();

    return snapshot.docs
        .map((doc) => WorkerLocationData.fromFirestore(doc.data(), doc.id))
        .toList();
  }

  /// Find workers near high-risk areas
  Future<List<WorkerLocationAlert>> findWorkersInHighRiskAreas() async {
    final alerts = <WorkerLocationAlert>[];
    
    // Get heat map data for high vibration areas
    final heatMapPoints = await _historyService.getHeatMapData(
      startTime: DateTime.now().subtract(const Duration(days: 30)),
      minExposureLevel: 5.0, // High exposure threshold
    );

    // Get all active workers
    final workers = await getAllActive();

    for (final worker in workers) {
      for (final heatPoint in heatMapPoints) {
        final distance = Geolocator.distanceBetween(
          worker.latitude,
          worker.longitude,
          heatPoint.latitude,
          heatPoint.longitude,
        );

        // If worker is within 50 meters of high-risk area
        if (distance <= 50) {
          alerts.add(WorkerLocationAlert(
            alertId: '${worker.workerId}_${DateTime.now().millisecondsSinceEpoch}',
            workerId: worker.workerId,
            workerName: worker.workerName,
            alertType: LocationAlertType.highRiskArea,
            latitude: worker.latitude,
            longitude: worker.longitude,
            timestamp: DateTime.now(),
            severity: heatPoint.vibrationLevel > 10.0 ? 'critical' : 'warning',
            message: 'Worker near high-vibration area (${heatPoint.vibrationLevel.toStringAsFixed(1)} m/s²)',
            metadata: {
              'heatPointVibration': heatPoint.vibrationLevel,
              'heatPointExposureTime': heatPoint.exposureTime,
              'distance': distance,
            },
          ));
        }
      }
    }

    return alerts;
  }

  /// Get worker proximity to each other (for contact tracing/safety)
  Future<List<WorkerProximityInfo>> getWorkerProximity({
    double proximityThresholdMeters = 10.0,
    Duration timeWindow = const Duration(minutes: 5),
  }) async {
    final proximityInfos = <WorkerProximityInfo>[];
    final workers = await getAllActive();
    
    // Check each pair of workers
    for (int i = 0; i < workers.length; i++) {
      for (int j = i + 1; j < workers.length; j++) {
        final worker1 = workers[i];
        final worker2 = workers[j];
        
        final distance = Geolocator.distanceBetween(
          worker1.latitude,
          worker1.longitude,
          worker2.latitude,
          worker2.longitude,
        );

        if (distance <= proximityThresholdMeters) {
          // Check if they've been in proximity for the time window
          final proximityDuration = await _calculateProximityDuration(
            worker1.workerId,
            worker2.workerId,
            timeWindow,
          );

          proximityInfos.add(WorkerProximityInfo(
            worker1Id: worker1.workerId,
            worker1Name: worker1.workerName,
            worker2Id: worker2.workerId,
            worker2Name: worker2.workerName,
            distance: distance,
            proximityDuration: proximityDuration,
            timestamp: DateTime.now(),
          ));
        }
      }
    }

    return proximityInfos;
  }

  /// Private helper methods
  Future<void> _updateWorkerLocationFromGPS(
    String workerId,
    String workerName,
    String? currentToolId,
    String? sessionId,
  ) async {
    try {
      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied');
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 30),
      );

      // Get address (optional - could use reverse geocoding service)
      String? address;
      // TODO: Implement reverse geocoding

      await updateWorkerLocation(
        workerId: workerId,
        workerName: workerName,
        latitude: position.latitude,
        longitude: position.longitude,
        altitude: position.altitude,
        accuracy: position.accuracy,
        address: address,
        currentToolId: currentToolId,
        sessionId: sessionId,
        source: LocationSource.gps,
      );
    } catch (e) {
      print('Error updating worker location: $e');
      
      // Send location error alert
      _alertStreamController.add(WorkerLocationAlert(
        alertId: '${workerId}_location_error_${DateTime.now().millisecondsSinceEpoch}',
        workerId: workerId,
        workerName: workerName,
        alertType: LocationAlertType.locationError,
        latitude: 0.0,
        longitude: 0.0,
        timestamp: DateTime.now(),
        severity: 'warning',
        message: 'Failed to update worker location: $e',
      ));
    }
  }

  Future<void> _saveLocationHistory(WorkerLocationData location) async {
    final historyEntry = LocationHistoryEntry(
      entityId: location.workerId,
      entityType: 'worker',
      latitude: location.latitude,
      longitude: location.longitude,
      timestamp: location.timestamp,
      address: location.address,
      jobSiteId: location.jobSiteId,
      exposureLevel: null, // Would be calculated from current tool use
      metadata: {
        'workerName': location.workerName,
        'currentToolId': location.currentToolId,
        'sessionId': location.sessionId,
        'isWorking': location.isWorking,
        'source': location.source.name,
      },
    );

    await _historyService.saveLocationHistory(historyEntry);
  }

  Future<void> _checkLocationAlerts(WorkerLocationData location) async {
    // Check for workers in unauthorized areas
    final jobSites = await _geofencingService.getJobSitesContainingLocation(
      location.latitude,
      location.longitude,
    );

    for (final jobSite in jobSites) {
      if (!jobSite.authorizedWorkers.isEmpty && 
          !jobSite.authorizedWorkers.contains(location.workerId)) {
        _alertStreamController.add(WorkerLocationAlert(
          alertId: '${location.workerId}_unauthorized_${DateTime.now().millisecondsSinceEpoch}',
          workerId: location.workerId,
          workerName: location.workerName,
          alertType: LocationAlertType.unauthorizedArea,
          latitude: location.latitude,
          longitude: location.longitude,
          timestamp: DateTime.now(),
          severity: 'critical',
          message: 'Worker in unauthorized job site: ${jobSite.name}',
          metadata: {
            'jobSiteId': jobSite.id,
            'jobSiteName': jobSite.name,
          },
        ));
      }
    }
  }

  Future<Duration> _calculateProximityDuration(
    String worker1Id,
    String worker2Id,
    Duration timeWindow,
  ) async {
    // This would analyze historical location data to determine
    // how long workers have been in proximity
    // For now, return a simple approximation
    return const Duration(minutes: 1);
  }

  /// Get all active worker locations
  Future<List<WorkerLocationData>> getAllActive() async {
    if (_locationCache.isNotEmpty) {
      return _locationCache.values.toList();
    }

    final snapshot = await _firestore
        .collection(_collection)
        .where('isActive', isEqualTo: true)
        .get();

    return snapshot.docs
        .map((doc) => WorkerLocationData.fromFirestore(doc.data(), doc.id))
        .toList();
  }

  /// Dispose resources
  void dispose() {
    // Stop all tracking timers
    for (final timer in _trackingTimers.values) {
      timer.cancel();
    }
    _trackingTimers.clear();
    
    _locationStreamController.close();
    _singleLocationStreamController.close();
    _alertStreamController.close();
    _locationCache.clear();
  }
}

/// Worker location alert
class WorkerLocationAlert {
  final String alertId;
  final String workerId;
  final String workerName;
  final LocationAlertType alertType;
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final String severity;
  final String message;
  final Map<String, dynamic>? metadata;

  WorkerLocationAlert({
    required this.alertId,
    required this.workerId,
    required this.workerName,
    required this.alertType,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    required this.severity,
    required this.message,
    this.metadata,
  });

  Map<String, dynamic> toMap() {
    return {
      'alertId': alertId,
      'workerId': workerId,
      'workerName': workerName,
      'alertType': alertType.name,
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': Timestamp.fromDate(timestamp),
      'severity': severity,
      'message': message,
      'metadata': metadata,
    };
  }
}

/// Worker proximity information
class WorkerProximityInfo {
  final String worker1Id;
  final String worker1Name;
  final String worker2Id;
  final String worker2Name;
  final double distance;
  final Duration proximityDuration;
  final DateTime timestamp;

  WorkerProximityInfo({
    required this.worker1Id,
    required this.worker1Name,
    required this.worker2Id,
    required this.worker2Name,
    required this.distance,
    required this.proximityDuration,
    required this.timestamp,
  });
}

/// Location alert types
enum LocationAlertType {
  unauthorizedArea,
  highRiskArea,
  emergencyZone,
  locationError,
  proximityAlert,
  geofenceViolation;
}