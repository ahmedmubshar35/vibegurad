import 'dart:async';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/location/location_models.dart';

/// Service for indoor positioning using beacons and other technologies
class IndoorPositioningService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  static const String _beaconsCollection = 'indoor_beacons';
  static const String _indoorLocationsCollection = 'indoor_locations';
  static const String _calibrationDataCollection = 'indoor_calibration';

  final StreamController<IndoorLocationUpdate> _locationUpdateController = 
      StreamController<IndoorLocationUpdate>.broadcast();
  final StreamController<List<IndoorBeacon>> _beaconUpdateController = 
      StreamController<List<IndoorBeacon>>.broadcast();

  // Cache for active beacons
  final Map<String, IndoorBeacon> _beaconCache = {};
  
  // Active positioning sessions
  final Map<String, IndoorPositioningSession> _activeSessions = {};

  /// Stream of indoor location updates
  Stream<IndoorLocationUpdate> get locationUpdateStream => _locationUpdateController.stream;
  
  /// Stream of beacon updates
  Stream<List<IndoorBeacon>> get beaconUpdateStream => _beaconUpdateController.stream;

  /// Initialize indoor positioning service
  Future<void> initialize() async {
    await _loadActiveBeacons();
    _startRealtimeBeaconUpdates();
  }

  /// Load active beacons into cache
  Future<void> _loadActiveBeacons() async {
    final snapshot = await _firestore
        .collection(_beaconsCollection)
        .where('isActive', isEqualTo: true)
        .get();

    _beaconCache.clear();
    for (final doc in snapshot.docs) {
      final beacon = IndoorBeacon.fromMap(doc.data());
      _beaconCache[beacon.beaconId] = beacon;
    }
  }

  /// Start real-time beacon updates
  void _startRealtimeBeaconUpdates() {
    _firestore
        .collection(_beaconsCollection)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .listen((snapshot) {
      for (final change in snapshot.docChanges) {
        final beacon = IndoorBeacon.fromMap(change.doc.data()!);
        
        switch (change.type) {
          case DocumentChangeType.added:
          case DocumentChangeType.modified:
            _beaconCache[beacon.beaconId] = beacon;
            break;
          case DocumentChangeType.removed:
            _beaconCache.remove(beacon.beaconId);
            break;
        }
      }
      
      _beaconUpdateController.add(_beaconCache.values.toList());
    });
  }

  /// Register a new indoor beacon
  Future<String> registerBeacon({
    required String beaconId,
    required String name,
    required String jobSiteId,
    required double latitude,
    required double longitude,
    double? floor,
    String? building,
    String? room,
    BeaconType type = BeaconType.bluetooth,
    Map<String, dynamic> config = const {},
  }) async {
    final beacon = IndoorBeacon(
      beaconId: beaconId,
      name: name,
      jobSiteId: jobSiteId,
      latitude: latitude,
      longitude: longitude,
      floor: floor,
      building: building,
      room: room,
      type: type,
      config: config,
      isActive: true,
    );

    await _firestore
        .collection(_beaconsCollection)
        .doc(beaconId)
        .set(beacon.toMap());

    _beaconCache[beaconId] = beacon;
    
    return beaconId;
  }

  /// Update beacon configuration
  Future<void> updateBeacon(String beaconId, Map<String, dynamic> updates) async {
    await _firestore
        .collection(_beaconsCollection)
        .doc(beaconId)
        .update(updates);
  }

  /// Start indoor positioning session
  Future<void> startPositioning({
    required String entityId,
    required String entityType,
    required String jobSiteId,
    Duration updateInterval = const Duration(seconds: 5),
  }) async {
    final session = IndoorPositioningSession(
      entityId: entityId,
      entityType: entityType,
      jobSiteId: jobSiteId,
      startTime: DateTime.now(),
      updateInterval: updateInterval,
      isActive: true,
    );

    _activeSessions[entityId] = session;

    // Start periodic positioning updates (simulated for now)
    session.timer = Timer.periodic(updateInterval, (_) async {
      await _updateIndoorPosition(entityId);
    });
  }

  /// Stop indoor positioning session
  Future<void> stopPositioning(String entityId) async {
    final session = _activeSessions[entityId];
    if (session != null) {
      session.timer?.cancel();
      session.isActive = false;
      _activeSessions.remove(entityId);
    }
  }

  /// Process beacon signal data to determine position
  Future<IndoorLocation?> processBeaconSignals({
    required String entityId,
    required List<BeaconSignal> signals,
  }) async {
    if (signals.length < 3) {
      // Need at least 3 beacons for trilateration
      return null;
    }

    // Get beacon information
    final beaconPositions = <BeaconPosition>[];
    for (final signal in signals) {
      final beacon = _beaconCache[signal.beaconId];
      if (beacon != null) {
        beaconPositions.add(BeaconPosition(
          beaconId: signal.beaconId,
          latitude: beacon.latitude,
          longitude: beacon.longitude,
          distance: _calculateDistanceFromRSSI(signal.rssi, beacon.type),
        ));
      }
    }

    if (beaconPositions.length < 3) return null;

    // Calculate position using trilateration
    final position = _trilaterate(beaconPositions);
    if (position == null) return null;

    // Determine floor and building from strongest beacon
    final strongestBeacon = signals.reduce((a, b) => a.rssi > b.rssi ? a : b);
    final beacon = _beaconCache[strongestBeacon.beaconId];

    final indoorLocation = IndoorLocation(
      entityId: entityId,
      latitude: position.latitude,
      longitude: position.longitude,
      floor: beacon?.floor,
      building: beacon?.building,
      room: beacon?.room,
      jobSiteId: beacon?.jobSiteId ?? '',
      accuracy: _calculateAccuracy(beaconPositions),
      timestamp: DateTime.now(),
      beaconsUsed: signals.map((s) => s.beaconId).toList(),
      positioningMethod: PositioningMethod.trilateration,
      metadata: {
        'signalCount': signals.length,
        'strongestBeaconId': strongestBeacon.beaconId,
        'strongestRSSI': strongestBeacon.rssi,
      },
    );

    // Save to database
    await _saveIndoorLocation(indoorLocation);

    // Emit location update
    _locationUpdateController.add(IndoorLocationUpdate(
      entityId: entityId,
      location: indoorLocation,
      updateType: IndoorUpdateType.positionUpdate,
      timestamp: DateTime.now(),
    ));

    return indoorLocation;
  }

  /// Process WiFi fingerprinting data
  Future<IndoorLocation?> processWiFiFingerprint({
    required String entityId,
    required List<WiFiSignal> wifiSignals,
  }) async {
    // Get calibration data for comparison
    final calibrationData = await _getCalibrationData(entityId);
    if (calibrationData.isEmpty) return null;

    // Find best match using signal strength comparison
    double bestMatch = double.infinity;
    CalibrationPoint? bestCalibrationPoint;

    for (final calibrationPoint in calibrationData) {
      final distance = _calculateWiFiDistance(wifiSignals, calibrationPoint.wifiSignatures);
      if (distance < bestMatch) {
        bestMatch = distance;
        bestCalibrationPoint = calibrationPoint;
      }
    }

    if (bestCalibrationPoint == null) return null;

    final indoorLocation = IndoorLocation(
      entityId: entityId,
      latitude: bestCalibrationPoint.latitude,
      longitude: bestCalibrationPoint.longitude,
      floor: bestCalibrationPoint.floor,
      building: bestCalibrationPoint.building,
      room: bestCalibrationPoint.room,
      jobSiteId: bestCalibrationPoint.jobSiteId,
      accuracy: bestMatch,
      timestamp: DateTime.now(),
      beaconsUsed: [],
      positioningMethod: PositioningMethod.wifiFingerprinting,
      metadata: {
        'matchDistance': bestMatch,
        'calibrationPointId': bestCalibrationPoint.id,
        'wifiSignalCount': wifiSignals.length,
      },
    );

    await _saveIndoorLocation(indoorLocation);

    _locationUpdateController.add(IndoorLocationUpdate(
      entityId: entityId,
      location: indoorLocation,
      updateType: IndoorUpdateType.positionUpdate,
      timestamp: DateTime.now(),
    ));

    return indoorLocation;
  }

  /// Add calibration point for WiFi fingerprinting
  Future<String> addCalibrationPoint({
    required String jobSiteId,
    required double latitude,
    required double longitude,
    double? floor,
    String? building,
    String? room,
    required List<WiFiSignal> wifiSignatures,
    required List<BeaconSignal> beaconSignatures,
    String? notes,
  }) async {
    final calibrationPoint = CalibrationPoint(
      id: _firestore.collection(_calibrationDataCollection).doc().id,
      jobSiteId: jobSiteId,
      latitude: latitude,
      longitude: longitude,
      floor: floor,
      building: building,
      room: room,
      wifiSignatures: wifiSignatures,
      beaconSignatures: beaconSignatures,
      notes: notes,
      timestamp: DateTime.now(),
    );

    await _firestore
        .collection(_calibrationDataCollection)
        .doc(calibrationPoint.id)
        .set(calibrationPoint.toMap());

    return calibrationPoint.id;
  }

  /// Get indoor location history
  Future<List<IndoorLocation>> getIndoorLocationHistory({
    required String entityId,
    DateTime? startTime,
    DateTime? endTime,
    int limit = 100,
  }) async {
    Query query = _firestore
        .collection(_indoorLocationsCollection)
        .where('entityId', isEqualTo: entityId)
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
        .map((doc) => IndoorLocation.fromMap(doc.data() as Map<String, dynamic>))
        .toList();
  }

  /// Get entities currently in a specific room/area
  Future<List<IndoorLocation>> getEntitiesInArea({
    required String jobSiteId,
    String? building,
    double? floor,
    String? room,
    Duration timeWindow = const Duration(minutes: 5),
  }) async {
    final cutoffTime = DateTime.now().subtract(timeWindow);
    
    Query query = _firestore
        .collection(_indoorLocationsCollection)
        .where('jobSiteId', isEqualTo: jobSiteId)
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(cutoffTime));

    if (building != null) {
      query = query.where('building', isEqualTo: building);
    }

    if (floor != null) {
      query = query.where('floor', isEqualTo: floor);
    }

    if (room != null) {
      query = query.where('room', isEqualTo: room);
    }

    final snapshot = await query.get();
    return snapshot.docs
        .map((doc) => IndoorLocation.fromMap(doc.data() as Map<String, dynamic>))
        .toList();
  }

  /// Calculate positioning accuracy metrics
  Future<PositioningAccuracyReport> calculateAccuracyReport({
    required String jobSiteId,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    final locations = await _firestore
        .collection(_indoorLocationsCollection)
        .where('jobSiteId', isEqualTo: jobSiteId)
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startTime))
        .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endTime))
        .get();

    final List<double> accuracies = [];
    final Map<PositioningMethod, int> methodCounts = {};

    for (final doc in locations.docs) {
      final location = IndoorLocation.fromMap(doc.data() as Map<String, dynamic>);
      accuracies.add(location.accuracy);
      methodCounts[location.positioningMethod] = 
          (methodCounts[location.positioningMethod] ?? 0) + 1;
    }

    final averageAccuracy = accuracies.isEmpty 
        ? 0.0 
        : accuracies.reduce((a, b) => a + b) / accuracies.length;

    final maxAccuracy = accuracies.isEmpty ? 0.0 : accuracies.reduce(math.max);
    final minAccuracy = accuracies.isEmpty ? 0.0 : accuracies.reduce(math.min);

    return PositioningAccuracyReport(
      jobSiteId: jobSiteId,
      reportPeriod: DateTimeRange(startTime, endTime),
      totalPositions: locations.docs.length,
      averageAccuracy: averageAccuracy,
      maxAccuracy: maxAccuracy,
      minAccuracy: minAccuracy,
      methodBreakdown: methodCounts,
      generatedAt: DateTime.now(),
    );
  }

  /// Private helper methods
  Future<void> _updateIndoorPosition(String entityId) async {
    // This would integrate with actual beacon/wifi scanning hardware
    // For now, simulate position updates
    final session = _activeSessions[entityId];
    if (session == null || !session.isActive) return;

    // Simulate beacon signals
    final simulatedSignals = _generateSimulatedBeaconSignals(entityId);
    if (simulatedSignals.isNotEmpty) {
      await processBeaconSignals(
        entityId: entityId,
        signals: simulatedSignals,
      );
    }
  }

  List<BeaconSignal> _generateSimulatedBeaconSignals(String entityId) {
    // Generate simulated beacon signals for testing
    final beacons = _beaconCache.values.toList();
    if (beacons.length < 3) return [];

    return beacons.take(3).map((beacon) => BeaconSignal(
      beaconId: beacon.beaconId,
      rssi: -50 - (math.Random().nextDouble() * 30), // Random RSSI between -50 and -80
      timestamp: DateTime.now(),
    )).toList();
  }

  double _calculateDistanceFromRSSI(double rssi, BeaconType beaconType) {
    // Simple distance calculation from RSSI
    // Real implementation would use beacon-specific calibration
    switch (beaconType) {
      case BeaconType.bluetooth:
        return math.pow(10, (-69 - rssi) / 20).toDouble(); // Simplified BLE formula
      case BeaconType.wifi:
        return math.pow(10, (-40 - rssi) / 20).toDouble();
      case BeaconType.uwb:
        return (rssi.abs() / 10.0); // UWB provides direct distance
      case BeaconType.nfc:
        return rssi > -30 ? 0.1 : 5.0; // NFC is very short range
    }
  }

  LatLng? _trilaterate(List<BeaconPosition> beacons) {
    // Simplified trilateration algorithm
    // Real implementation would use more sophisticated algorithms
    if (beacons.length < 3) return null;

    final b1 = beacons[0];
    final b2 = beacons[1];
    final b3 = beacons[2];

    // Convert to Cartesian coordinates (simplified)
    final x1 = b1.latitude * 111000; // Rough conversion to meters
    final y1 = b1.longitude * 111000;
    final r1 = b1.distance;

    final x2 = b2.latitude * 111000;
    final y2 = b2.longitude * 111000;
    final r2 = b2.distance;

    final x3 = b3.latitude * 111000;
    final y3 = b3.longitude * 111000;
    final r3 = b3.distance;

    // Trilateration calculation
    final A = 2 * (x2 - x1);
    final B = 2 * (y2 - y1);
    final C = math.pow(r1, 2) - math.pow(r2, 2) - math.pow(x1, 2) + math.pow(x2, 2) - math.pow(y1, 2) + math.pow(y2, 2);
    final D = 2 * (x3 - x2);
    final E = 2 * (y3 - y2);
    final F = math.pow(r2, 2) - math.pow(r3, 2) - math.pow(x2, 2) + math.pow(x3, 2) - math.pow(y2, 2) + math.pow(y3, 2);

    final denominator = A * E - B * D;
    if (denominator == 0) return null; // Points are collinear

    final x = (C * E - F * B) / denominator;
    final y = (A * F - D * C) / denominator;

    // Convert back to lat/lng
    return LatLng(x / 111000, y / 111000);
  }

  double _calculateAccuracy(List<BeaconPosition> beacons) {
    // Calculate estimated accuracy based on beacon distances and configuration
    final distances = beacons.map((b) => b.distance).toList();
    final avgDistance = distances.reduce((a, b) => a + b) / distances.length;
    return avgDistance * 0.3; // Rough accuracy estimate
  }

  double _calculateWiFiDistance(List<WiFiSignal> signals1, List<WiFiSignal> signals2) {
    // Calculate Euclidean distance between WiFi signal vectors
    double distance = 0.0;
    final signalMap1 = {for (var s in signals1) s.bssid: s.rssi};
    final signalMap2 = {for (var s in signals2) s.bssid: s.rssi};

    final allBssids = {...signalMap1.keys, ...signalMap2.keys};
    
    for (final bssid in allBssids) {
      final rssi1 = signalMap1[bssid] ?? -100; // Use very weak signal if missing
      final rssi2 = signalMap2[bssid] ?? -100;
      distance += math.pow(rssi1 - rssi2, 2).toDouble();
    }

    return math.sqrt(distance);
  }

  Future<List<CalibrationPoint>> _getCalibrationData(String entityId) async {
    // Get calibration data for WiFi fingerprinting
    // This would be filtered by job site or area
    final snapshot = await _firestore
        .collection(_calibrationDataCollection)
        .get();

    return snapshot.docs
        .map((doc) => CalibrationPoint.fromMap(doc.data() as Map<String, dynamic>))
        .toList();
  }

  Future<void> _saveIndoorLocation(IndoorLocation location) async {
    await _firestore
        .collection(_indoorLocationsCollection)
        .add(location.toMap());
  }

  /// Get active beacons in a job site
  List<IndoorBeacon> getBeaconsInJobSite(String jobSiteId) {
    return _beaconCache.values
        .where((beacon) => beacon.jobSiteId == jobSiteId && beacon.isActive)
        .toList();
  }

  /// Dispose resources
  void dispose() {
    // Stop all active sessions
    for (final session in _activeSessions.values) {
      session.timer?.cancel();
    }
    _activeSessions.clear();
    
    _locationUpdateController.close();
    _beaconUpdateController.close();
    _beaconCache.clear();
  }
}

