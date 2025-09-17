import 'dart:async';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import '../../models/location/location_models.dart';
import 'location_history_service.dart';
import 'tool_location_service.dart';

/// Service for generating and managing vibration heat maps
class VibrationHeatMapService {
  final firestore.FirebaseFirestore _firestore = firestore.FirebaseFirestore.instance;
  final LocationHistoryService _historyService = LocationHistoryService();
  final ToolLocationService _toolLocationService = ToolLocationService();
  
  static const String _heatMapDataCollection = 'vibration_heatmap_data';
  static const String _heatMapConfigCollection = 'heatmap_configurations';
  static const String _hotSpotsCollection = 'vibration_hotspots';

  final StreamController<List<VibrationHeatMapPoint>> _heatMapUpdateController = 
      StreamController<List<VibrationHeatMapPoint>>.broadcast();

  /// Stream of heat map updates
  Stream<List<VibrationHeatMapPoint>> get heatMapUpdateStream => _heatMapUpdateController.stream;

  /// Initialize heat map service
  Future<void> initialize() async {
    await _toolLocationService.initialize();
    _startPeriodicHeatMapUpdates();
  }

  /// Start periodic heat map data updates
  void _startPeriodicHeatMapUpdates() {
    // Update heat map data every hour
    Timer.periodic(const Duration(hours: 1), (_) async {
      await updateHeatMapData();
    });
  }

  /// Generate heat map data for a specific area and time period
  Future<List<VibrationHeatMapPoint>> generateHeatMap({
    String? jobSiteId,
    DateTime? startTime,
    DateTime? endTime,
    double? minVibrationLevel,
    double gridResolutionMeters = 50.0,
    List<String>? toolIds,
    List<String>? workerIds,
  }) async {
    startTime ??= DateTime.now().subtract(const Duration(days: 30));
    endTime ??= DateTime.now();

    // Get location history with vibration data
    final vibrationData = await _getVibrationLocationData(
      jobSiteId: jobSiteId,
      startTime: startTime,
      endTime: endTime,
      minVibrationLevel: minVibrationLevel,
      toolIds: toolIds,
      workerIds: workerIds,
    );

    if (vibrationData.isEmpty) return [];

    // Group data into grid cells
    final gridCells = _groupIntoGridCells(vibrationData, gridResolutionMeters);

    // Create heat map points from grid cells
    final heatMapPoints = <VibrationHeatMapPoint>[];
    
    for (final cell in gridCells.values) {
      if (cell.isEmpty) continue;

      final heatMapPoint = _createHeatMapPoint(cell);
      heatMapPoints.add(heatMapPoint);
    }

    // Save heat map data to database
    await _saveHeatMapData(heatMapPoints, jobSiteId);

    // Emit update
    _heatMapUpdateController.add(heatMapPoints);

    return heatMapPoints;
  }

  /// Get cached heat map data
  Future<List<VibrationHeatMapPoint>> getCachedHeatMap({
    String? jobSiteId,
    DateTime? maxAge,
  }) async {
    firestore.Query query = _firestore.collection(_heatMapDataCollection);

    if (jobSiteId != null) {
      query = query.where('jobSiteId', isEqualTo: jobSiteId);
    }

    if (maxAge != null) {
      query = query.where('lastUpdated', isGreaterThanOrEqualTo: firestore.Timestamp.fromDate(maxAge));
    }

    query = query.orderBy('vibrationLevel', descending: true);

    final snapshot = await query.get();
    return snapshot.docs
        .map((doc) => VibrationHeatMapPoint.fromMap(doc.data() as Map<String, dynamic>))
        .toList();
  }

