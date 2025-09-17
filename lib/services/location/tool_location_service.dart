import 'dart:async';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../../models/location/location_models.dart';
import '../../models/tool/tool.dart';

/// Service for tracking tool locations and managing GPS data
class ToolLocationService {
  static const String _collection = 'tool_locations';
  static const String _historyCollection = 'tool_location_history';
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final StreamController<List<ToolLocationData>> _locationStreamController = 
      StreamController<List<ToolLocationData>>.broadcast();
  final StreamController<ToolLocationData> _singleLocationStreamController = 
      StreamController<ToolLocationData>.broadcast();

  // Cache for real-time location data
  final Map<String, ToolLocationData> _locationCache = {};
  Timer? _trackingTimer;
  
  ToolLocationService();

  /// Stream of all tool locations
  Stream<List<ToolLocationData>> get locationStream => _locationStreamController.stream;
  
  /// Stream of single tool location updates
  Stream<ToolLocationData> get singleLocationStream => _singleLocationStreamController.stream;

  /// Initialize location tracking
  Future<void> initialize() async {
    await _loadCachedLocations();
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
        final data = ToolLocationData.fromFirestore(change.doc.data()!, change.doc.id);
        
        switch (change.type) {
          case DocumentChangeType.added:
          case DocumentChangeType.modified:
            _locationCache[data.toolId] = data;
            _singleLocationStreamController.add(data);
            break;
          case DocumentChangeType.removed:
            _locationCache.remove(data.toolId);
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
      final location = ToolLocationData.fromFirestore(doc.data() as Map<String, dynamic>, doc.id);
      _locationCache[location.toolId] = location;
    }
  }

  /// Update tool location
  Future<String> updateToolLocation({
    required String toolId,
    required String toolName,
    required double latitude,
    required double longitude,
    double? altitude,
    double accuracy = 10.0,
    double? speed,
    double? heading,
    String? address,
    String? jobSiteId,
    String? workerId,
    LocationSource source = LocationSource.gps,
    Map<String, dynamic>? metadata,
  }) async {
    final now = DateTime.now();
    
    final toolLocation = ToolLocationData(
      toolId: toolId,
      toolName: toolName,
      latitude: latitude,
      longitude: longitude,
      altitude: altitude,
      accuracy: accuracy,
      speed: speed,
      heading: heading,
      timestamp: now,
      address: address,
      jobSiteId: jobSiteId,
      workerId: workerId,
      isActive: true,
      source: source,
      metadata: metadata,
      createdAt: now,
      updatedAt: now,
    );

    // Save to current locations
    final docRef = await _firestore.collection(_collection).add(toolLocation.toJson());
    final id = docRef.id;
    
    // Save to history
    await _saveLocationHistory(toolLocation);
    
    // Update cache
    _locationCache[toolId] = toolLocation.copyWith(id: id);
    _singleLocationStreamController.add(toolLocation.copyWith(id: id));
    
    return id;
  }

  /// Get current location of a specific tool
  Future<ToolLocationData?> getToolLocation(String toolId) async {
    // Check cache first
    if (_locationCache.containsKey(toolId)) {
      return _locationCache[toolId];
    }

    // Query database
    final snapshot = await _firestore
        .collection(_collection)
        .where('toolId', isEqualTo: toolId)
        .where('isActive', isEqualTo: true)
        .orderBy('timestamp', descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      final location = ToolLocationData.fromFirestore(
        snapshot.docs.first.data(),
        snapshot.docs.first.id,
      );
      _locationCache[toolId] = location;
      return location;
    }

    return null;
  }

  /// Get last known locations for multiple tools
  Future<Map<String, ToolLocationData>> getToolLocations(List<String> toolIds) async {
    final Map<String, ToolLocationData> results = {};
    
    // Get from cache first
    for (final toolId in toolIds) {
      if (_locationCache.containsKey(toolId)) {
        results[toolId] = _locationCache[toolId]!;
      }
    }
    
    // Get remaining from database
    final missingIds = toolIds.where((id) => !results.containsKey(id)).toList();
    if (missingIds.isNotEmpty) {
      final snapshot = await _firestore
          .collection(_collection)
          .where('toolId', whereIn: missingIds)
          .where('isActive', isEqualTo: true)
          .get();

      for (final doc in snapshot.docs) {
        final location = ToolLocationData.fromFirestore(doc.data() as Map<String, dynamic>, doc.id);
        results[location.toolId] = location;
        _locationCache[location.toolId] = location;
      }
    }
    
    return results;
  }