/// Indoor positioning session
class IndoorPositioningSession {
  final String entityId;
  final String entityType;
  final String jobSiteId;
  final DateTime startTime;
  final Duration updateInterval;
  bool isActive;
  Timer? timer;

  IndoorPositioningSession({
    required this.entityId,
    required this.entityType,
    required this.jobSiteId,
    required this.startTime,
    required this.updateInterval,
    required this.isActive,
    this.timer,
  });
}

/// Indoor location data
class IndoorLocation {
  final String entityId;
  final double latitude;
  final double longitude;
  final double? floor;
  final String? building;
  final String? room;
  final String jobSiteId;
  final double accuracy;
  final DateTime timestamp;
  final List<String> beaconsUsed;
  final PositioningMethod positioningMethod;
  final Map<String, dynamic>? metadata;

  IndoorLocation({
    required this.entityId,
    required this.latitude,
    required this.longitude,
    this.floor,
    this.building,
    this.room,
    required this.jobSiteId,
    required this.accuracy,
    required this.timestamp,
    required this.beaconsUsed,
    required this.positioningMethod,
    this.metadata,
  });

  Map<String, dynamic> toMap() {
    return {
      'entityId': entityId,
      'latitude': latitude,
      'longitude': longitude,
      'floor': floor,
      'building': building,
      'room': room,
      'jobSiteId': jobSiteId,
      'accuracy': accuracy,
      'timestamp': Timestamp.fromDate(timestamp),
      'beaconsUsed': beaconsUsed,
      'positioningMethod': positioningMethod.name,
      'metadata': metadata,
    };
  }

