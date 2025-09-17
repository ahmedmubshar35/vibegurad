import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/base_model.dart';

/// Tool location tracking data
class ToolLocationData extends BaseModel {
  final String toolId;
  final String toolName;
  final double latitude;
  final double longitude;
  final double? altitude;
  final double accuracy;
  final double? speed;
  final double? heading;
  final DateTime timestamp;
  final String? address;
  final String? jobSiteId;
  final String? workerId; // Who is currently using the tool
  final LocationSource source;
  final Map<String, dynamic>? metadata;

  ToolLocationData({
    super.id,
    required this.toolId,
    required this.toolName,
    required this.latitude,
    required this.longitude,
    this.altitude,
    required this.accuracy,
    this.speed,
    this.heading,
    required this.timestamp,
    this.address,
    this.jobSiteId,
    this.workerId,
    required this.source,
    this.metadata,
    super.createdAt,
    super.updatedAt,
    super.isActive = true,
  });

  @override
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'toolId': toolId,
      'toolName': toolName,
      'latitude': latitude,
      'longitude': longitude,
      'altitude': altitude,
      'accuracy': accuracy,
      'speed': speed,
      'heading': heading,
      'timestamp': Timestamp.fromDate(timestamp),
      'address': address,
      'jobSiteId': jobSiteId,
      'workerId': workerId,
      'isActive': super.isActive,
      'source': source.name,
      'metadata': metadata,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
    };
  }

  factory ToolLocationData.fromFirestore(Map<String, dynamic> data, String id) {
    return ToolLocationData(
      id: id,
      toolId: data['toolId'] ?? '',
      toolName: data['toolName'] ?? '',
      latitude: (data['latitude'] ?? 0.0).toDouble(),
      longitude: (data['longitude'] ?? 0.0).toDouble(),
      altitude: data['altitude']?.toDouble(),
      accuracy: (data['accuracy'] ?? 0.0).toDouble(),
      speed: data['speed']?.toDouble(),
      heading: data['heading']?.toDouble(),
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      address: data['address'],
      jobSiteId: data['jobSiteId'],
      workerId: data['workerId'],
      source: LocationSource.fromString(data['source'] ?? 'gps'),
      metadata: data['metadata'] as Map<String, dynamic>?,
      createdAt: data['createdAt'] != null 
          ? (data['createdAt'] as Timestamp).toDate() 
          : null,
      updatedAt: data['updatedAt'] != null 
          ? (data['updatedAt'] as Timestamp).toDate() 
          : null,
    );
  }

  @override
  ToolLocationData copyWith({
    String? id,
    String? toolId,
    String? toolName,
    double? latitude,
    double? longitude,
    double? altitude,
    double? accuracy,
    double? speed,
    double? heading,
    DateTime? timestamp,
    String? address,
    String? jobSiteId,
    String? workerId,
    LocationSource? source,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
  }) {
    return ToolLocationData(
      id: id ?? this.id,
      toolId: toolId ?? this.toolId,
      toolName: toolName ?? this.toolName,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      altitude: altitude ?? this.altitude,
      accuracy: accuracy ?? this.accuracy,
      speed: speed ?? this.speed,
      heading: heading ?? this.heading,
      timestamp: timestamp ?? this.timestamp,
      address: address ?? this.address,
      jobSiteId: jobSiteId ?? this.jobSiteId,
      workerId: workerId ?? this.workerId,
      source: source ?? this.source,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
    );
  }
}

/// Worker location during tool use
class WorkerLocationData extends BaseModel {
  final String workerId;
  final String workerName;
  final double latitude;
  final double longitude;
  final double? altitude;
  final double accuracy;
  final DateTime timestamp;
  final String? address;
  final String? jobSiteId;
  final String? currentToolId;
  final String? sessionId;
  final bool isWorking;
  final LocationSource source;
  final Map<String, dynamic>? metadata;