  /// Get tools within a specific radius
  Future<List<ToolLocationData>> getToolsInRadius({
    required double centerLat,
    required double centerLng,
    required double radiusMeters,
    List<String>? toolIds,
    DateTime? since,
  }) async {
    // Get all active tool locations
    Query query = _firestore
        .collection(_collection)
        .where('isActive', isEqualTo: true);

    if (toolIds != null && toolIds.isNotEmpty) {
      query = query.where('toolId', whereIn: toolIds);
    }

    if (since != null) {
      query = query.where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(since));
    }

    final snapshot = await query.get();
    final tools = <ToolLocationData>[];

    for (final doc in snapshot.docs) {
      final location = ToolLocationData.fromFirestore(doc.data() as Map<String, dynamic>, doc.id);
      final distance = Geolocator.distanceBetween(
        centerLat,
        centerLng,
        location.latitude,
        location.longitude,
      );

      if (distance <= radiusMeters) {
        tools.add(location);
      }
    }

    return tools;
  }

  /// Get location history for a tool
  Future<List<LocationHistoryEntry>> getToolLocationHistory({
    required String toolId,
    DateTime? startTime,
    DateTime? endTime,
    int limit = 100,
  }) async {
    Query query = _firestore
        .collection(_historyCollection)
        .where('entityId', isEqualTo: toolId)
        .where('entityType', isEqualTo: 'tool')
        .orderBy('timestamp', descending: true);

    if (startTime != null) {
      query = query.where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startTime));
    }

    if (endTime != null) {
      query = query.where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endTime));
    }

    query = query.limit(limit);

    final snapshot = await query.get();
    return snapshot.docs
        .map((doc) => LocationHistoryEntry.fromMap(doc.data() as Map<String, dynamic>))
        .toList();
  }

  /// Track tool movement path
  Future<List<LocationHistoryEntry>> getToolMovementPath({
    required String toolId,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    final snapshot = await _firestore
        .collection(_historyCollection)
        .where('entityId', isEqualTo: toolId)
        .where('entityType', isEqualTo: 'tool')
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startTime))
        .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endTime))
        .orderBy('timestamp', descending: false)
        .get();

    return snapshot.docs
        .map((doc) => LocationHistoryEntry.fromMap(doc.data() as Map<String, dynamic>))
        .toList();
  }

  /// Calculate distance traveled by a tool
  Future<double> calculateDistanceTraveled({
    required String toolId,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    final path = await getToolMovementPath(
      toolId: toolId,
      startTime: startTime,
      endTime: endTime,
    );

    if (path.length < 2) return 0.0;

    double totalDistance = 0.0;
    for (int i = 1; i < path.length; i++) {
      totalDistance += Geolocator.distanceBetween(
        path[i - 1].latitude,
        path[i - 1].longitude,
        path[i].latitude,
        path[i].longitude,
      );
    }

    return totalDistance;
  }

  /// Get tools that haven't moved in a specified time
  Future<List<ToolLocationData>> getStationaryTools({
    required Duration threshold,
    double movementThresholdMeters = 50.0,
  }) async {
    final cutoffTime = DateTime.now().subtract(threshold);
    final allTools = await getAllActive();
    final stationaryTools = <ToolLocationData>[];

    for (final tool in allTools) {
      if (tool.timestamp.isBefore(cutoffTime)) {
        // Check if the tool has moved significantly in the threshold period
        final recentHistory = await getToolLocationHistory(
          toolId: tool.toolId,
          startTime: cutoffTime,
          limit: 10,
        );

        if (recentHistory.length < 2) {
          stationaryTools.add(tool);
          continue;
        }

        // Calculate maximum distance moved
        double maxDistance = 0.0;
        for (final history in recentHistory) {
          final distance = Geolocator.distanceBetween(
            tool.latitude,
            tool.longitude,
            history.latitude,
            history.longitude,
          );
          maxDistance = math.max(maxDistance, distance);
        }

        if (maxDistance < movementThresholdMeters) {
          stationaryTools.add(tool);
        }
      }
    }

    return stationaryTools;
  }

  /// Start continuous tracking for a tool
  Future<void> startToolTracking(String toolId, {Duration interval = const Duration(minutes: 5)}) async {
    _trackingTimer?.cancel();
    _trackingTimer = Timer.periodic(interval, (_) async {
      await _updateToolLocationFromDevice(toolId);
    });
  }

  /// Stop tool tracking
  void stopToolTracking() {
    _trackingTimer?.cancel();
    _trackingTimer = null;
  }

  /// Update tool location from device GPS
  Future<void> _updateToolLocationFromDevice(String toolId) async {
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

      // Get tool information (would need to be provided from tool registry)
      // For now, we'll use a placeholder
      await updateToolLocation(
        toolId: toolId,
        toolName: 'Tool $toolId', // Would be fetched from tool registry
        latitude: position.latitude,
        longitude: position.longitude,
        altitude: position.altitude,
        accuracy: position.accuracy,
        speed: position.speed,
        heading: position.heading,
        source: LocationSource.gps,
      );
    } catch (e) {
      print('Error updating tool location: $e');
    }
  }

  /// Save location to history
  Future<void> _saveLocationHistory(ToolLocationData location) async {
    final historyEntry = LocationHistoryEntry(
      entityId: location.toolId,
      entityType: 'tool',
      latitude: location.latitude,
      longitude: location.longitude,
      timestamp: location.timestamp,
      address: location.address,
      jobSiteId: location.jobSiteId,
      metadata: location.metadata,
    );

    await _firestore
        .collection(_historyCollection)
        .add(historyEntry.toMap());
  }

  /// Mark tool as inactive/lost
  Future<void> markToolInactive(String toolId, {String? reason}) async {
    final currentLocation = await getToolLocation(toolId);
    if (currentLocation != null) {
      final updatedLocation = currentLocation.copyWith(
          isActive: false,
          metadata: {
            ...currentLocation.metadata ?? {},
            'deactivatedAt': DateTime.now().toIso8601String(),
            'deactivationReason': reason ?? 'manually_marked_inactive',
          },
      );
      
      await _firestore.collection(_collection).doc(currentLocation.id!).update(updatedLocation.toJson());
      _locationCache.remove(toolId);
    }
  }

  /// Get all active tool locations
  Future<List<ToolLocationData>> getAllActive() async {
    if (_locationCache.isNotEmpty) {
      return _locationCache.values.toList();
    }

    final snapshot = await _firestore
        .collection(_collection)
        .where('isActive', isEqualTo: true)
        .get();

    return snapshot.docs
        .map((doc) => ToolLocationData.fromFirestore(doc.data(), doc.id))
        .toList();
  }

  /// Clean up old location data
  Future<void> cleanupOldLocations({Duration retention = const Duration(days: 90)}) async {
    final cutoffDate = DateTime.now().subtract(retention);
    
    // Clean up current locations
    final currentSnapshot = await _firestore
        .collection(_collection)
        .where('timestamp', isLessThan: Timestamp.fromDate(cutoffDate))
        .get();

    final batch = _firestore.batch();
    for (final doc in currentSnapshot.docs) {
      batch.delete(doc.reference);
    }

    // Clean up history
    final historySnapshot = await _firestore
        .collection(_historyCollection)
        .where('timestamp', isLessThan: Timestamp.fromDate(cutoffDate))
        .get();

    for (final doc in historySnapshot.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }

  /// Dispose resources
  void dispose() {
    stopToolTracking();
    _locationStreamController.close();
    _singleLocationStreamController.close();
    _locationCache.clear();
  }
}