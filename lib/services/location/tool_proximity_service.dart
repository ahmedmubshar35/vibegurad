import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../../models/location/location_models.dart';
import 'tool_location_service.dart';
import 'worker_location_service.dart';

/// Service for managing tool proximity alerts and monitoring
class ToolProximityService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ToolLocationService _toolLocationService = ToolLocationService();
  final WorkerLocationService _workerLocationService = WorkerLocationService();
  
  static const String _proximityAlertsCollection = 'tool_proximity_alerts';
  static const String _proximityConfigCollection = 'proximity_configurations';
  static const String _proximityHistoryCollection = 'proximity_history';

  final StreamController<ToolProximityAlert> _proximityAlertController = 
      StreamController<ToolProximityAlert>.broadcast();

  // Active proximity monitoring sessions
  final Map<String, ProximityMonitoringSession> _activeSessions = {};
  
  // Proximity configurations cache
  final Map<String, ProximityConfiguration> _configCache = {};
  
  Timer? _monitoringTimer;

  /// Stream of proximity alerts
  Stream<ToolProximityAlert> get proximityAlertStream => _proximityAlertController.stream;

  /// Initialize tool proximity service
  Future<void> initialize() async {
    await _toolLocationService.initialize();
    await _workerLocationService.initialize();
    await _loadProximityConfigurations();
    _startProximityMonitoring();
  }

  /// Load proximity configurations
  Future<void> _loadProximityConfigurations() async {
    final snapshot = await _firestore
        .collection(_proximityConfigCollection)
        .where('isActive', isEqualTo: true)
        .get();

    _configCache.clear();
    for (final doc in snapshot.docs) {
      final config = ProximityConfiguration.fromMap(doc.data(), doc.id);
      _configCache[config.id!] = config;
    }
  }

  /// Start proximity monitoring
  void _startProximityMonitoring() {
    _monitoringTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      await _checkAllProximities();
    });
  }

  /// Create proximity configuration
  Future<String> createProximityConfiguration({
    required String name,
    required ProximityType type,
    required double alertDistance,
    double? warningDistance,
    List<String>? specificToolIds,
    List<String>? specificWorkerIds,
    String? jobSiteId,
    bool requiresAcknowledgment = false,
    Duration? alertCooldown,
    Map<String, dynamic>? conditions,
    List<String>? actions,
  }) async {
    final config = ProximityConfiguration(
      name: name,
      type: type,
      alertDistance: alertDistance,
      warningDistance: warningDistance ?? alertDistance * 1.5,
      specificToolIds: specificToolIds ?? [],
      specificWorkerIds: specificWorkerIds ?? [],
      jobSiteId: jobSiteId,
      requiresAcknowledgment: requiresAcknowledgment,
      alertCooldown: alertCooldown ?? const Duration(minutes: 5),
      conditions: conditions ?? {},
      actions: actions ?? [],
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final docRef = await _firestore
        .collection(_proximityConfigCollection)
        .add(config.toMap());

    _configCache[docRef.id] = config.copyWith(id: docRef.id);

    return docRef.id;
  }

  /// Start monitoring proximity for specific entities
  Future<void> startProximityMonitoring({
    required String entityId,
    required ProximityEntityType entityType,
    List<String>? configIds, // Specific configurations to apply
  }) async {
    final session = ProximityMonitoringSession(
      entityId: entityId,
      entityType: entityType,
      configIds: configIds,
      startTime: DateTime.now(),
      isActive: true,
    );

    _activeSessions[entityId] = session;
  }

  /// Stop proximity monitoring for an entity
  void stopProximityMonitoring(String entityId) {
    _activeSessions.remove(entityId);
  }

  /// Check proximities for all active sessions
  Future<void> _checkAllProximities() async {
    for (final session in _activeSessions.values) {
      await _checkEntityProximity(session);
    }
  }

  /// Check proximity for a specific entity
  Future<void> _checkEntityProximity(ProximityMonitoringSession session) async {
    try {
      if (session.entityType == ProximityEntityType.tool) {
        await _checkToolProximity(session);
      } else if (session.entityType == ProximityEntityType.worker) {
        await _checkWorkerProximity(session);
      }
    } catch (e) {
      print('Error checking proximity for ${session.entityId}: $e');
    }
  }

  /// Check tool proximity alerts
  Future<void> _checkToolProximity(ProximityMonitoringSession session) async {
    final toolLocation = await _toolLocationService.getToolLocation(session.entityId);
    if (toolLocation == null) return;

    final applicableConfigs = _getApplicableConfigurations(session);
    
    for (final config in applicableConfigs) {
      switch (config.type) {
        case ProximityType.toolToWorker:
          await _checkToolToWorkerProximity(toolLocation, config);
          break;
        case ProximityType.toolToTool:
          await _checkToolToToolProximity(toolLocation, config);
          break;
        case ProximityType.toolToArea:
          await _checkToolToAreaProximity(toolLocation, config);
          break;
        case ProximityType.workerToWorker:
          // Not applicable for tool monitoring
          break;
      }
    }
  }

  /// Check worker proximity alerts
  Future<void> _checkWorkerProximity(ProximityMonitoringSession session) async {
    final workerLocation = await _workerLocationService.getWorkerLocation(session.entityId);
    if (workerLocation == null) return;

    final applicableConfigs = _getApplicableConfigurations(session);
    
    for (final config in applicableConfigs) {
      switch (config.type) {
        case ProximityType.workerToWorker:
          await _checkWorkerToWorkerProximity(workerLocation, config);
          break;
        case ProximityType.toolToWorker:
          await _checkWorkerToToolProximity(workerLocation, config);
          break;
        case ProximityType.toolToTool:
        case ProximityType.toolToArea:
          // Not applicable for worker monitoring
          break;
      }
    }
  }

  /// Check tool-to-worker proximity
  Future<void> _checkToolToWorkerProximity(
    ToolLocationData toolLocation,
    ProximityConfiguration config,
  ) async {
    final workers = await _workerLocationService.getAllActive();
    
    for (final worker in workers) {
      if (config.specificWorkerIds.isNotEmpty &&
          !config.specificWorkerIds.contains(worker.workerId)) {
        continue;
      }

      final distance = Geolocator.distanceBetween(
        toolLocation.latitude,
        toolLocation.longitude,
        worker.latitude,
        worker.longitude,
      );

      await _evaluateProximityAlert(
        entityId1: toolLocation.toolId,
        entityType1: ProximityEntityType.tool,
        entityId2: worker.workerId,
        entityType2: ProximityEntityType.worker,
        distance: distance,
        config: config,
        location1: toolLocation,
        location2: worker,
      );
    }
  }

  /// Check tool-to-tool proximity
  Future<void> _checkToolToToolProximity(
    ToolLocationData toolLocation,
    ProximityConfiguration config,
  ) async {
    final tools = await _toolLocationService.getAllActive();
    
    for (final otherTool in tools) {
      if (otherTool.toolId == toolLocation.toolId) continue;

      if (config.specificToolIds.isNotEmpty &&
          !config.specificToolIds.contains(otherTool.toolId)) {
        continue;
      }

      final distance = Geolocator.distanceBetween(
        toolLocation.latitude,
        toolLocation.longitude,
        otherTool.latitude,
        otherTool.longitude,
      );

      await _evaluateProximityAlert(
        entityId1: toolLocation.toolId,
        entityType1: ProximityEntityType.tool,
        entityId2: otherTool.toolId,
        entityType2: ProximityEntityType.tool,
        distance: distance,
        config: config,
        location1: toolLocation,
        location2: otherTool,
      );
    }
  }

  /// Check tool-to-area proximity (dangerous zones, etc.)
  Future<void> _checkToolToAreaProximity(
    ToolLocationData toolLocation,
    ProximityConfiguration config,
  ) async {
    // Check if tool is within specified areas (from config conditions)
    final areas = config.conditions['areas'] as List<dynamic>? ?? [];
    
    for (final areaData in areas) {
      final area = areaData as Map<String, dynamic>;
      final centerLat = area['centerLat'] as double;
      final centerLng = area['centerLng'] as double;
      final radius = area['radius'] as double;

      final distance = Geolocator.distanceBetween(
        toolLocation.latitude,
        toolLocation.longitude,
        centerLat,
        centerLng,
      );

      if (distance <= config.alertDistance) {
        await _createProximityAlert(
          entityId1: toolLocation.toolId,
          entityType1: ProximityEntityType.tool,
          entityId2: area['name'] ?? 'Restricted Area',
          entityType2: ProximityEntityType.area,
          alertType: 'area_proximity',
          distance: distance,
          config: config,
          severity: distance <= config.alertDistance * 0.5 ? 'critical' : 'warning',
          message: 'Tool ${toolLocation.toolName} is near restricted area ${area['name']}',
          location: toolLocation,
        );
      }
    }
  }

  /// Check worker-to-worker proximity
  Future<void> _checkWorkerToWorkerProximity(
    WorkerLocationData workerLocation,
    ProximityConfiguration config,
  ) async {
    final workers = await _workerLocationService.getAllActive();
    
    for (final otherWorker in workers) {
      if (otherWorker.workerId == workerLocation.workerId) continue;

      if (config.specificWorkerIds.isNotEmpty &&
          !config.specificWorkerIds.contains(otherWorker.workerId)) {
        continue;
      }

      final distance = Geolocator.distanceBetween(
        workerLocation.latitude,
        workerLocation.longitude,
        otherWorker.latitude,
        otherWorker.longitude,
      );

      await _evaluateProximityAlert(
        entityId1: workerLocation.workerId,
        entityType1: ProximityEntityType.worker,
        entityId2: otherWorker.workerId,
        entityType2: ProximityEntityType.worker,
        distance: distance,
        config: config,
        location1: workerLocation,
        location2: otherWorker,
      );
    }
  }

  /// Check worker-to-tool proximity
  Future<void> _checkWorkerToToolProximity(
    WorkerLocationData workerLocation,
    ProximityConfiguration config,
  ) async {
    final tools = await _toolLocationService.getAllActive();
    
    for (final tool in tools) {
      if (config.specificToolIds.isNotEmpty &&
          !config.specificToolIds.contains(tool.toolId)) {
        continue;
      }

      final distance = Geolocator.distanceBetween(
        workerLocation.latitude,
        workerLocation.longitude,
        tool.latitude,
        tool.longitude,
      );

      await _evaluateProximityAlert(
        entityId1: workerLocation.workerId,
        entityType1: ProximityEntityType.worker,
        entityId2: tool.toolId,
        entityType2: ProximityEntityType.tool,
        distance: distance,
        config: config,
        location1: workerLocation,
        location2: tool,
      );
    }
  }

  /// Evaluate if proximity alert should be triggered
  Future<void> _evaluateProximityAlert({
    required String entityId1,
    required ProximityEntityType entityType1,
    required String entityId2,
    required ProximityEntityType entityType2,
    required double distance,
    required ProximityConfiguration config,
    required dynamic location1,
    required dynamic location2,
  }) async {
    String alertType;
    String severity;
    
    if (distance <= config.alertDistance) {
      alertType = 'critical_proximity';
      severity = 'critical';
    } else if (distance <= config.warningDistance) {
      alertType = 'proximity_warning';
      severity = 'warning';
    } else {
      return; // No alert needed
    }

    // Check cooldown period
    final alertKey = '${entityId1}_${entityId2}_${config.id}';
    if (await _isInCooldownPeriod(alertKey, config.alertCooldown)) {
      return;
    }

    String message = _generateProximityMessage(
      entityId1, entityType1,
      entityId2, entityType2,
      distance, alertType,
    );

    await _createProximityAlert(
      entityId1: entityId1,
      entityType1: entityType1,
      entityId2: entityId2,
      entityType2: entityType2,
      alertType: alertType,
      distance: distance,
      config: config,
      severity: severity,
      message: message,
      location: location1,
    );

    // Record cooldown
    await _recordAlertCooldown(alertKey, config.alertCooldown);
  }

  /// Create proximity alert
  Future<void> _createProximityAlert({
    required String entityId1,
    required ProximityEntityType entityType1,
    required String entityId2,
    required ProximityEntityType entityType2,
    required String alertType,
    required double distance,
    required ProximityConfiguration config,
    required String severity,
    required String message,
    required dynamic location,
  }) async {
    final alert = ToolProximityAlert(
      alertId: '${DateTime.now().millisecondsSinceEpoch}',
      toolId: entityType1 == ProximityEntityType.tool ? entityId1 : entityId2,
      workerId: entityType1 == ProximityEntityType.worker ? entityId1 : 
                (entityType2 == ProximityEntityType.worker ? entityId2 : ''),
      alertType: alertType,
      distance: distance,
      triggeredAt: DateTime.now(),
      message: message,
      severity: severity,
      acknowledged: false,
    );

    // Save to database
    await _firestore
        .collection(_proximityAlertsCollection)
        .doc(alert.alertId)
        .set(alert.toMap());

    // Emit alert
    _proximityAlertController.add(alert);

    // Record proximity history
    await _recordProximityHistory(
      entityId1, entityType1,
      entityId2, entityType2,
      distance, config, location,
    );

    // Execute configured actions
    await _executeAlertActions(alert, config);
  }

  /// Generate proximity message
  String _generateProximityMessage(
    String entityId1, ProximityEntityType entityType1,
    String entityId2, ProximityEntityType entityType2,
    double distance, String alertType,
  ) {
    final distanceText = '${distance.toStringAsFixed(1)}m';
    
    if (entityType1 == ProximityEntityType.tool && entityType2 == ProximityEntityType.worker) {
      return 'Tool $entityId1 is ${distanceText} from worker $entityId2';
    } else if (entityType1 == ProximityEntityType.worker && entityType2 == ProximityEntityType.tool) {
      return 'Worker $entityId1 is ${distanceText} from tool $entityId2';
    } else if (entityType1 == ProximityEntityType.tool && entityType2 == ProximityEntityType.tool) {
      return 'Tools $entityId1 and $entityId2 are ${distanceText} apart';
    } else if (entityType1 == ProximityEntityType.worker && entityType2 == ProximityEntityType.worker) {
      return 'Workers $entityId1 and $entityId2 are ${distanceText} apart';
    } else {
      return 'Proximity alert: $entityId1 is ${distanceText} from $entityId2';
    }
  }

  /// Execute alert actions
  Future<void> _executeAlertActions(ToolProximityAlert alert, ProximityConfiguration config) async {
    for (final action in config.actions) {
      switch (action) {
        case 'send_notification':
          await _sendNotification(alert);
          break;
        case 'log_to_audit':
          await _logToAudit(alert, config);
          break;
        case 'trigger_emergency_stop':
          await _triggerEmergencyStop(alert);
          break;
        case 'escalate_to_supervisor':
          await _escalateToSupervisor(alert, config);
          break;
      }
    }
  }

  /// Get proximity alerts
  Future<List<ToolProximityAlert>> getProximityAlerts({
    String? entityId,
    ProximityEntityType? entityType,
    DateTime? startTime,
    DateTime? endTime,
    bool? acknowledged,
    int limit = 100,
  }) async {
    Query query = _firestore
        .collection(_proximityAlertsCollection)
        .orderBy('triggeredAt', descending: true);

    if (entityId != null) {
      if (entityType == ProximityEntityType.tool) {
        query = query.where('toolId', isEqualTo: entityId);
      } else if (entityType == ProximityEntityType.worker) {
        query = query.where('workerId', isEqualTo: entityId);
      }
    }

    if (startTime != null) {
      query = query.where('triggeredAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startTime));
    }

    if (endTime != null) {
      query = query.where('triggeredAt', isLessThanOrEqualTo: Timestamp.fromDate(endTime));
    }

    if (acknowledged != null) {
      query = query.where('acknowledged', isEqualTo: acknowledged);
    }

    query = query.limit(limit);

    final snapshot = await query.get();
    return snapshot.docs
        .map((doc) => ToolProximityAlert.fromMap(doc.data() as Map<String, dynamic>))
        .toList();
  }

  /// Acknowledge proximity alert
  Future<void> acknowledgeAlert(String alertId, {String? acknowledgedBy}) async {
    await _firestore
        .collection(_proximityAlertsCollection)
        .doc(alertId)
        .update({
          'acknowledged': true,
          'acknowledgedAt': Timestamp.fromDate(DateTime.now()),
          'acknowledgedBy': acknowledgedBy,
        });
  }

  /// Get proximity statistics
  Future<ProximityStatistics> getProximityStatistics({
    String? jobSiteId,
    DateTime? startTime,
    DateTime? endTime,
  }) async {
    startTime ??= DateTime.now().subtract(const Duration(days: 30));
    endTime ??= DateTime.now();

    Query query = _firestore
        .collection(_proximityAlertsCollection)
        .where('triggeredAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startTime))
        .where('triggeredAt', isLessThanOrEqualTo: Timestamp.fromDate(endTime));

    final snapshot = await query.get();
    final alerts = snapshot.docs
        .map((doc) => ToolProximityAlert.fromMap(doc.data() as Map<String, dynamic>))
        .toList();

    final totalAlerts = alerts.length;
    final acknowledgedAlerts = alerts.where((a) => a.acknowledged).length;
    final criticalAlerts = alerts.where((a) => a.severity == 'critical').length;
    
    final alertsByType = <String, int>{};
    for (final alert in alerts) {
      alertsByType[alert.alertType] = (alertsByType[alert.alertType] ?? 0) + 1;
    }

    return ProximityStatistics(
      totalAlerts: totalAlerts,
      acknowledgedAlerts: acknowledgedAlerts,
      criticalAlerts: criticalAlerts,
      averageDistance: alerts.isNotEmpty
          ? alerts.map((a) => a.distance).reduce((a, b) => a + b) / alerts.length
          : 0.0,
      alertsByType: alertsByType,
      period: DateTimeRange(startTime, endTime),
    );
  }

  /// Private helper methods
  List<ProximityConfiguration> _getApplicableConfigurations(ProximityMonitoringSession session) {
    if (session.configIds != null) {
      return session.configIds!
          .map((id) => _configCache[id])
          .where((config) => config != null)
          .cast<ProximityConfiguration>()
          .toList();
    }

    return _configCache.values.where((config) => config.isActive).toList();
  }

  Future<bool> _isInCooldownPeriod(String alertKey, Duration cooldown) async {
    // Check if we've sent an alert for this combination recently
    final lastAlertDoc = await _firestore
        .collection('alert_cooldowns')
        .doc(alertKey)
        .get();

    if (lastAlertDoc.exists) {
      final lastAlert = (lastAlertDoc.data()!['timestamp'] as Timestamp).toDate();
      return DateTime.now().difference(lastAlert) < cooldown;
    }

    return false;
  }

  Future<void> _recordAlertCooldown(String alertKey, Duration cooldown) async {
    await _firestore
        .collection('alert_cooldowns')
        .doc(alertKey)
        .set({
          'timestamp': Timestamp.fromDate(DateTime.now()),
          'cooldownMinutes': cooldown.inMinutes,
        });
  }

  Future<void> _recordProximityHistory(
    String entityId1, ProximityEntityType entityType1,
    String entityId2, ProximityEntityType entityType2,
    double distance, ProximityConfiguration config,
    dynamic location,
  ) async {
    final historyEntry = {
      'entityId1': entityId1,
      'entityType1': entityType1.name,
      'entityId2': entityId2,
      'entityType2': entityType2.name,
      'distance': distance,
      'configId': config.id,
      'timestamp': Timestamp.fromDate(DateTime.now()),
      'location': location is ToolLocationData
          ? {'lat': location.latitude, 'lng': location.longitude}
          : {'lat': location.latitude, 'lng': location.longitude},
    };

    await _firestore
        .collection(_proximityHistoryCollection)
        .add(historyEntry);
  }

  Future<void> _sendNotification(ToolProximityAlert alert) async {
    // Implement notification sending logic
    print('Sending notification for proximity alert: ${alert.message}');
  }

  Future<void> _logToAudit(ToolProximityAlert alert, ProximityConfiguration config) async {
    // Log to audit trail
    print('Logging proximity alert to audit: ${alert.alertId}');
  }

  Future<void> _triggerEmergencyStop(ToolProximityAlert alert) async {
    // Implement emergency stop logic
    print('EMERGENCY STOP triggered for proximity alert: ${alert.alertId}');
  }

  Future<void> _escalateToSupervisor(ToolProximityAlert alert, ProximityConfiguration config) async {
    // Escalate to supervisor
    print('Escalating proximity alert to supervisor: ${alert.alertId}');
  }

  /// Dispose resources
  void dispose() {
    _monitoringTimer?.cancel();
    _proximityAlertController.close();
    _activeSessions.clear();
    _configCache.clear();
  }
}

/// Proximity monitoring session
class ProximityMonitoringSession {
  final String entityId;
  final ProximityEntityType entityType;
  final List<String>? configIds;
  final DateTime startTime;
  bool isActive;

  ProximityMonitoringSession({
    required this.entityId,
    required this.entityType,
    this.configIds,
    required this.startTime,
    required this.isActive,
  });
}

/// Proximity configuration
class ProximityConfiguration {
  final String? id;
  final String name;
  final ProximityType type;
  final double alertDistance;
  final double warningDistance;
  final List<String> specificToolIds;
  final List<String> specificWorkerIds;
  final String? jobSiteId;
  final bool requiresAcknowledgment;
  final Duration alertCooldown;
  final Map<String, dynamic> conditions;
  final List<String> actions;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  ProximityConfiguration({
    this.id,
    required this.name,
    required this.type,
    required this.alertDistance,
    required this.warningDistance,
    required this.specificToolIds,
    required this.specificWorkerIds,
    this.jobSiteId,
    required this.requiresAcknowledgment,
    required this.alertCooldown,
    required this.conditions,
    required this.actions,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'type': type.name,
      'alertDistance': alertDistance,
      'warningDistance': warningDistance,
      'specificToolIds': specificToolIds,
      'specificWorkerIds': specificWorkerIds,
      'jobSiteId': jobSiteId,
      'requiresAcknowledgment': requiresAcknowledgment,
      'alertCooldownMinutes': alertCooldown.inMinutes,
      'conditions': conditions,
      'actions': actions,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory ProximityConfiguration.fromMap(Map<String, dynamic> map, String id) {
    return ProximityConfiguration(
      id: id,
      name: map['name'] ?? '',
      type: ProximityType.fromString(map['type'] ?? 'tool_to_worker'),
      alertDistance: (map['alertDistance'] ?? 0.0).toDouble(),
      warningDistance: (map['warningDistance'] ?? 0.0).toDouble(),
      specificToolIds: List<String>.from(map['specificToolIds'] ?? []),
      specificWorkerIds: List<String>.from(map['specificWorkerIds'] ?? []),
      jobSiteId: map['jobSiteId'],
      requiresAcknowledgment: map['requiresAcknowledgment'] ?? false,
      alertCooldown: Duration(minutes: map['alertCooldownMinutes'] ?? 5),
      conditions: map['conditions'] as Map<String, dynamic>? ?? {},
      actions: List<String>.from(map['actions'] ?? []),
      isActive: map['isActive'] ?? true,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
    );
  }

  ProximityConfiguration copyWith({
    String? id,
    String? name,
    ProximityType? type,
    double? alertDistance,
    double? warningDistance,
    List<String>? specificToolIds,
    List<String>? specificWorkerIds,
    String? jobSiteId,
    bool? requiresAcknowledgment,
    Duration? alertCooldown,
    Map<String, dynamic>? conditions,
    List<String>? actions,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProximityConfiguration(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      alertDistance: alertDistance ?? this.alertDistance,
      warningDistance: warningDistance ?? this.warningDistance,
      specificToolIds: specificToolIds ?? this.specificToolIds,
      specificWorkerIds: specificWorkerIds ?? this.specificWorkerIds,
      jobSiteId: jobSiteId ?? this.jobSiteId,
      requiresAcknowledgment: requiresAcknowledgment ?? this.requiresAcknowledgment,
      alertCooldown: alertCooldown ?? this.alertCooldown,
      conditions: conditions ?? this.conditions,
      actions: actions ?? this.actions,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Proximity statistics
class ProximityStatistics {
  final int totalAlerts;
  final int acknowledgedAlerts;
  final int criticalAlerts;
  final double averageDistance;
  final Map<String, int> alertsByType;
  final DateTimeRange period;

  ProximityStatistics({
    required this.totalAlerts,
    required this.acknowledgedAlerts,
    required this.criticalAlerts,
    required this.averageDistance,
    required this.alertsByType,
    required this.period,
  });
}

/// Date time range helper
class DateTimeRange {
  final DateTime start;
  final DateTime end;

  DateTimeRange(this.start, this.end);
}

/// Proximity types
enum ProximityType {
  toolToWorker,
  toolToTool,
  workerToWorker,
  toolToArea;

  static ProximityType fromString(String value) {
    return ProximityType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => ProximityType.toolToWorker,
    );
  }
}

/// Proximity entity types
enum ProximityEntityType {
  tool,
  worker,
  area;
}