  factory IndoorLocation.fromMap(Map<String, dynamic> map) {
    return IndoorLocation(
      entityId: map['entityId'] ?? '',
      latitude: (map['latitude'] ?? 0.0).toDouble(),
      longitude: (map['longitude'] ?? 0.0).toDouble(),
      floor: map['floor']?.toDouble(),
      building: map['building'],
      room: map['room'],
      jobSiteId: map['jobSiteId'] ?? '',
      accuracy: (map['accuracy'] ?? 0.0).toDouble(),
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      beaconsUsed: List<String>.from(map['beaconsUsed'] ?? []),
      positioningMethod: PositioningMethod.fromString(map['positioningMethod'] ?? 'trilateration'),
      metadata: map['metadata'] as Map<String, dynamic>?,
    );
  }
}

/// Beacon signal data
class BeaconSignal {
  final String beaconId;
  final double rssi;
  final DateTime timestamp;

  BeaconSignal({
    required this.beaconId,
    required this.rssi,
    required this.timestamp,
  });
}

/// WiFi signal data
class WiFiSignal {
  final String bssid;
  final String ssid;
  final double rssi;
  final int frequency;
  final DateTime timestamp;

  WiFiSignal({
    required this.bssid,
    required this.ssid,
    required this.rssi,
    required this.frequency,
    required this.timestamp,
  });
}