  WorkerLocationData({
    super.id,
    required this.workerId,
    required this.workerName,
    required this.latitude,
    required this.longitude,
    this.altitude,
    required this.accuracy,
    required this.timestamp,
    this.address,
    this.jobSiteId,
    this.currentToolId,
    this.sessionId,
    required this.isWorking,
    required this.source,
    this.metadata,
    super.createdAt,
    super.updatedAt,
    super.isActive = true,
  });

  @override
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'workerId': workerId,
      'workerName': workerName,
      'latitude': latitude,
      'longitude': longitude,
      'altitude': altitude,
      'accuracy': accuracy,
      'timestamp': Timestamp.fromDate(timestamp),
      'address': address,
      'jobSiteId': jobSiteId,
      'currentToolId': currentToolId,
      'sessionId': sessionId,
      'isWorking': isWorking,
      'source': source.name,
      'metadata': metadata,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
      'isActive': super.isActive,
    };
  }

  factory WorkerLocationData.fromFirestore(Map<String, dynamic> data, String id) {
    return WorkerLocationData(
      id: id,
      workerId: data['workerId'] ?? '',
      workerName: data['workerName'] ?? '',
      latitude: (data['latitude'] ?? 0.0).toDouble(),
      longitude: (data['longitude'] ?? 0.0).toDouble(),
      altitude: data['altitude']?.toDouble(),
      accuracy: (data['accuracy'] ?? 0.0).toDouble(),
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      address: data['address'],
      jobSiteId: data['jobSiteId'],
      currentToolId: data['currentToolId'],
      sessionId: data['sessionId'],
      isWorking: data['isWorking'] ?? false,
      source: LocationSource.fromString(data['source'] ?? 'gps'),
      metadata: data['metadata'] as Map<String, dynamic>?,
      createdAt: data['createdAt'] != null 
          ? (data['createdAt'] as Timestamp).toDate() 
          : null,
      updatedAt: data['updatedAt'] != null 
          ? (data['updatedAt'] as Timestamp).toDate() 
          : null,
    );
  }

  @override
  WorkerLocationData copyWith({
    String? id,
    String? workerId,
    String? workerName,
    double? latitude,
    double? longitude,
    double? altitude,
    double? accuracy,
    DateTime? timestamp,
    String? address,
    String? jobSiteId,
    String? currentToolId,
    String? sessionId,
    bool? isWorking,
    LocationSource? source,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
  }) {
    return WorkerLocationData(
      id: id ?? this.id,
      workerId: workerId ?? this.workerId,
      workerName: workerName ?? this.workerName,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      altitude: altitude ?? this.altitude,
      accuracy: accuracy ?? this.accuracy,
      timestamp: timestamp ?? this.timestamp,
      address: address ?? this.address,
      jobSiteId: jobSiteId ?? this.jobSiteId,
      currentToolId: currentToolId ?? this.currentToolId,
      sessionId: sessionId ?? this.sessionId,
      isWorking: isWorking ?? this.isWorking,
      source: source ?? this.source,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
    );
  }
}

/// Job site geofence definition
class JobSite extends BaseModel {
  final String name;
  final String description;
  final String companyId;
  final String address;
  final double centerLatitude;
  final double centerLongitude;
  final List<GeoPoint> boundaryPoints; // For polygon geofences
  final double? radius; // For circular geofences
  final GeofenceType type;
  final Map<String, double>? exposureLimits; // Tool-specific limits
  final List<String> authorizedWorkers;
  final List<String> authorizedTools;
  final Map<String, dynamic> settings;
  final bool alertsEnabled;
  final DateTime validFrom;
  final DateTime? validUntil;

  JobSite({
    super.id,
    required this.name,
    required this.description,
    required this.companyId,
    required this.address,
    required this.centerLatitude,
    required this.centerLongitude,
    required this.boundaryPoints,
    this.radius,
    required this.type,
    this.exposureLimits,
    required this.authorizedWorkers,
    required this.authorizedTools,
    required this.settings,
    required this.alertsEnabled,
    required this.validFrom,
    this.validUntil,
    super.createdAt,
    super.updatedAt,
    super.isActive = true,
  });