  /// Identify high-risk vibration hotspots
  Future<List<VibrationHotSpot>> identifyHotSpots({
    String? jobSiteId,
    double vibrationThreshold = 8.0,
    int minSessionCount = 5,
    double minExposureTime = 30.0, // minutes
  }) async {
    final heatMapData = await getCachedHeatMap(jobSiteId: jobSiteId);
    
    final hotSpots = <VibrationHotSpot>[];
    
    for (final point in heatMapData) {
      if (point.vibrationLevel >= vibrationThreshold &&
          point.sessionCount >= minSessionCount &&
          point.exposureTime >= minExposureTime) {
        
        final hotSpot = VibrationHotSpot(
          id: '${point.latitude}_${point.longitude}',
          jobSiteId: jobSiteId ?? 'unknown',
          latitude: point.latitude,
          longitude: point.longitude,
          vibrationLevel: point.vibrationLevel,
          exposureTime: point.exposureTime,
          sessionCount: point.sessionCount,
          toolsUsed: point.toolsUsed,
          riskLevel: _calculateRiskLevel(point.vibrationLevel, point.exposureTime),
          firstDetected: point.lastUpdated,
          lastUpdated: point.lastUpdated,
          isActive: true,
          severity: _calculateSeverity(point.vibrationLevel, point.exposureTime, point.sessionCount),
          recommendations: _generateRecommendations(point),
        );

        hotSpots.add(hotSpot);
      }
    }

    // Save hot spots to database
    await _saveHotSpots(hotSpots);

    return hotSpots;
  }

  /// Get vibration exposure trends over time
  Future<List<VibrationTrend>> getVibrationTrends({
    String? jobSiteId,
    required DateTime startTime,
    required DateTime endTime,
    Duration aggregationPeriod = const Duration(days: 1),
  }) async {
    final trends = <VibrationTrend>[];
    
    DateTime currentTime = startTime;
    while (currentTime.isBefore(endTime)) {
      final periodEnd = currentTime.add(aggregationPeriod);
      
      final heatMapData = await generateHeatMap(
        jobSiteId: jobSiteId,
        startTime: currentTime,
        endTime: periodEnd,
        gridResolutionMeters: 100.0,
      );

      if (heatMapData.isNotEmpty) {
        final avgVibration = heatMapData
            .map((p) => p.vibrationLevel)
            .reduce((a, b) => a + b) / heatMapData.length;
        
        final maxVibration = heatMapData
            .map((p) => p.vibrationLevel)
            .reduce(math.max);
        
        final totalExposureTime = heatMapData
            .map((p) => p.exposureTime)
            .reduce((a, b) => a + b);

        trends.add(VibrationTrend(
          timestamp: currentTime,
          averageVibration: avgVibration,
          maxVibration: maxVibration,
          totalExposureTime: totalExposureTime,
          hotSpotCount: heatMapData.where((p) => p.vibrationLevel > 8.0).length,
        ));
      }

      currentTime = periodEnd;
    }

    return trends;
  }