/// Beacon position for trilateration
class BeaconPosition {
  final String beaconId;
  final double latitude;
  final double longitude;
  final double distance;

  BeaconPosition({
    required this.beaconId,
    required this.latitude,
    required this.longitude,
    required this.distance,
  });
}

/// Calibration point for WiFi fingerprinting
class CalibrationPoint {
  final String id;
  final String jobSiteId;
  final double latitude;
  final double longitude;
  final double? floor;
  final String? building;
  final String? room;
  final List<WiFiSignal> wifiSignatures;
  final List<BeaconSignal> beaconSignatures;
  final String? notes;
  final DateTime timestamp;

  CalibrationPoint({
    required this.id,
    required this.jobSiteId,
    required this.latitude,
    required this.longitude,
    this.floor,
    this.building,
    this.room,
    required this.wifiSignatures,
    required this.beaconSignatures,
    this.notes,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'jobSiteId': jobSiteId,
      'latitude': latitude,
      'longitude': longitude,
      'floor': floor,
      'building': building,
      'room': room,
      'wifiSignatures': wifiSignatures.map((w) => {
        'bssid': w.bssid,
        'ssid': w.ssid,
        'rssi': w.rssi,
        'frequency': w.frequency,
      }).toList(),
      'beaconSignatures': beaconSignatures.map((b) => {
        'beaconId': b.beaconId,
        'rssi': b.rssi,
      }).toList(),
      'notes': notes,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  factory CalibrationPoint.fromMap(Map<String, dynamic> map) {
    return CalibrationPoint(
      id: map['id'] ?? '',
      jobSiteId: map['jobSiteId'] ?? '',
      latitude: (map['latitude'] ?? 0.0).toDouble(),
      longitude: (map['longitude'] ?? 0.0).toDouble(),
      floor: map['floor']?.toDouble(),
      building: map['building'],
      room: map['room'],
      wifiSignatures: (map['wifiSignatures'] as List<dynamic>? ?? [])
          .map((w) => WiFiSignal(
                bssid: w['bssid'] ?? '',
                ssid: w['ssid'] ?? '',
                rssi: (w['rssi'] ?? 0.0).toDouble(),
                frequency: w['frequency'] ?? 0,
                timestamp: DateTime.now(),
              ))
          .toList(),
      beaconSignatures: (map['beaconSignatures'] as List<dynamic>? ?? [])
          .map((b) => BeaconSignal(
                beaconId: b['beaconId'] ?? '',
                rssi: (b['rssi'] ?? 0.0).toDouble(),
                timestamp: DateTime.now(),
              ))
          .toList(),
      notes: map['notes'],
      timestamp: (map['timestamp'] as Timestamp).toDate(),
    );
  }
}

/// Indoor location update event
class IndoorLocationUpdate {
  final String entityId;
  final IndoorLocation location;
  final IndoorUpdateType updateType;
  final DateTime timestamp;

  IndoorLocationUpdate({
    required this.entityId,
    required this.location,
    required this.updateType,
    required this.timestamp,
  });
}

/// Positioning accuracy report
class PositioningAccuracyReport {
  final String jobSiteId;
  final DateTimeRange reportPeriod;
  final int totalPositions;
  final double averageAccuracy;
  final double maxAccuracy;
  final double minAccuracy;
  final Map<PositioningMethod, int> methodBreakdown;
  final DateTime generatedAt;

  PositioningAccuracyReport({
    required this.jobSiteId,
    required this.reportPeriod,
    required this.totalPositions,
    required this.averageAccuracy,
    required this.maxAccuracy,
    required this.minAccuracy,
    required this.methodBreakdown,
    required this.generatedAt,
  });
}

/// Simple LatLng class
class LatLng {
  final double latitude;
  final double longitude;

  LatLng(this.latitude, this.longitude);
}

/// Date time range helper
class DateTimeRange {
  final DateTime start;
  final DateTime end;

  DateTimeRange(this.start, this.end);
}

/// Positioning methods
enum PositioningMethod {
  trilateration,
  wifiFingerprinting,
  hybridApproach,
  uwbRanging;

  static PositioningMethod fromString(String value) {
    return PositioningMethod.values.firstWhere(
      (method) => method.name == value.toLowerCase(),
      orElse: () => PositioningMethod.trilateration,
    );
  }
}

/// Indoor update types
enum IndoorUpdateType {
  positionUpdate,
  beaconUpdate,
  calibrationUpdate,
}