  @override
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'description': description,
      'companyId': companyId,
      'address': address,
      'centerLatitude': centerLatitude,
      'centerLongitude': centerLongitude,
      'boundaryPoints': boundaryPoints.map((p) => {
        'latitude': p.latitude,
        'longitude': p.longitude,
      }).toList(),
      'radius': radius,
      'type': type.name,
      'exposureLimits': exposureLimits,
      'authorizedWorkers': authorizedWorkers,
      'authorizedTools': authorizedTools,
      'settings': settings,
      'alertsEnabled': alertsEnabled,
      'validFrom': Timestamp.fromDate(validFrom),
      'validUntil': validUntil != null ? Timestamp.fromDate(validUntil!) : null,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
      'isActive': super.isActive,
    };
  }

  factory JobSite.fromFirestore(Map<String, dynamic> data, String id) {
    return JobSite(
      id: id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      companyId: data['companyId'] ?? '',
      address: data['address'] ?? '',
      centerLatitude: (data['centerLatitude'] ?? 0.0).toDouble(),
      centerLongitude: (data['centerLongitude'] ?? 0.0).toDouble(),
      boundaryPoints: (data['boundaryPoints'] as List<dynamic>? ?? [])
          .map((p) => GeoPoint(p['latitude'], p['longitude']))
          .toList(),
      radius: data['radius']?.toDouble(),
      type: GeofenceType.fromString(data['type'] ?? 'circle'),
      exposureLimits: (data['exposureLimits'] as Map<String, dynamic>?)
          ?.map((k, v) => MapEntry(k, v.toDouble())),
      authorizedWorkers: List<String>.from(data['authorizedWorkers'] ?? []),
      authorizedTools: List<String>.from(data['authorizedTools'] ?? []),
      settings: data['settings'] as Map<String, dynamic>? ?? {},
      alertsEnabled: data['alertsEnabled'] ?? true,
      validFrom: (data['validFrom'] as Timestamp).toDate(),
      validUntil: data['validUntil'] != null 
          ? (data['validUntil'] as Timestamp).toDate() 
          : null,
      createdAt: data['createdAt'] != null 
          ? (data['createdAt'] as Timestamp).toDate() 
          : null,
      updatedAt: data['updatedAt'] != null 
          ? (data['updatedAt'] as Timestamp).toDate() 
          : null,
    );
  }

  /// Check if a point is within this geofence
  bool containsPoint(double latitude, double longitude) {
    switch (type) {
      case GeofenceType.circle:
        if (radius == null) return false;
        return _distanceBetween(centerLatitude, centerLongitude, latitude, longitude) <= radius!;
      case GeofenceType.polygon:
        return _isPointInPolygon(latitude, longitude, boundaryPoints);
    }
  }

  double _distanceBetween(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000; // meters
    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLon = _degreesToRadians(lon2 - lon1);
    final double a = 
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) * math.cos(_degreesToRadians(lat2)) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * (math.pi / 180);
  }

  bool _isPointInPolygon(double lat, double lon, List<GeoPoint> polygon) {
    bool inside = false;
    int j = polygon.length - 1;
    
    for (int i = 0; i < polygon.length; i++) {
      final xi = polygon[i].latitude;
      final yi = polygon[i].longitude;
      final xj = polygon[j].latitude;
      final yj = polygon[j].longitude;
      
      if (((yi > lon) != (yj > lon)) &&
          (lat < (xj - xi) * (lon - yi) / (yj - yi) + xi)) {
        inside = !inside;
      }
      j = i;
    }
    
    return inside;
  }

  @override
  JobSite copyWith({
    String? id,
    String? name,
    String? description,
    String? companyId,
    String? address,
    double? centerLatitude,
    double? centerLongitude,
    List<GeoPoint>? boundaryPoints,
    double? radius,
    GeofenceType? type,
    Map<String, double>? exposureLimits,
    List<String>? authorizedWorkers,
    List<String>? authorizedTools,
    Map<String, dynamic>? settings,
    bool? alertsEnabled,
    DateTime? validFrom,
    DateTime? validUntil,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
  }) {
    return JobSite(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      companyId: companyId ?? this.companyId,
      address: address ?? this.address,
      centerLatitude: centerLatitude ?? this.centerLatitude,
      centerLongitude: centerLongitude ?? this.centerLongitude,
      boundaryPoints: boundaryPoints ?? this.boundaryPoints,
      radius: radius ?? this.radius,
      type: type ?? this.type,
      exposureLimits: exposureLimits ?? this.exposureLimits,
      authorizedWorkers: authorizedWorkers ?? this.authorizedWorkers,
      authorizedTools: authorizedTools ?? this.authorizedTools,
      settings: settings ?? this.settings,
      alertsEnabled: alertsEnabled ?? this.alertsEnabled,
      validFrom: validFrom ?? this.validFrom,
      validUntil: validUntil ?? this.validUntil,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
    );
  }
}