  /// Generate exposure risk zones
  Future<List<ExposureRiskZone>> generateRiskZones({
    String? jobSiteId,
    double lowRiskThreshold = 2.5,
    double mediumRiskThreshold = 5.0,
    double highRiskThreshold = 8.0,
  }) async {
    final heatMapData = await getCachedHeatMap(jobSiteId: jobSiteId);
    
    // Group points by risk level and create zones
    final Map<RiskLevel, List<VibrationHeatMapPoint>> riskGroups = {};
    
    for (final point in heatMapData) {
      final riskLevel = _getRiskLevelFromVibration(
        point.vibrationLevel,
        lowRiskThreshold,
        mediumRiskThreshold,
        highRiskThreshold,
      );
      
      riskGroups.putIfAbsent(riskLevel, () => []).add(point);
    }

    final riskZones = <ExposureRiskZone>[];
    
    for (final entry in riskGroups.entries) {
      if (entry.value.isEmpty) continue;

      // Calculate zone boundaries
      final latitudes = entry.value.map((p) => p.latitude);
      final longitudes = entry.value.map((p) => p.longitude);
      
      final centerLat = latitudes.reduce((a, b) => a + b) / latitudes.length;
      final centerLng = longitudes.reduce((a, b) => a + b) / longitudes.length;
      
      final minLat = latitudes.reduce(math.min);
      final maxLat = latitudes.reduce(math.max);
      final minLng = longitudes.reduce(math.min);
      final maxLng = longitudes.reduce(math.max);

      final zone = ExposureRiskZone(
        id: '${entry.key.name}_${jobSiteId ?? 'global'}',
        jobSiteId: jobSiteId,
        riskLevel: entry.key,
        centerLatitude: centerLat,
        centerLongitude: centerLng,
        boundaryPoints: [
          firestore.GeoPoint(minLat, minLng),
          firestore.GeoPoint(minLat, maxLng),
          firestore.GeoPoint(maxLat, maxLng),
          firestore.GeoPoint(maxLat, minLng),
        ],
        averageVibration: entry.value.map((p) => p.vibrationLevel).reduce((a, b) => a + b) / entry.value.length,
        maxVibration: entry.value.map((p) => p.vibrationLevel).reduce(math.max),
        pointCount: entry.value.length,
        recommendedPPE: _getRecommendedPPE(entry.key),
        restrictions: _getZoneRestrictions(entry.key),
        createdAt: DateTime.now(),
      );

      riskZones.add(zone);
    }

    return riskZones;
  }

  /// Create heat map overlay data for visualization
  Future<HeatMapOverlay> createHeatMapOverlay({
    String? jobSiteId,
    double intensity = 1.0,
    int radiusMeters = 50,
    Map<double, String>? colorGradient,
  }) async {
    final heatMapData = await getCachedHeatMap(jobSiteId: jobSiteId);
    
    // Default color gradient if not provided
    colorGradient ??= {
      0.0: '#00FF00', // Green - low vibration
      2.5: '#FFFF00', // Yellow - medium vibration
      5.0: '#FFA500', // Orange - high vibration
      8.0: '#FF0000', // Red - very high vibration
    };

    final overlayPoints = heatMapData.map((point) => HeatMapOverlayPoint(
      latitude: point.latitude,
      longitude: point.longitude,
      intensity: _normalizeIntensity(point.vibrationLevel, intensity),
      radius: _calculatePointRadius(point.sessionCount, radiusMeters),
      color: _interpolateColor(point.vibrationLevel, colorGradient ?? {}),
      metadata: {
        'vibrationLevel': point.vibrationLevel,
        'exposureTime': point.exposureTime,
        'sessionCount': point.sessionCount,
        'toolsUsed': point.toolsUsed,
      },
    )).toList();

    return HeatMapOverlay(
      jobSiteId: jobSiteId,
      points: overlayPoints,
      colorGradient: colorGradient ?? {},
      maxIntensity: heatMapData.isNotEmpty 
          ? heatMapData.map((p) => p.vibrationLevel).reduce(math.max)
          : 0.0,
      generatedAt: DateTime.now(),
    );
  }

  /// Update heat map data (called periodically or manually)
  Future<void> updateHeatMapData() async {
    final jobSites = await _getActiveJobSites();
    
    for (final jobSiteId in jobSites) {
      await generateHeatMap(jobSiteId: jobSiteId);
    }

    // Clean up old heat map data
    await _cleanupOldHeatMapData();
  }

