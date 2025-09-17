import 'dart:async';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../../models/location/location_models.dart' hide GeoPoint;
import '../../models/location/location_models.dart' as models;

/// Service for managing geofences and job site boundaries
class GeofencingService {
  static const String _collection = 'job_sites';
  static const String _geofenceEventsCollection = 'geofence_events';
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final StreamController<GeofenceEvent> _geofenceEventController = 
      StreamController<GeofenceEvent>.broadcast();
  
  // Cache for active job sites
  final Map<String, JobSite> _jobSiteCache = {};
  
  // Currently monitored entities
  final Map<String, GeofenceMonitoringSession> _monitoringSessions = {};
  
  GeofencingService();

  /// Stream of geofence events
  Stream<GeofenceEvent> get geofenceEventStream => _geofenceEventController.stream;

  /// Initialize geofencing service
  Future<void> initialize() async {
    await _loadActiveJobSites();
    _startRealtimeJobSiteUpdates();
  }

  /// Load all active job sites into cache
  Future<void> _loadActiveJobSites() async {
    final snapshot = await _firestore
        .collection(_collection)
        .where('isActive', isEqualTo: true)
        .get();

    _jobSiteCache.clear();
    for (final doc in snapshot.docs) {
      final jobSite = JobSite.fromFirestore(doc.data(), doc.id);
      _jobSiteCache[jobSite.id!] = jobSite;
    }
  }

  /// Start real-time job site updates
  void _startRealtimeJobSiteUpdates() {
    _firestore
        .collection(_collection)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .listen((snapshot) {
      for (final change in snapshot.docChanges) {
        final jobSite = JobSite.fromFirestore(change.doc.data()!, change.doc.id);
        
        switch (change.type) {
          case DocumentChangeType.added:
          case DocumentChangeType.modified:
            _jobSiteCache[jobSite.id!] = jobSite;
            break;
          case DocumentChangeType.removed:
            _jobSiteCache.remove(jobSite.id!);
            break;
        }
      }
    });
  }