/// Location history entry
class LocationHistoryEntry {
  final String entityId; // Tool or worker ID
  final String entityType; // 'tool' or 'worker'
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final String? address;
  final String? jobSiteId;
  final double? exposureLevel; // If applicable
  final Map<String, dynamic>? metadata;

  LocationHistoryEntry({
    required this.entityId,
    required this.entityType,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.address,
    this.jobSiteId,
    this.exposureLevel,
    this.metadata,
  });

  Map<String, dynamic> toMap() {
    return {
      'entityId': entityId,
      'entityType': entityType,
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': Timestamp.fromDate(timestamp),
      'address': address,
      'jobSiteId': jobSiteId,
      'exposureLevel': exposureLevel,
      'metadata': metadata,
    };
  }

  factory LocationHistoryEntry.fromMap(Map<String, dynamic> map) {
    return LocationHistoryEntry(
      entityId: map['entityId'] ?? '',
      entityType: map['entityType'] ?? '',
      latitude: (map['latitude'] ?? 0.0).toDouble(),
      longitude: (map['longitude'] ?? 0.0).toDouble(),
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      address: map['address'],
      jobSiteId: map['jobSiteId'],
      exposureLevel: map['exposureLevel']?.toDouble(),
      metadata: map['metadata'] as Map<String, dynamic>?,
    );
  }
}

/// Heat map data point for high-vibration areas
class VibrationHeatMapPoint {
  final double latitude;
  final double longitude;
  final double vibrationLevel;
  final double exposureTime; // minutes
  final int sessionCount;
  final DateTime lastUpdated;
  final List<String> toolsUsed;

  VibrationHeatMapPoint({
    required this.latitude,
    required this.longitude,
    required this.vibrationLevel,
    required this.exposureTime,
    required this.sessionCount,
    required this.lastUpdated,
    required this.toolsUsed,
  });

  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'vibrationLevel': vibrationLevel,
      'exposureTime': exposureTime,
      'sessionCount': sessionCount,
      'lastUpdated': Timestamp.fromDate(lastUpdated),
      'toolsUsed': toolsUsed,
    };
  }

  factory VibrationHeatMapPoint.fromMap(Map<String, dynamic> map) {
    return VibrationHeatMapPoint(
      latitude: (map['latitude'] ?? 0.0).toDouble(),
      longitude: (map['longitude'] ?? 0.0).toDouble(),
      vibrationLevel: (map['vibrationLevel'] ?? 0.0).toDouble(),
      exposureTime: (map['exposureTime'] ?? 0.0).toDouble(),
      sessionCount: map['sessionCount'] ?? 0,
      lastUpdated: (map['lastUpdated'] as Timestamp).toDate(),
      toolsUsed: List<String>.from(map['toolsUsed'] ?? []),
    );
  }
}

/// Indoor positioning system beacon
class IndoorBeacon {
  final String beaconId;
  final String name;
  final String jobSiteId;
  final double latitude;
  final double longitude;
  final double? floor;
  final String? building;
  final String? room;
  final BeaconType type;
  final Map<String, dynamic> config;
  final bool isActive;

  IndoorBeacon({
    required this.beaconId,
    required this.name,
    required this.jobSiteId,
    required this.latitude,
    required this.longitude,
    this.floor,
    this.building,
    this.room,
    required this.type,
    required this.config,
    required this.isActive,
  });

