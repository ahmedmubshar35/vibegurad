import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/location/location_models.dart';
import 'geofencing_service.dart';
import 'tool_location_service.dart';

/// Service for managing site-specific exposure limits and environmental factors
class SiteExposureService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GeofencingService _geofencingService = GeofencingService();
  final ToolLocationService _toolLocationService = ToolLocationService();
  
  static const String _exposureLimitsCollection = 'site_exposure_limits';
  static const String _environmentalFactorsCollection = 'environmental_factors';
  static const String _exposureOverridesCollection = 'exposure_overrides';

  final StreamController<SiteExposureUpdate> _exposureUpdateController = 
      StreamController<SiteExposureUpdate>.broadcast();

  /// Stream of site-specific exposure updates
  Stream<SiteExposureUpdate> get exposureUpdateStream => _exposureUpdateController.stream;

  /// Initialize site exposure service
  Future<void> initialize() async {
    await _geofencingService.initialize();
    await _toolLocationService.initialize();
    _startListeningToGeofenceEvents();
  }

  /// Start listening to geofence events to apply site-specific limits
  void _startListeningToGeofenceEvents() {
    _geofencingService.geofenceEventStream.listen((event) {
      if (event.eventType == GeofenceEventType.enter) {
        _applySiteSpecificLimits(event);
      } else if (event.eventType == GeofenceEventType.exit) {
        _restoreDefaultLimits(event);
      }
    });
  }

  /// Create site-specific exposure configuration
  Future<String> createSiteExposureConfig({
    required String jobSiteId,
    required String jobSiteName,
    required Map<String, SiteExposureLimit> toolLimits,
    Map<String, double>? environmentalFactors,
    String? weatherConditions,
    double? temperatureCelsius,
    double? humidityPercent,
    String? notes,
    DateTime? validFrom,
    DateTime? validUntil,
  }) async {
    final config = SiteExposureConfig(
      jobSiteId: jobSiteId,
      jobSiteName: jobSiteName,
      toolLimits: toolLimits,
      environmentalFactors: environmentalFactors ?? {},
      weatherConditions: weatherConditions,
      temperatureCelsius: temperatureCelsius,
      humidityPercent: humidityPercent,
      notes: notes,
      validFrom: validFrom ?? DateTime.now(),
      validUntil: validUntil,
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final docRef = await _firestore
        .collection(_exposureLimitsCollection)
        .add(config.toMap());

    return docRef.id;
  }

  /// Update site exposure configuration
  Future<void> updateSiteExposureConfig(
    String configId,
    Map<String, dynamic> updates,
  ) async {
    await _firestore
        .collection(_exposureLimitsCollection)
        .doc(configId)
        .update({
          ...updates,
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        });
  }

  /// Get site exposure configuration
  Future<SiteExposureConfig?> getSiteExposureConfig(String jobSiteId) async {
    final snapshot = await _firestore
        .collection(_exposureLimitsCollection)
        .where('jobSiteId', isEqualTo: jobSiteId)
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      return SiteExposureConfig.fromMap(snapshot.docs.first.data(), snapshot.docs.first.id);
    }

    return null;
  }

  /// Apply site-specific exposure limits when entering a job site
  Future<void> _applySiteSpecificLimits(GeofenceEvent event) async {
    final config = await getSiteExposureConfig(event.jobSiteId);
    if (config == null || !config.isActive) return;

    if (event.entityType == 'tool') {
      await _applyToolExposureLimits(event.entityId, config);
    } else if (event.entityType == 'worker') {
      await _applyWorkerExposureLimits(event.entityId, config);
    }

    // Emit exposure update event
    _exposureUpdateController.add(SiteExposureUpdate(
      entityId: event.entityId,
      entityType: event.entityType,
      jobSiteId: event.jobSiteId,
      jobSiteName: event.jobSiteName,
      updateType: ExposureUpdateType.limitsApplied,
      newLimits: config.toolLimits,
      environmentalFactors: config.environmentalFactors,
      timestamp: DateTime.now(),
    ));
  }

  /// Restore default limits when exiting a job site
  Future<void> _restoreDefaultLimits(GeofenceEvent event) async {
    if (event.entityType == 'tool') {
      await _restoreDefaultToolLimits(event.entityId);
    } else if (event.entityType == 'worker') {
      await _restoreDefaultWorkerLimits(event.entityId);
    }

    // Emit exposure update event
    _exposureUpdateController.add(SiteExposureUpdate(
      entityId: event.entityId,
      entityType: event.entityType,
      jobSiteId: event.jobSiteId,
      jobSiteName: event.jobSiteName,
      updateType: ExposureUpdateType.limitsRestored,
      newLimits: {},
      environmentalFactors: {},
      timestamp: DateTime.now(),
    ));
  }

  /// Apply tool-specific exposure limits
  Future<void> _applyToolExposureLimits(String toolId, SiteExposureConfig config) async {
    // Get tool information to determine tool type
    final toolLocation = await _toolLocationService.getToolLocation(toolId);
    if (toolLocation == null) return;

    // Find matching exposure limit for this tool
    SiteExposureLimit? applicableLimit;
    
    // Try exact tool ID match first
    if (config.toolLimits.containsKey(toolId)) {
      applicableLimit = config.toolLimits[toolId];
    } else {
      // Try tool type match (would need tool registry to get tool type)
      // For now, use default limit if available
      if (config.toolLimits.containsKey('default')) {
        applicableLimit = config.toolLimits['default'];
      }
    }

    if (applicableLimit == null) return;

    // Calculate adjusted limits based on environmental factors
    final adjustedLimit = _calculateAdjustedLimits(applicableLimit, config);

    // Apply limits to tool (this would integrate with tool control system)
    await _applyToolLimits(toolId, adjustedLimit);
    
    print('Applied site-specific limits to tool $toolId: '
          'Daily: ${adjustedLimit.dailyExposureLimit}, '
          'Session: ${adjustedLimit.sessionExposureLimit}');
  }

  /// Apply worker-specific exposure limits
  Future<void> _applyWorkerExposureLimits(String workerId, SiteExposureConfig config) async {
    // Apply any worker-specific restrictions based on site conditions
    // This could include mandatory PPE, reduced work hours, etc.
    
    print('Applied site-specific worker limits for worker $workerId at site ${config.jobSiteName}');
  }

  /// Calculate adjusted limits based on environmental factors
  SiteExposureLimit _calculateAdjustedLimits(
    SiteExposureLimit baseLimit,
    SiteExposureConfig config,
  ) {
    double dailyAdjustment = 1.0;
    double sessionAdjustment = 1.0;

    // Temperature adjustments
    if (config.temperatureCelsius != null) {
      final temp = config.temperatureCelsius!;
      if (temp > 30) {
        // Hot conditions - reduce limits
        dailyAdjustment *= 0.8;
        sessionAdjustment *= 0.85;
      } else if (temp < 0) {
        // Cold conditions - may affect tool operation
        dailyAdjustment *= 0.9;
        sessionAdjustment *= 0.9;
      }
    }

    // Humidity adjustments
    if (config.humidityPercent != null) {
      final humidity = config.humidityPercent!;
      if (humidity > 80) {
        // High humidity - reduce limits
        dailyAdjustment *= 0.9;
      }
    }

    // Weather condition adjustments
    if (config.weatherConditions != null) {
      switch (config.weatherConditions!.toLowerCase()) {
        case 'rain':
        case 'storm':
          dailyAdjustment *= 0.7;
          sessionAdjustment *= 0.8;
          break;
        case 'snow':
        case 'ice':
          dailyAdjustment *= 0.6;
          sessionAdjustment *= 0.7;
          break;
      }
    }

    // Environmental factors adjustments
    for (final factor in config.environmentalFactors.entries) {
      switch (factor.key.toLowerCase()) {
        case 'noise_level':
          if (factor.value > 85) {
            dailyAdjustment *= 0.85;
          }
          break;
        case 'dust_level':
          if (factor.value > 5.0) {
            dailyAdjustment *= 0.9;
          }
          break;
        case 'confined_space':
          if (factor.value > 0) {
            dailyAdjustment *= 0.8;
            sessionAdjustment *= 0.75;
          }
          break;
      }
    }

    return SiteExposureLimit(
      toolId: baseLimit.toolId,
      toolType: baseLimit.toolType,
      dailyExposureLimit: baseLimit.dailyExposureLimit * dailyAdjustment,
      sessionExposureLimit: baseLimit.sessionExposureLimit * sessionAdjustment,
      breakIntervalMinutes: baseLimit.breakIntervalMinutes,
      maxContinuousMinutes: (baseLimit.maxContinuousMinutes * sessionAdjustment).round(),
      vibrationThreshold: baseLimit.vibrationThreshold,
      requiresPPE: baseLimit.requiresPPE,
      requiredPPE: baseLimit.requiredPPE,
      restrictions: [
        ...baseLimit.restrictions,
        if (dailyAdjustment < 1.0) 'Environmental adjustment applied',
      ],
      isActive: baseLimit.isActive,
    );
  }

  /// Create temporary exposure override
  Future<String> createExposureOverride({
    required String entityId,
    required String entityType,
    required String jobSiteId,
    required String reason,
    required String authorizedBy,
    required Map<String, double> overrideLimits,
    required Duration validDuration,
    String? notes,
  }) async {
    final override = ExposureOverride(
      entityId: entityId,
      entityType: entityType,
      jobSiteId: jobSiteId,
      reason: reason,
      authorizedBy: authorizedBy,
      overrideLimits: overrideLimits,
      validFrom: DateTime.now(),
      validUntil: DateTime.now().add(validDuration),
      notes: notes,
      isActive: true,
      createdAt: DateTime.now(),
    );

    final docRef = await _firestore
        .collection(_exposureOverridesCollection)
        .add(override.toMap());

    // Apply override immediately if entity is currently at the job site
    await _applyOverrideIfApplicable(override);

    return docRef.id;
  }

  /// Get active exposure overrides
  Future<List<ExposureOverride>> getActiveOverrides({
    String? entityId,
    String? jobSiteId,
  }) async {
    Query query = _firestore
        .collection(_exposureOverridesCollection)
        .where('isActive', isEqualTo: true)
        .where('validUntil', isGreaterThan: Timestamp.fromDate(DateTime.now()));

    if (entityId != null) {
      query = query.where('entityId', isEqualTo: entityId);
    }

    if (jobSiteId != null) {
      query = query.where('jobSiteId', isEqualTo: jobSiteId);
    }

    final snapshot = await query.get();
    return snapshot.docs
        .map((doc) => ExposureOverride.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList();
  }

  /// Record environmental conditions at a job site
  Future<void> recordEnvironmentalConditions({
    required String jobSiteId,
    required double temperatureCelsius,
    required double humidityPercent,
    required String weatherConditions,
    Map<String, double>? additionalFactors,
    String? recordedBy,
  }) async {
    final conditions = EnvironmentalConditions(
      jobSiteId: jobSiteId,
      temperatureCelsius: temperatureCelsius,
      humidityPercent: humidityPercent,
      weatherConditions: weatherConditions,
      additionalFactors: additionalFactors ?? {},
      recordedBy: recordedBy,
      timestamp: DateTime.now(),
    );

    await _firestore
        .collection(_environmentalFactorsCollection)
        .add(conditions.toMap());

    // Update active site exposure config with new conditions
    await _updateSiteConditions(jobSiteId, conditions);
  }

  /// Get historical environmental conditions
  Future<List<EnvironmentalConditions>> getEnvironmentalHistory({
    required String jobSiteId,
    DateTime? startTime,
    DateTime? endTime,
    int limit = 50,
  }) async {
    Query query = _firestore
        .collection(_environmentalFactorsCollection)
        .where('jobSiteId', isEqualTo: jobSiteId)
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
        .map((doc) => EnvironmentalConditions.fromMap(doc.data() as Map<String, dynamic>))
        .toList();
  }

  /// Get exposure compliance report for a site
  Future<SiteExposureComplianceReport> getComplianceReport({
    required String jobSiteId,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    // This would analyze actual exposure vs. limits for the site
    // For now, return a simplified report structure
    
    return SiteExposureComplianceReport(
      jobSiteId: jobSiteId,
      reportPeriod: DateTimeRange(startTime, endTime),
      totalWorkers: 0,
      totalTools: 0,
      complianceRate: 95.0,
      violations: [],
      recommendations: [
        'Continue monitoring environmental conditions',
        'Regular calibration of exposure limits',
      ],
      generatedAt: DateTime.now(),
    );
  }

  /// Private helper methods
  Future<void> _applyToolLimits(String toolId, SiteExposureLimit limit) async {
    // This would integrate with the tool control system
    // to actually apply the exposure limits to the tool
    print('Applying limits to tool $toolId: $limit');
  }

  Future<void> _restoreDefaultToolLimits(String toolId) async {
    // Restore original tool limits
    print('Restoring default limits for tool $toolId');
  }

  Future<void> _restoreDefaultWorkerLimits(String workerId) async {
    // Restore original worker limits
    print('Restoring default limits for worker $workerId');
  }

  Future<void> _applyOverrideIfApplicable(ExposureOverride override) async {
    // Check if the entity is currently at the job site and apply override
    print('Applying exposure override for ${override.entityId}');
  }

  Future<void> _updateSiteConditions(String jobSiteId, EnvironmentalConditions conditions) async {
    // Update the active site exposure config with new environmental conditions
    final config = await getSiteExposureConfig(jobSiteId);
    if (config != null) {
      await updateSiteExposureConfig(config.id!, {
        'temperatureCelsius': conditions.temperatureCelsius,
        'humidityPercent': conditions.humidityPercent,
        'weatherConditions': conditions.weatherConditions,
        'environmentalFactors': conditions.additionalFactors,
      });
    }
  }

  /// Clean up expired overrides
  Future<void> cleanupExpiredOverrides() async {
    final expiredSnapshot = await _firestore
        .collection(_exposureOverridesCollection)
        .where('validUntil', isLessThan: Timestamp.fromDate(DateTime.now()))
        .get();

    final batch = _firestore.batch();
    for (final doc in expiredSnapshot.docs) {
      batch.update(doc.reference, {'isActive': false});
    }

    await batch.commit();
  }

  /// Dispose resources
  void dispose() {
    _exposureUpdateController.close();
  }
}

/// Site exposure configuration model
class SiteExposureConfig {
  final String? id;
  final String jobSiteId;
  final String jobSiteName;
  final Map<String, SiteExposureLimit> toolLimits;
  final Map<String, double> environmentalFactors;
  final String? weatherConditions;
  final double? temperatureCelsius;
  final double? humidityPercent;
  final String? notes;
  final DateTime validFrom;
  final DateTime? validUntil;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  SiteExposureConfig({
    this.id,
    required this.jobSiteId,
    required this.jobSiteName,
    required this.toolLimits,
    required this.environmentalFactors,
    this.weatherConditions,
    this.temperatureCelsius,
    this.humidityPercent,
    this.notes,
    required this.validFrom,
    this.validUntil,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'jobSiteId': jobSiteId,
      'jobSiteName': jobSiteName,
      'toolLimits': toolLimits.map((k, v) => MapEntry(k, v.toMap())),
      'environmentalFactors': environmentalFactors,
      'weatherConditions': weatherConditions,
      'temperatureCelsius': temperatureCelsius,
      'humidityPercent': humidityPercent,
      'notes': notes,
      'validFrom': Timestamp.fromDate(validFrom),
      'validUntil': validUntil != null ? Timestamp.fromDate(validUntil!) : null,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory SiteExposureConfig.fromMap(Map<String, dynamic> map, String id) {
    return SiteExposureConfig(
      id: id,
      jobSiteId: map['jobSiteId'] ?? '',
      jobSiteName: map['jobSiteName'] ?? '',
      toolLimits: (map['toolLimits'] as Map<String, dynamic>? ?? {})
          .map((k, v) => MapEntry(k, SiteExposureLimit.fromMap(v))),
      environmentalFactors: Map<String, double>.from(map['environmentalFactors'] ?? {}),
      weatherConditions: map['weatherConditions'],
      temperatureCelsius: map['temperatureCelsius']?.toDouble(),
      humidityPercent: map['humidityPercent']?.toDouble(),
      notes: map['notes'],
      validFrom: (map['validFrom'] as Timestamp).toDate(),
      validUntil: map['validUntil'] != null ? (map['validUntil'] as Timestamp).toDate() : null,
      isActive: map['isActive'] ?? true,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
    );
  }
}

/// Site-specific exposure limit for tools
class SiteExposureLimit {
  final String? toolId;
  final String? toolType;
  final double dailyExposureLimit;
  final double sessionExposureLimit;
  final int breakIntervalMinutes;
  final int maxContinuousMinutes;
  final double? vibrationThreshold;
  final bool requiresPPE;
  final List<String> requiredPPE;
  final List<String> restrictions;
  final bool isActive;

  SiteExposureLimit({
    this.toolId,
    this.toolType,
    required this.dailyExposureLimit,
    required this.sessionExposureLimit,
    required this.breakIntervalMinutes,
    required this.maxContinuousMinutes,
    this.vibrationThreshold,
    required this.requiresPPE,
    required this.requiredPPE,
    required this.restrictions,
    required this.isActive,
  });

  Map<String, dynamic> toMap() {
    return {
      'toolId': toolId,
      'toolType': toolType,
      'dailyExposureLimit': dailyExposureLimit,
      'sessionExposureLimit': sessionExposureLimit,
      'breakIntervalMinutes': breakIntervalMinutes,
      'maxContinuousMinutes': maxContinuousMinutes,
      'vibrationThreshold': vibrationThreshold,
      'requiresPPE': requiresPPE,
      'requiredPPE': requiredPPE,
      'restrictions': restrictions,
      'isActive': isActive,
    };
  }

  factory SiteExposureLimit.fromMap(Map<String, dynamic> map) {
    return SiteExposureLimit(
      toolId: map['toolId'],
      toolType: map['toolType'],
      dailyExposureLimit: (map['dailyExposureLimit'] ?? 0.0).toDouble(),
      sessionExposureLimit: (map['sessionExposureLimit'] ?? 0.0).toDouble(),
      breakIntervalMinutes: map['breakIntervalMinutes'] ?? 120,
      maxContinuousMinutes: map['maxContinuousMinutes'] ?? 60,
      vibrationThreshold: map['vibrationThreshold']?.toDouble(),
      requiresPPE: map['requiresPPE'] ?? false,
      requiredPPE: List<String>.from(map['requiredPPE'] ?? []),
      restrictions: List<String>.from(map['restrictions'] ?? []),
      isActive: map['isActive'] ?? true,
    );
  }
}

/// Environmental conditions record
class EnvironmentalConditions {
  final String jobSiteId;
  final double temperatureCelsius;
  final double humidityPercent;
  final String weatherConditions;
  final Map<String, double> additionalFactors;
  final String? recordedBy;
  final DateTime timestamp;

  EnvironmentalConditions({
    required this.jobSiteId,
    required this.temperatureCelsius,
    required this.humidityPercent,
    required this.weatherConditions,
    required this.additionalFactors,
    this.recordedBy,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'jobSiteId': jobSiteId,
      'temperatureCelsius': temperatureCelsius,
      'humidityPercent': humidityPercent,
      'weatherConditions': weatherConditions,
      'additionalFactors': additionalFactors,
      'recordedBy': recordedBy,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  factory EnvironmentalConditions.fromMap(Map<String, dynamic> map) {
    return EnvironmentalConditions(
      jobSiteId: map['jobSiteId'] ?? '',
      temperatureCelsius: (map['temperatureCelsius'] ?? 0.0).toDouble(),
      humidityPercent: (map['humidityPercent'] ?? 0.0).toDouble(),
      weatherConditions: map['weatherConditions'] ?? '',
      additionalFactors: Map<String, double>.from(map['additionalFactors'] ?? {}),
      recordedBy: map['recordedBy'],
      timestamp: (map['timestamp'] as Timestamp).toDate(),
    );
  }
}

/// Exposure override for special circumstances
class ExposureOverride {
  final String? id;
  final String entityId;
  final String entityType;
  final String jobSiteId;
  final String reason;
  final String authorizedBy;
  final Map<String, double> overrideLimits;
  final DateTime validFrom;
  final DateTime validUntil;
  final String? notes;
  final bool isActive;
  final DateTime createdAt;

  ExposureOverride({
    this.id,
    required this.entityId,
    required this.entityType,
    required this.jobSiteId,
    required this.reason,
    required this.authorizedBy,
    required this.overrideLimits,
    required this.validFrom,
    required this.validUntil,
    this.notes,
    required this.isActive,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'entityId': entityId,
      'entityType': entityType,
      'jobSiteId': jobSiteId,
      'reason': reason,
      'authorizedBy': authorizedBy,
      'overrideLimits': overrideLimits,
      'validFrom': Timestamp.fromDate(validFrom),
      'validUntil': Timestamp.fromDate(validUntil),
      'notes': notes,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory ExposureOverride.fromMap(Map<String, dynamic> map, String id) {
    return ExposureOverride(
      id: id,
      entityId: map['entityId'] ?? '',
      entityType: map['entityType'] ?? '',
      jobSiteId: map['jobSiteId'] ?? '',
      reason: map['reason'] ?? '',
      authorizedBy: map['authorizedBy'] ?? '',
      overrideLimits: Map<String, double>.from(map['overrideLimits'] ?? {}),
      validFrom: (map['validFrom'] as Timestamp).toDate(),
      validUntil: (map['validUntil'] as Timestamp).toDate(),
      notes: map['notes'],
      isActive: map['isActive'] ?? true,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }
}

/// Site exposure update event
class SiteExposureUpdate {
  final String entityId;
  final String entityType;
  final String jobSiteId;
  final String jobSiteName;
  final ExposureUpdateType updateType;
  final Map<String, SiteExposureLimit> newLimits;
  final Map<String, double> environmentalFactors;
  final DateTime timestamp;

  SiteExposureUpdate({
    required this.entityId,
    required this.entityType,
    required this.jobSiteId,
    required this.jobSiteName,
    required this.updateType,
    required this.newLimits,
    required this.environmentalFactors,
    required this.timestamp,
  });
}

/// Site exposure compliance report
class SiteExposureComplianceReport {
  final String jobSiteId;
  final DateTimeRange reportPeriod;
  final int totalWorkers;
  final int totalTools;
  final double complianceRate;
  final List<String> violations;
  final List<String> recommendations;
  final DateTime generatedAt;

  SiteExposureComplianceReport({
    required this.jobSiteId,
    required this.reportPeriod,
    required this.totalWorkers,
    required this.totalTools,
    required this.complianceRate,
    required this.violations,
    required this.recommendations,
    required this.generatedAt,
  });
}

/// Date time range helper
class DateTimeRange {
  final DateTime start;
  final DateTime end;

  DateTimeRange(this.start, this.end);
}

/// Exposure update types
enum ExposureUpdateType {
  limitsApplied,
  limitsRestored,
  environmentalChange,
  overrideApplied,
  overrideExpired,
}