  /// Create a new job site with geofencing
  Future<String> createJobSite({
    required String name,
    required String description,
    required String companyId,
    required String address,
    required double centerLatitude,
    required double centerLongitude,
    List<GeoPoint>? boundaryPoints,
    double? radius,
    GeofenceType type = GeofenceType.circle,
    Map<String, double>? exposureLimits,
    List<String> authorizedWorkers = const [],
    List<String> authorizedTools = const [],
    Map<String, dynamic> settings = const {},
    bool alertsEnabled = true,
    DateTime? validFrom,
    DateTime? validUntil,
  }) async {
    final jobSite = JobSite(
      name: name,
      description: description,
      companyId: companyId,
      address: address,
      centerLatitude: centerLatitude,
      centerLongitude: centerLongitude,
      boundaryPoints: boundaryPoints?.map((p) => models.GeoPoint(p.latitude, p.longitude)).toList() ?? [],
      radius: radius,
      type: type,
      exposureLimits: exposureLimits,
      authorizedWorkers: authorizedWorkers,
      authorizedTools: authorizedTools,
      settings: settings,
      alertsEnabled: alertsEnabled,
      validFrom: validFrom ?? DateTime.now(),
      validUntil: validUntil,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final docRef = await _firestore.collection(_collection).add(jobSite.toJson());
    final id = docRef.id;
    _jobSiteCache[id] = jobSite.copyWith(id: id);
    
    return id;
  }

  /// Update job site geofence
  Future<void> updateJobSite(String jobSiteId, JobSite updatedJobSite) async {
    await _firestore.collection(_collection).doc(jobSiteId).update(updatedJobSite.toJson());
    _jobSiteCache[jobSiteId] = updatedJobSite;
  }

  /// Check if a location is within any job site
  Future<List<JobSite>> getJobSitesContainingLocation(
    double latitude, 
    double longitude,
  ) async {
    final containingJobSites = <JobSite>[];
    
    for (final jobSite in _jobSiteCache.values) {
      if (_isValidJobSite(jobSite) && jobSite.containsPoint(latitude, longitude)) {
        containingJobSites.add(jobSite);
      }
    }
    
    return containingJobSites;
  }

  /// Start monitoring an entity (tool or worker) for geofence events
  Future<void> startMonitoring({
    required String entityId,
    required String entityType, // 'tool' or 'worker'
    required String entityName,
    List<String>? specificJobSiteIds,
  }) async {
    final session = GeofenceMonitoringSession(
      entityId: entityId,
      entityType: entityType,
      entityName: entityName,
      startedAt: DateTime.now(),
      specificJobSiteIds: specificJobSiteIds,
    );
    
    _monitoringSessions[entityId] = session;
  }

  /// Stop monitoring an entity
  void stopMonitoring(String entityId) {
    _monitoringSessions.remove(entityId);
  }

  /// Process location update and check for geofence events
  Future<void> processLocationUpdate({
    required String entityId,
    required String entityType,
    required double latitude,
    required double longitude,
    DateTime? timestamp,
  }) async {
    final session = _monitoringSessions[entityId];
    if (session == null) return;

    final currentTime = timestamp ?? DateTime.now();
    final currentJobSites = await getJobSitesContainingLocation(latitude, longitude);
    final previousJobSites = session.currentJobSites;

    // Check for entry events
    for (final jobSite in currentJobSites) {
      if (!previousJobSites.contains(jobSite.id)) {
        await _triggerGeofenceEvent(
          entityId: entityId,
          entityType: entityType,
          jobSiteId: jobSite.id!,
          eventType: GeofenceEventType.enter,
          latitude: latitude,
          longitude: longitude,
          timestamp: currentTime,
          jobSite: jobSite,
        );
      }
    }

    // Check for exit events
    for (final previousJobSiteId in previousJobSites) {
      if (!currentJobSites.any((js) => js.id == previousJobSiteId)) {
        final jobSite = _jobSiteCache[previousJobSiteId];
        if (jobSite != null) {
          await _triggerGeofenceEvent(
            entityId: entityId,
            entityType: entityType,
            jobSiteId: previousJobSiteId,
            eventType: GeofenceEventType.exit,
            latitude: latitude,
            longitude: longitude,
            timestamp: currentTime,
            jobSite: jobSite,
          );
        }
      }
    }

    // Update session
    session.currentJobSites = currentJobSites.map((js) => js.id!).toList();
    session.lastLocationUpdate = currentTime;
    _monitoringSessions[entityId] = session;
  }

  /// Trigger a geofence event
  Future<void> _triggerGeofenceEvent({
    required String entityId,
    required String entityType,
    required String jobSiteId,
    required GeofenceEventType eventType,
    required double latitude,
    required double longitude,
    required DateTime timestamp,
    required JobSite jobSite,
  }) async {
    final event = GeofenceEvent(
      eventId: _firestore.collection(_geofenceEventsCollection).doc().id,
      entityId: entityId,
      entityType: entityType,
      jobSiteId: jobSiteId,
      eventType: eventType,
      latitude: latitude,
      longitude: longitude,
      timestamp: timestamp,
      jobSiteName: jobSite.name,
      isAuthorized: _isEntityAuthorized(entityId, entityType, jobSite),
      metadata: {
        'jobSiteAddress': jobSite.address,
        'geofenceType': jobSite.type.name,
      },
    );

    // Save event to database
    await _firestore
        .collection(_geofenceEventsCollection)
        .doc(event.eventId)
        .set(event.toMap());

    // Emit event through stream
    _geofenceEventController.add(event);

    // Trigger additional actions based on event type and authorization
    await _handleGeofenceEvent(event, jobSite);
  }

  /// Handle geofence event actions
  Future<void> _handleGeofenceEvent(GeofenceEvent event, JobSite jobSite) async {
    // Check if alerts are enabled
    if (!jobSite.alertsEnabled) return;

    // Handle unauthorized access
    if (!event.isAuthorized) {
      await _handleUnauthorizedAccess(event, jobSite);
    }

    // Apply site-specific exposure limits
    if (event.eventType == GeofenceEventType.enter && 
        event.entityType == 'tool' && 
        jobSite.exposureLimits != null) {
      await _applySiteSpecificLimits(event.entityId, jobSite);
    }
  }

  /// Handle unauthorized access to job site
  Future<void> _handleUnauthorizedAccess(GeofenceEvent event, JobSite jobSite) async {
    // Log security event
    print('SECURITY ALERT: Unauthorized ${event.entityType} ${event.entityId} '
          '${event.eventType.name} job site ${jobSite.name}');
    
    // TODO: Send alert to security personnel
    // TODO: Log to security audit trail
  }

  /// Apply site-specific exposure limits
  Future<void> _applySiteSpecificLimits(String toolId, JobSite jobSite) async {
    // TODO: Update tool configuration with site-specific limits
    print('Applying site-specific exposure limits for tool $toolId at ${jobSite.name}');
  }

  /// Check if entity is authorized for job site
  bool _isEntityAuthorized(String entityId, String entityType, JobSite jobSite) {
    switch (entityType) {
      case 'worker':
        return jobSite.authorizedWorkers.isEmpty || 
               jobSite.authorizedWorkers.contains(entityId);
      case 'tool':
        return jobSite.authorizedTools.isEmpty || 
               jobSite.authorizedTools.contains(entityId);
      default:
        return false;
    }
  }

  /// Check if job site is currently valid
  bool _isValidJobSite(JobSite jobSite) {
    final now = DateTime.now();
    return jobSite.isActive &&
           now.isAfter(jobSite.validFrom) &&
           (jobSite.validUntil == null || now.isBefore(jobSite.validUntil!));
  }

  /// Get geofence events for an entity
  Future<List<GeofenceEvent>> getGeofenceEvents({
    String? entityId,
    String? jobSiteId,
    GeofenceEventType? eventType,
    DateTime? startTime,
    DateTime? endTime,
    int limit = 100,
  }) async {
    Query query = _firestore.collection(_geofenceEventsCollection);

    if (entityId != null) {
      query = query.where('entityId', isEqualTo: entityId);
    }

    if (jobSiteId != null) {
      query = query.where('jobSiteId', isEqualTo: jobSiteId);
    }

    if (eventType != null) {
      query = query.where('eventType', isEqualTo: eventType.name);
    }

    if (startTime != null) {
      query = query.where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startTime));
    }