  /// Get vibration statistics for an area
  Future<VibrationAreaStatistics> getAreaStatistics({
    required double centerLat,
    required double centerLng,
    required double radiusMeters,
    DateTime? startTime,
    DateTime? endTime,
  }) async {
    final heatMapData = await getCachedHeatMap();
    
    // Filter points within the radius
    final pointsInArea = heatMapData.where((point) {
      final distance = _calculateDistance(
        centerLat, centerLng,
        point.latitude, point.longitude,
      );
      return distance <= radiusMeters;
    }).toList();

    if (pointsInArea.isEmpty) {
      return VibrationAreaStatistics(
        centerLatitude: centerLat,
        centerLongitude: centerLng,
        radiusMeters: radiusMeters,
        totalDataPoints: 0,
        averageVibration: 0.0,
        maxVibration: 0.0,
        minVibration: 0.0,
        totalExposureTime: 0.0,
        uniqueTools: [],
        riskLevel: RiskLevel.low,
      );
    }

    final vibrationLevels = pointsInArea.map((p) => p.vibrationLevel).toList();
    final totalExposureTime = pointsInArea.map((p) => p.exposureTime).reduce((a, b) => a + b);
    final uniqueTools = pointsInArea
        .expand((p) => p.toolsUsed)
        .toSet()
        .toList();

    return VibrationAreaStatistics(
      centerLatitude: centerLat,
      centerLongitude: centerLng,
      radiusMeters: radiusMeters,
      totalDataPoints: pointsInArea.length,
      averageVibration: vibrationLevels.reduce((a, b) => a + b) / vibrationLevels.length,
      maxVibration: vibrationLevels.reduce(math.max),
      minVibration: vibrationLevels.reduce(math.min),
      totalExposureTime: totalExposureTime,
      uniqueTools: uniqueTools,
      riskLevel: _getRiskLevelFromVibration(
        vibrationLevels.reduce(math.max),
        2.5, 5.0, 8.0,
      ),
    );
  }

  /// Private helper methods
  Future<List<VibrationLocationData>> _getVibrationLocationData({
    String? jobSiteId,
    required DateTime startTime,
    required DateTime endTime,
    double? minVibrationLevel,
    List<String>? toolIds,
    List<String>? workerIds,
  }) async {
    firestore.Query query = _firestore.collection('location_history');

    query = query
        .where('timestamp', isGreaterThanOrEqualTo: firestore.Timestamp.fromDate(startTime))
        .where('timestamp', isLessThanOrEqualTo: firestore.Timestamp.fromDate(endTime));

    if (jobSiteId != null) {
      query = query.where('jobSiteId', isEqualTo: jobSiteId);
    }

    if (minVibrationLevel != null) {
      query = query.where('exposureLevel', isGreaterThanOrEqualTo: minVibrationLevel);
    }

    if (toolIds != null && toolIds.isNotEmpty) {
      query = query.where('metadata.toolId', whereIn: toolIds);
    }

    if (workerIds != null && workerIds.isNotEmpty) {
      query = query.where('entityId', whereIn: workerIds);
    }

    final snapshot = await query.get();
    
    return snapshot.docs
        .map((doc) => VibrationLocationData.fromMap(doc.data() as Map<String, dynamic>))
        .where((data) => data.vibrationLevel != null)
        .toList();
  }

  Map<String, List<VibrationLocationData>> _groupIntoGridCells(
    List<VibrationLocationData> data,
    double gridResolutionMeters,
  ) {
    final Map<String, List<VibrationLocationData>> gridCells = {};
    
    for (final point in data) {
      final gridKey = _getGridKey(point.latitude, point.longitude, gridResolutionMeters);
      gridCells.putIfAbsent(gridKey, () => []).add(point);
    }
    
    return gridCells;
  }

  VibrationHeatMapPoint _createHeatMapPoint(List<VibrationLocationData> cellData) {
    final centerLat = cellData.map((d) => d.latitude).reduce((a, b) => a + b) / cellData.length;
    final centerLng = cellData.map((d) => d.longitude).reduce((a, b) => a + b) / cellData.length;
    
    final vibrationLevels = cellData.map((d) => d.vibrationLevel!).toList();
    final avgVibration = vibrationLevels.reduce((a, b) => a + b) / vibrationLevels.length;
    
    const avgSessionDuration = 15.0; // minutes per data point
    final exposureTime = cellData.length * avgSessionDuration;
    
    final toolsUsed = cellData
        .where((d) => d.toolId != null)
        .map((d) => d.toolId!)
        .toSet()
        .toList();

    return VibrationHeatMapPoint(
      latitude: centerLat,
      longitude: centerLng,
      vibrationLevel: avgVibration,
      exposureTime: exposureTime,
      sessionCount: cellData.length,
      lastUpdated: cellData.map((d) => d.timestamp).reduce((a, b) => a.isAfter(b) ? a : b),
      toolsUsed: toolsUsed,
    );
  }

