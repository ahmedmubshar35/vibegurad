import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../../models/location/location_models.dart';

/// Service for managing location history and analytics
class LocationHistoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _historyCollection = 'location_history';
  static const String _analyticsCollection = 'location_analytics';

  /// Save location history entry
  Future<void> saveLocationHistory(LocationHistoryEntry entry) async {
    await _firestore
        .collection(_historyCollection)
        .add(entry.toMap());
  }

  /// Batch save multiple location history entries
  Future<void> batchSaveLocationHistory(List<LocationHistoryEntry> entries) async {
    if (entries.isEmpty) return;

    final batch = _firestore.batch();
    for (final entry in entries) {
      final docRef = _firestore.collection(_historyCollection).doc();
      batch.set(docRef, entry.toMap());
    }

    await batch.commit();
  }

  /// Get location history for an entity
  Future<List<LocationHistoryEntry>> getLocationHistory({
    required String entityId,
    required String entityType,
    DateTime? startTime,
    DateTime? endTime,
    int limit = 1000,
    String? jobSiteId,
  }) async {
    Query query = _firestore
        .collection(_historyCollection)
        .where('entityId', isEqualTo: entityId)
        .where('entityType', isEqualTo: entityType);

    if (startTime != null) {
      query = query.where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startTime));
    }

    if (endTime != null) {
      query = query.where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endTime));
    }

    if (jobSiteId != null) {
      query = query.where('jobSiteId', isEqualTo: jobSiteId);
    }

    query = query.orderBy('timestamp', descending: false).limit(limit);

    final snapshot = await query.get();
    return snapshot.docs
        .map((doc) => LocationHistoryEntry.fromMap(doc.data() as Map<String, dynamic>))
        .toList();
  }

  /// Get movement path for visualization
  Future<List<LocationHistoryEntry>> getMovementPath({
    required String entityId,
    required String entityType,
    required DateTime startTime,
    required DateTime endTime,
    double minimumDistanceMeters = 10.0, // Filter out small movements
  }) async {
    final allHistory = await getLocationHistory(
      entityId: entityId,
      entityType: entityType,
      startTime: startTime,
      endTime: endTime,
    );

    if (allHistory.isEmpty) return [];

    // Filter out points that are too close to previous point
    final filteredPath = <LocationHistoryEntry>[allHistory.first];
    
    for (int i = 1; i < allHistory.length; i++) {
      final current = allHistory[i];
      final previous = filteredPath.last;
      
      final distance = Geolocator.distanceBetween(
        previous.latitude,
        previous.longitude,
        current.latitude,
        current.longitude,
      );
      
      if (distance >= minimumDistanceMeters) {
        filteredPath.add(current);
      }
    }

    return filteredPath;
  }

  /// Calculate distance traveled
  Future<double> calculateDistanceTraveled({
    required String entityId,
    required String entityType,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    final path = await getMovementPath(
      entityId: entityId,
      entityType: entityType,
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

  /// Calculate average speed
  Future<double> calculateAverageSpeed({
    required String entityId,
    required String entityType,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    final distance = await calculateDistanceTraveled(
      entityId: entityId,
      entityType: entityType,
      startTime: startTime,
      endTime: endTime,
    );

    final duration = endTime.difference(startTime);
    if (duration.inSeconds == 0) return 0.0;

    return distance / duration.inSeconds; // meters per second
  }

  /// Get location statistics
  Future<LocationStatistics> getLocationStatistics({
    required String entityId,
    required String entityType,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    final history = await getLocationHistory(
      entityId: entityId,
      entityType: entityType,
      startTime: startTime,
      endTime: endTime,
    );

    if (history.isEmpty) {
      return LocationStatistics(
        entityId: entityId,
        entityType: entityType,
        startTime: startTime,
        endTime: endTime,
        totalDataPoints: 0,
        distanceTraveled: 0.0,
        averageSpeed: 0.0,
        maxSpeed: 0.0,
        timeMoving: Duration.zero,
        timeStationary: endTime.difference(startTime),
        uniqueLocations: 0,
        jobSitesVisited: [],
        averageExposureLevel: 0.0,
        maxExposureLevel: 0.0,
      );
    }

    final distanceTraveled = await calculateDistanceTraveled(
      entityId: entityId,
      entityType: entityType,
      startTime: startTime,
      endTime: endTime,
    );

    final averageSpeed = await calculateAverageSpeed(
      entityId: entityId,
      entityType: entityType,
      startTime: startTime,
      endTime: endTime,
    );

    // Calculate unique locations (simplified - using grid-based approach)
    final uniqueLocations = _calculateUniqueLocations(history);

    // Get job sites visited
    final jobSitesVisited = history
        .where((h) => h.jobSiteId != null)
        .map((h) => h.jobSiteId!)
        .toSet()
        .toList();

    // Calculate exposure statistics
    final exposureLevels = history
        .where((h) => h.exposureLevel != null)
        .map((h) => h.exposureLevel!)
        .toList();

    final averageExposure = exposureLevels.isNotEmpty
        ? exposureLevels.reduce((a, b) => a + b) / exposureLevels.length
        : 0.0;

    final maxExposure = exposureLevels.isNotEmpty
        ? exposureLevels.reduce((a, b) => a > b ? a : b)
        : 0.0;

    // Calculate movement times (simplified)
    final movingTime = _calculateMovingTime(history);
    final totalTime = endTime.difference(startTime);
    final stationaryTime = totalTime - movingTime;

    return LocationStatistics(
      entityId: entityId,
      entityType: entityType,
      startTime: startTime,
      endTime: endTime,
      totalDataPoints: history.length,
      distanceTraveled: distanceTraveled,
      averageSpeed: averageSpeed,
      maxSpeed: 0.0, // Would need speed calculation from consecutive points
      timeMoving: movingTime,
      timeStationary: stationaryTime,
      uniqueLocations: uniqueLocations,
      jobSitesVisited: jobSitesVisited,
      averageExposureLevel: averageExposure,
      maxExposureLevel: maxExposure,
    );
  }

  /// Get heat map data for high activity areas
  Future<List<VibrationHeatMapPoint>> getHeatMapData({
    DateTime? startTime,
    DateTime? endTime,
    String? jobSiteId,
    double? minExposureLevel,
    double gridResolutionMeters = 100.0,
  }) async {
    Query query = _firestore.collection(_historyCollection);

    if (startTime != null) {
      query = query.where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startTime));
    }

    if (endTime != null) {
      query = query.where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endTime));
    }

    if (jobSiteId != null) {
      query = query.where('jobSiteId', isEqualTo: jobSiteId);
    }

    if (minExposureLevel != null) {
      query = query.where('exposureLevel', isGreaterThanOrEqualTo: minExposureLevel);
    }

    final snapshot = await query.get();
    final history = snapshot.docs
        .map((doc) => LocationHistoryEntry.fromMap(doc.data() as Map<String, dynamic>))
        .where((entry) => entry.exposureLevel != null)
        .toList();

    // Group by grid cells
    final Map<String, List<LocationHistoryEntry>> gridCells = {};
    
    for (final entry in history) {
      final gridKey = _getGridKey(entry.latitude, entry.longitude, gridResolutionMeters);
      gridCells.putIfAbsent(gridKey, () => []).add(entry);
    }

    // Create heat map points
    final heatMapPoints = <VibrationHeatMapPoint>[];
    
    for (final cellEntries in gridCells.values) {
      if (cellEntries.isEmpty) continue;

      final centerLat = cellEntries.map((e) => e.latitude).reduce((a, b) => a + b) / cellEntries.length;
      final centerLng = cellEntries.map((e) => e.longitude).reduce((a, b) => a + b) / cellEntries.length;
      final avgVibration = cellEntries.map((e) => e.exposureLevel!).reduce((a, b) => a + b) / cellEntries.length;
      
      // Calculate exposure time (rough estimate)
      const avgSessionDuration = 15.0; // minutes per data point
      final exposureTime = cellEntries.length * avgSessionDuration;
      
      // Get unique tools used
      final toolsUsed = cellEntries
          .where((e) => e.metadata?['toolId'] != null)
          .map((e) => e.metadata!['toolId'] as String)
          .toSet()
          .toList();

      final heatMapPoint = VibrationHeatMapPoint(
        latitude: centerLat,
        longitude: centerLng,
        vibrationLevel: avgVibration,
        exposureTime: exposureTime,
        sessionCount: cellEntries.length,
        lastUpdated: cellEntries.map((e) => e.timestamp).reduce((a, b) => a.isAfter(b) ? a : b),
        toolsUsed: toolsUsed,
      );

      heatMapPoints.add(heatMapPoint);
    }

    return heatMapPoints;
  }

  /// Get frequently visited locations
  Future<List<FrequentLocation>> getFrequentLocations({
    required String entityId,
    required String entityType,
    DateTime? startTime,
    DateTime? endTime,
    double radiusMeters = 50.0,
    int minVisits = 3,
  }) async {
    final history = await getLocationHistory(
      entityId: entityId,
      entityType: entityType,
      startTime: startTime,
      endTime: endTime,
    );

    // Cluster locations by proximity
    final clusters = <List<LocationHistoryEntry>>[];
    
    for (final entry in history) {
      bool addedToCluster = false;
      
      for (final cluster in clusters) {
        final clusterCenter = cluster.first;
        final distance = Geolocator.distanceBetween(
          clusterCenter.latitude,
          clusterCenter.longitude,
          entry.latitude,
          entry.longitude,
        );
        
        if (distance <= radiusMeters) {
          cluster.add(entry);
          addedToCluster = true;
          break;
        }
      }
      
      if (!addedToCluster) {
        clusters.add([entry]);
      }
    }

    // Create frequent locations from clusters with enough visits
    final frequentLocations = <FrequentLocation>[];
    
    for (final cluster in clusters) {
      if (cluster.length >= minVisits) {
        final centerLat = cluster.map((e) => e.latitude).reduce((a, b) => a + b) / cluster.length;
        final centerLng = cluster.map((e) => e.longitude).reduce((a, b) => a + b) / cluster.length;
        
        final firstVisit = cluster.map((e) => e.timestamp).reduce((a, b) => a.isBefore(b) ? a : b);
        final lastVisit = cluster.map((e) => e.timestamp).reduce((a, b) => a.isAfter(b) ? a : b);
        
        final avgExposure = cluster
            .where((e) => e.exposureLevel != null)
            .map((e) => e.exposureLevel!)
            .fold(0.0, (a, b) => a + b) / cluster.where((e) => e.exposureLevel != null).length;

        frequentLocations.add(FrequentLocation(
          latitude: centerLat,
          longitude: centerLng,
          visitCount: cluster.length,
          firstVisit: firstVisit,
          lastVisit: lastVisit,
          averageExposureLevel: avgExposure.isNaN ? 0.0 : avgExposure,
          address: cluster.first.address,
          jobSiteId: cluster.first.jobSiteId,
        ));
      }
    }

    // Sort by visit count
    frequentLocations.sort((a, b) => b.visitCount.compareTo(a.visitCount));
    
    return frequentLocations;
  }

  /// Archive old location history
  Future<void> archiveOldHistory({Duration retention = const Duration(days: 365)}) async {
    final cutoffDate = DateTime.now().subtract(retention);
    
    // Move old data to archive collection
    final snapshot = await _firestore
        .collection(_historyCollection)
        .where('timestamp', isLessThan: Timestamp.fromDate(cutoffDate))
        .get();

    if (snapshot.docs.isEmpty) return;

    final batch = _firestore.batch();
    
    // Copy to archive
    for (final doc in snapshot.docs) {
      final archiveRef = _firestore.collection('${_historyCollection}_archive').doc();
      batch.set(archiveRef, doc.data());
    }
    
    // Delete from main collection
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }

  /// Generate location analytics summary
  Future<void> generateDailyAnalytics(DateTime date) async {
    final startTime = DateTime(date.year, date.month, date.day);
    final endTime = startTime.add(const Duration(days: 1));

    // Get all entities that have location data for this day
    final snapshot = await _firestore
        .collection(_historyCollection)
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startTime))
        .where('timestamp', isLessThan: Timestamp.fromDate(endTime))
        .get();

    final entityData = <String, List<LocationHistoryEntry>>{};
    
    for (final doc in snapshot.docs) {
      final entry = LocationHistoryEntry.fromMap(doc.data());
      final key = '${entry.entityType}:${entry.entityId}';
      entityData.putIfAbsent(key, () => []).add(entry);
    }

    // Generate analytics for each entity
    final batch = _firestore.batch();
    
    for (final entry in entityData.entries) {
      final keyParts = entry.key.split(':');
      final entityType = keyParts[0];
      final entityId = keyParts[1];
      
      final stats = await getLocationStatistics(
        entityId: entityId,
        entityType: entityType,
        startTime: startTime,
        endTime: endTime,
      );

      final analyticsRef = _firestore.collection(_analyticsCollection).doc();
      batch.set(analyticsRef, stats.toMap());
    }

    await batch.commit();
  }

  /// Helper methods
  String _getGridKey(double lat, double lng, double resolution) {
    final latGrid = (lat / resolution * 111000).round(); // Rough conversion to meters
    final lngGrid = (lng / resolution * 111000).round();
    return '$latGrid,$lngGrid';
  }

  int _calculateUniqueLocations(List<LocationHistoryEntry> history) {
    final locations = <String>{};
    const resolution = 0.0001; // ~10 meters
    
    for (final entry in history) {
      final key = _getGridKey(entry.latitude, entry.longitude, resolution);
      locations.add(key);
    }
    
    return locations.length;
  }

  Duration _calculateMovingTime(List<LocationHistoryEntry> history) {
    if (history.length < 2) return Duration.zero;

    Duration movingTime = Duration.zero;
    const movementThreshold = 10.0; // meters

    for (int i = 1; i < history.length; i++) {
      final distance = Geolocator.distanceBetween(
        history[i - 1].latitude,
        history[i - 1].longitude,
        history[i].latitude,
        history[i].longitude,
      );

      if (distance > movementThreshold) {
        final timeDiff = history[i].timestamp.difference(history[i - 1].timestamp);
        movingTime += timeDiff;
      }
    }

    return movingTime;
  }
}