    if (endTime != null) {
      query = query.where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endTime));
    }

    query = query.orderBy('timestamp', descending: true).limit(limit);

    final snapshot = await query.get();
    return snapshot.docs
        .map((doc) => GeofenceEvent.fromMap(doc.data() as Map<String, dynamic>))
        .toList();
  }

  /// Get all active job sites
  List<JobSite> getActiveJobSites() {
    return _jobSiteCache.values
        .where((jobSite) => _isValidJobSite(jobSite))
        .toList();
  }

  /// Get job site by ID
  JobSite? getJobSite(String jobSiteId) {
    return _jobSiteCache[jobSiteId];
  }

  /// Calculate time spent in job sites
  Future<Map<String, Duration>> calculateTimeInJobSites({
    required String entityId,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    final events = await getGeofenceEvents(
      entityId: entityId,
      startTime: startTime,
      endTime: endTime,
    );

    final Map<String, Duration> timeInSites = {};
    final Map<String, DateTime> enterTimes = {};

    for (final event in events.reversed) {
      switch (event.eventType) {
        case GeofenceEventType.enter:
          enterTimes[event.jobSiteId] = event.timestamp;
          break;
        case GeofenceEventType.exit:
          final enterTime = enterTimes[event.jobSiteId];
          if (enterTime != null) {
            final duration = event.timestamp.difference(enterTime);
            timeInSites[event.jobSiteId] = 
                (timeInSites[event.jobSiteId] ?? Duration.zero) + duration;
            enterTimes.remove(event.jobSiteId);
          }
          break;
      }
    }

    // Handle ongoing sessions
    final now = DateTime.now();
    for (final entry in enterTimes.entries) {
      final duration = now.difference(entry.value);
      timeInSites[entry.key] = 
          (timeInSites[entry.key] ?? Duration.zero) + duration;
    }

    return timeInSites;
  }

  /// Clean up old geofence events
  Future<void> cleanupOldEvents({Duration retention = const Duration(days: 30)}) async {
    final cutoffDate = DateTime.now().subtract(retention);
    
    final snapshot = await _firestore
        .collection(_geofenceEventsCollection)
        .where('timestamp', isLessThan: Timestamp.fromDate(cutoffDate))
        .get();

    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }

  /// Dispose resources
  void dispose() {
    _geofenceEventController.close();
    _jobSiteCache.clear();
    _monitoringSessions.clear();
  }
}

/// Geofence monitoring session
class GeofenceMonitoringSession {
  final String entityId;
  final String entityType;
  final String entityName;
  final DateTime startedAt;
  final List<String>? specificJobSiteIds;
  List<String> currentJobSites;
  DateTime? lastLocationUpdate;

  GeofenceMonitoringSession({
    required this.entityId,
    required this.entityType,
    required this.entityName,
    required this.startedAt,
    this.specificJobSiteIds,
    this.currentJobSites = const [],
    this.lastLocationUpdate,
  });
}

/// Geofence event
class GeofenceEvent {
  final String eventId;
  final String entityId;
  final String entityType;
  final String jobSiteId;
  final GeofenceEventType eventType;
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final String jobSiteName;
  final bool isAuthorized;
  final Map<String, dynamic>? metadata;

  GeofenceEvent({
    required this.eventId,
    required this.entityId,
    required this.entityType,
    required this.jobSiteId,
    required this.eventType,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    required this.jobSiteName,
    required this.isAuthorized,
    this.metadata,
  });

  Map<String, dynamic> toMap() {
    return {
      'eventId': eventId,
      'entityId': entityId,
      'entityType': entityType,
      'jobSiteId': jobSiteId,
      'eventType': eventType.name,
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': Timestamp.fromDate(timestamp),
      'jobSiteName': jobSiteName,
      'isAuthorized': isAuthorized,
      'metadata': metadata,
    };
  }

  factory GeofenceEvent.fromMap(Map<String, dynamic> map) {
    return GeofenceEvent(
      eventId: map['eventId'] ?? '',
      entityId: map['entityId'] ?? '',
      entityType: map['entityType'] ?? '',
      jobSiteId: map['jobSiteId'] ?? '',
      eventType: GeofenceEventType.fromString(map['eventType'] ?? 'enter'),
      latitude: (map['latitude'] ?? 0.0).toDouble(),
      longitude: (map['longitude'] ?? 0.0).toDouble(),
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      jobSiteName: map['jobSiteName'] ?? '',
      isAuthorized: map['isAuthorized'] ?? false,
      metadata: map['metadata'] as Map<String, dynamic>?,
    );
  }
}

/// Geofence event types
enum GeofenceEventType {
  enter,
  exit;

  static GeofenceEventType fromString(String value) {
    return GeofenceEventType.values.firstWhere(
      (type) => type.name == value.toLowerCase(),
      orElse: () => GeofenceEventType.enter,
    );
  }
}