  String _getGridKey(double lat, double lng, double resolutionMeters) {
    const double metersPerDegree = 111000.0; // Rough approximation
    final latGrid = (lat / (resolutionMeters / metersPerDegree)).round();
    final lngGrid = (lng / (resolutionMeters / metersPerDegree)).round();
    return '$latGrid,$lngGrid';
  }

  RiskLevel _calculateRiskLevel(double vibrationLevel, double exposureTime) {
    if (vibrationLevel >= 8.0 && exposureTime >= 60) return RiskLevel.critical;
    if (vibrationLevel >= 5.0 && exposureTime >= 120) return RiskLevel.high;
    if (vibrationLevel >= 2.5 && exposureTime >= 240) return RiskLevel.medium;
    return RiskLevel.low;
  }

  String _calculateSeverity(double vibrationLevel, double exposureTime, int sessionCount) {
    if (vibrationLevel >= 8.0 || exposureTime >= 480 || sessionCount >= 50) return 'critical';
    if (vibrationLevel >= 5.0 || exposureTime >= 240 || sessionCount >= 20) return 'high';
    if (vibrationLevel >= 2.5 || exposureTime >= 120 || sessionCount >= 10) return 'medium';
    return 'low';
  }

  List<String> _generateRecommendations(VibrationHeatMapPoint point) {
    final recommendations = <String>[];
    
    if (point.vibrationLevel > 8.0) {
      recommendations.add('Consider restricting access to this area');
      recommendations.add('Mandatory use of anti-vibration gloves');
      recommendations.add('Limit exposure time to 15 minutes per session');
    } else if (point.vibrationLevel > 5.0) {
      recommendations.add('Enhanced PPE required in this area');
      recommendations.add('Regular break intervals recommended');
      recommendations.add('Monitor worker exposure levels closely');
    } else if (point.vibrationLevel > 2.5) {
      recommendations.add('Standard PPE recommended');
      recommendations.add('Regular health surveillance');
    }

    if (point.exposureTime > 240) {
      recommendations.add('High exposure time detected - review work practices');
    }

    if (point.sessionCount > 30) {
      recommendations.add('Frequently used area - implement preventive measures');
    }

    return recommendations;
  }

  RiskLevel _getRiskLevelFromVibration(
    double vibration,
    double lowThreshold,
    double mediumThreshold,
    double highThreshold,
  ) {
    if (vibration >= highThreshold) return RiskLevel.critical;
    if (vibration >= mediumThreshold) return RiskLevel.high;
    if (vibration >= lowThreshold) return RiskLevel.medium;
    return RiskLevel.low;
  }

  List<String> _getRecommendedPPE(RiskLevel riskLevel) {
    switch (riskLevel) {
      case RiskLevel.critical:
        return ['Anti-vibration gloves', 'Full-body anti-vibration suit', 'Hearing protection'];
      case RiskLevel.high:
        return ['Anti-vibration gloves', 'Arm protection', 'Hearing protection'];
      case RiskLevel.medium:
        return ['Anti-vibration gloves', 'Hearing protection'];
      case RiskLevel.low:
        return ['Standard work gloves'];
    }
  }

  List<String> _getZoneRestrictions(RiskLevel riskLevel) {
    switch (riskLevel) {
      case RiskLevel.critical:
        return ['Maximum 15 minutes exposure per session', 'Mandatory 2-hour breaks', 'Supervisor approval required'];
      case RiskLevel.high:
        return ['Maximum 30 minutes exposure per session', 'Mandatory 1-hour breaks'];
      case RiskLevel.medium:
        return ['Maximum 2 hours exposure per day', 'Regular breaks recommended'];
      case RiskLevel.low:
        return ['Standard work practices apply'];
    }
  }