/// Location statistics model
class LocationStatistics {
  final String entityId;
  final String entityType;
  final DateTime startTime;
  final DateTime endTime;
  final int totalDataPoints;
  final double distanceTraveled;
  final double averageSpeed;
  final double maxSpeed;
  final Duration timeMoving;
  final Duration timeStationary;
  final int uniqueLocations;
  final List<String> jobSitesVisited;
  final double averageExposureLevel;
  final double maxExposureLevel;

  LocationStatistics({
    required this.entityId,
    required this.entityType,
    required this.startTime,
    required this.endTime,
    required this.totalDataPoints,
    required this.distanceTraveled,
    required this.averageSpeed,
    required this.maxSpeed,
    required this.timeMoving,
    required this.timeStationary,
    required this.uniqueLocations,
    required this.jobSitesVisited,
    required this.averageExposureLevel,
    required this.maxExposureLevel,
  });

  Map<String, dynamic> toMap() {
    return {
      'entityId': entityId,
      'entityType': entityType,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'totalDataPoints': totalDataPoints,
      'distanceTraveled': distanceTraveled,
      'averageSpeed': averageSpeed,
      'maxSpeed': maxSpeed,
      'timeMovingSeconds': timeMoving.inSeconds,
      'timeStationarySeconds': timeStationary.inSeconds,
      'uniqueLocations': uniqueLocations,
      'jobSitesVisited': jobSitesVisited,
      'averageExposureLevel': averageExposureLevel,
      'maxExposureLevel': maxExposureLevel,
    };
  }
}

/// Frequent location model
class FrequentLocation {
  final double latitude;
  final double longitude;
  final int visitCount;
  final DateTime firstVisit;
  final DateTime lastVisit;
  final double averageExposureLevel;
  final String? address;
  final String? jobSiteId;

  FrequentLocation({
    required this.latitude,
    required this.longitude,
    required this.visitCount,
    required this.firstVisit,
    required this.lastVisit,
    required this.averageExposureLevel,
    this.address,
    this.jobSiteId,
  });

  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'visitCount': visitCount,
      'firstVisit': Timestamp.fromDate(firstVisit),
      'lastVisit': Timestamp.fromDate(lastVisit),
      'averageExposureLevel': averageExposureLevel,
      'address': address,
      'jobSiteId': jobSiteId,
    };
  }
}