  Map<String, dynamic> toMap() {
    return {
      'beaconId': beaconId,
      'name': name,
      'jobSiteId': jobSiteId,
      'latitude': latitude,
      'longitude': longitude,
      'floor': floor,
      'building': building,
      'room': room,
      'type': type.name,
      'config': config,
      'isActive': isActive,
    };
  }

  factory IndoorBeacon.fromMap(Map<String, dynamic> map) {
    return IndoorBeacon(
      beaconId: map['beaconId'] ?? '',
      name: map['name'] ?? '',
      jobSiteId: map['jobSiteId'] ?? '',
      latitude: (map['latitude'] ?? 0.0).toDouble(),
      longitude: (map['longitude'] ?? 0.0).toDouble(),
      floor: map['floor']?.toDouble(),
      building: map['building'],
      room: map['room'],
      type: BeaconType.fromString(map['type'] ?? 'bluetooth'),
      config: map['config'] as Map<String, dynamic>? ?? {},
      isActive: map['isActive'] ?? true,
    );
  }
}

/// Tool proximity alert
class ToolProximityAlert {
  final String alertId;
  final String toolId;
  final String workerId;
  final String alertType; // 'entering', 'exiting', 'too_close'
  final double distance;
  final DateTime triggeredAt;
  final String? message;
  final String severity; // 'info', 'warning', 'critical'
  final bool acknowledged;

  ToolProximityAlert({
    required this.alertId,
    required this.toolId,
    required this.workerId,
    required this.alertType,
    required this.distance,
    required this.triggeredAt,
    this.message,
    required this.severity,
    required this.acknowledged,
  });

  Map<String, dynamic> toMap() {
    return {
      'alertId': alertId,
      'toolId': toolId,
      'workerId': workerId,
      'alertType': alertType,
      'distance': distance,
      'triggeredAt': Timestamp.fromDate(triggeredAt),
      'message': message,
      'severity': severity,
      'acknowledged': acknowledged,
    };
  }

  factory ToolProximityAlert.fromMap(Map<String, dynamic> map) {
    return ToolProximityAlert(
      alertId: map['alertId'] ?? '',
      toolId: map['toolId'] ?? '',
      workerId: map['workerId'] ?? '',
      alertType: map['alertType'] ?? '',
      distance: (map['distance'] ?? 0.0).toDouble(),
      triggeredAt: (map['triggeredAt'] as Timestamp).toDate(),
      message: map['message'],
      severity: map['severity'] ?? 'info',
      acknowledged: map['acknowledged'] ?? false,
    );
  }
}

/// Enumerations
enum LocationSource {
  gps,
  network,
  bluetooth,
  wifi,
  uwb,
  manual;

  static LocationSource fromString(String value) {
    return LocationSource.values.firstWhere(
      (source) => source.name == value.toLowerCase(),
      orElse: () => LocationSource.gps,
    );
  }
}

enum GeofenceType {
  circle,
  polygon;

  static GeofenceType fromString(String value) {
    return GeofenceType.values.firstWhere(
      (type) => type.name == value.toLowerCase(),
      orElse: () => GeofenceType.circle,
    );
  }
}

enum BeaconType {
  bluetooth,
  wifi,
  uwb,
  nfc;

  static BeaconType fromString(String value) {
    return BeaconType.values.firstWhere(
      (type) => type.name == value.toLowerCase(),
      orElse: () => BeaconType.bluetooth,
    );
  }
}

/// Geographic point helper class
class GeoPoint {
  final double latitude;
  final double longitude;

  GeoPoint(this.latitude, this.longitude);

  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  factory GeoPoint.fromMap(Map<String, dynamic> map) {
    return GeoPoint(
      (map['latitude'] ?? 0.0).toDouble(),
      (map['longitude'] ?? 0.0).toDouble(),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GeoPoint &&
        other.latitude == latitude &&
        other.longitude == longitude;
  }

  @override
  int get hashCode => latitude.hashCode ^ longitude.hashCode;

  @override
  String toString() => 'GeoPoint($latitude, $longitude)';
}