  double _normalizeIntensity(double vibrationLevel, double maxIntensity) {
    return (vibrationLevel / 10.0).clamp(0.0, maxIntensity);
  }

  int _calculatePointRadius(int sessionCount, int baseRadius) {
    return (baseRadius * (1 + sessionCount / 10.0)).round();
  }

  String _interpolateColor(double vibrationLevel, Map<double, String> colorGradient) {
    final sortedThresholds = colorGradient.keys.toList()..sort();
    
    for (int i = 0; i < sortedThresholds.length; i++) {
      if (vibrationLevel <= sortedThresholds[i]) {
        return colorGradient[sortedThresholds[i]]!;
      }
    }
    
    return colorGradient[sortedThresholds.last]!;
  }

  double _calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    const double earthRadius = 6371000; // meters
    final dLat = _degreesToRadians(lat2 - lat1);
    final dLng = _degreesToRadians(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) * math.cos(_degreesToRadians(lat2)) *
        math.sin(dLng / 2) * math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * math.pi / 180;
  }

  Future<List<String>> _getActiveJobSites() async {
    final snapshot = await _firestore
        .collection('job_sites')
        .where('isActive', isEqualTo: true)
        .get();
    
    return snapshot.docs.map((doc) => doc.id).toList();
  }

  Future<void> _saveHeatMapData(List<VibrationHeatMapPoint> points, String? jobSiteId) async {
    if (points.isEmpty) return;

    final batch = _firestore.batch();
    
    for (final point in points) {
      final docRef = _firestore.collection(_heatMapDataCollection).doc();
      batch.set(docRef, {
        ...point.toMap(),
        'jobSiteId': jobSiteId,
      });
    }
    
    await batch.commit();
  }

  Future<void> _saveHotSpots(List<VibrationHotSpot> hotSpots) async {
    if (hotSpots.isEmpty) return;

    final batch = _firestore.batch();
    
    for (final hotSpot in hotSpots) {
      final docRef = _firestore.collection(_hotSpotsCollection).doc(hotSpot.id);
      batch.set(docRef, hotSpot.toMap(), firestore.SetOptions(merge: true));
    }
    
    await batch.commit();
  }

  Future<void> _cleanupOldHeatMapData() async {
    final cutoffDate = DateTime.now().subtract(const Duration(days: 30));
    
    final snapshot = await _firestore
        .collection(_heatMapDataCollection)
        .where('lastUpdated', isLessThan: firestore.Timestamp.fromDate(cutoffDate))
        .get();

    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    
    await batch.commit();
  }

  /// Dispose resources
  void dispose() {
    _heatMapUpdateController.close();
  }
}

/// Vibration location data with exposure information
class VibrationLocationData {
  final String entityId;
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final String? jobSiteId;
  final String? toolId;
  final double? vibrationLevel;

  VibrationLocationData({
    required this.entityId,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.jobSiteId,
    this.toolId,
    this.vibrationLevel,
  });

  factory VibrationLocationData.fromMap(Map<String, dynamic> map) {
    return VibrationLocationData(
      entityId: map['entityId'] ?? '',
      latitude: (map['latitude'] ?? 0.0).toDouble(),
      longitude: (map['longitude'] ?? 0.0).toDouble(),
      timestamp: (map['timestamp'] as firestore.Timestamp).toDate(),
      jobSiteId: map['jobSiteId'],
      toolId: map['metadata']?['toolId'],
      vibrationLevel: map['exposureLevel']?.toDouble(),
    );
  }
}

/// Vibration hotspot model
class VibrationHotSpot {
  final String id;
  final String jobSiteId;
  final double latitude;
  final double longitude;
  final double vibrationLevel;
  final double exposureTime;
  final int sessionCount;
  final List<String> toolsUsed;
  final RiskLevel riskLevel;
  final DateTime firstDetected;
  final DateTime lastUpdated;
  final bool isActive;
  final String severity;
  final List<String> recommendations;

  VibrationHotSpot({
    required this.id,
    required this.jobSiteId,
    required this.latitude,
    required this.longitude,
    required this.vibrationLevel,
    required this.exposureTime,
    required this.sessionCount,
    required this.toolsUsed,
    required this.riskLevel,
    required this.firstDetected,
    required this.lastUpdated,
    required this.isActive,
    required this.severity,
    required this.recommendations,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'jobSiteId': jobSiteId,
      'latitude': latitude,
      'longitude': longitude,
      'vibrationLevel': vibrationLevel,
      'exposureTime': exposureTime,
      'sessionCount': sessionCount,
      'toolsUsed': toolsUsed,
      'riskLevel': riskLevel.name,
      'firstDetected': firestore.Timestamp.fromDate(firstDetected),
      'lastUpdated': firestore.Timestamp.fromDate(lastUpdated),
      'isActive': isActive,
      'severity': severity,
      'recommendations': recommendations,
    };
  }
}

/// Vibration trend data
class VibrationTrend {
  final DateTime timestamp;
  final double averageVibration;
  final double maxVibration;
  final double totalExposureTime;
  final int hotSpotCount;

  VibrationTrend({
    required this.timestamp,
    required this.averageVibration,
    required this.maxVibration,
    required this.totalExposureTime,
    required this.hotSpotCount,
  });
}

/// Exposure risk zone
class ExposureRiskZone {
  final String id;
  final String? jobSiteId;
  final RiskLevel riskLevel;
  final double centerLatitude;
  final double centerLongitude;
  final List<firestore.GeoPoint> boundaryPoints;
  final double averageVibration;
  final double maxVibration;
  final int pointCount;
  final List<String> recommendedPPE;
  final List<String> restrictions;
  final DateTime createdAt;

  ExposureRiskZone({
    required this.id,
    this.jobSiteId,
    required this.riskLevel,
    required this.centerLatitude,
    required this.centerLongitude,
    required this.boundaryPoints,
    required this.averageVibration,
    required this.maxVibration,
    required this.pointCount,
    required this.recommendedPPE,
    required this.restrictions,
    required this.createdAt,
  });
}

/// Heat map overlay for visualization
class HeatMapOverlay {
  final String? jobSiteId;
  final List<HeatMapOverlayPoint> points;
  final Map<double, String> colorGradient;
  final double maxIntensity;
  final DateTime generatedAt;

  HeatMapOverlay({
    this.jobSiteId,
    required this.points,
    required this.colorGradient,
    required this.maxIntensity,
    required this.generatedAt,
  });
}

/// Heat map overlay point
class HeatMapOverlayPoint {
  final double latitude;
  final double longitude;
  final double intensity;
  final int radius;
  final String color;
  final Map<String, dynamic> metadata;

  HeatMapOverlayPoint({
    required this.latitude,
    required this.longitude,
    required this.intensity,
    required this.radius,
    required this.color,
    required this.metadata,
  });
}

/// Vibration area statistics
class VibrationAreaStatistics {
  final double centerLatitude;
  final double centerLongitude;
  final double radiusMeters;
  final int totalDataPoints;
  final double averageVibration;
  final double maxVibration;
  final double minVibration;
  final double totalExposureTime;
  final List<String> uniqueTools;
  final RiskLevel riskLevel;

  VibrationAreaStatistics({
    required this.centerLatitude,
    required this.centerLongitude,
    required this.radiusMeters,
    required this.totalDataPoints,
    required this.averageVibration,
    required this.maxVibration,
    required this.minVibration,
    required this.totalExposureTime,
    required this.uniqueTools,
    required this.riskLevel,
  });
}

/// Risk levels
enum RiskLevel {
  low,
  medium,
  high,
  critical;
}