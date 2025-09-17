import '../core/base_model.dart';
import '../../enums/timer_status.dart';
import '../tool/tool.dart';

class TimerSession extends BaseModel {
  final String workerId;
  final String toolId;
  final Tool? tool;
  final TimerStatus status;
  final DateTime startTime;
  final DateTime? endTime;
  final DateTime? pauseTime;
  final DateTime? resumeTime;
  final int totalPauseDuration; // in seconds
  final String? locationId;
  final double? latitude;
  final double? longitude;
  final String? notes;
  final bool isEmergencyStop;
  final String? emergencyStopReason;
  final List<String> warningsTriggered;
  final List<String> alertsTriggered;

  const TimerSession({
    super.id,
    required this.workerId,
    required this.toolId,
    this.tool,
    required this.status,
    required this.startTime,
    this.endTime,
    this.pauseTime,
    this.resumeTime,
    this.totalPauseDuration = 0,
    this.locationId,
    this.latitude,
    this.longitude,
    this.notes,
    this.isEmergencyStop = false,
    this.emergencyStopReason,
    this.warningsTriggered = const [],
    this.alertsTriggered = const [],
    super.createdAt,
    super.updatedAt,
    super.isActive,
  });

  factory TimerSession.fromJson(Map<String, dynamic> json) {
    return TimerSession.fromFirestore(json, json['id'] ?? '');
  }
  
  @override
  Map<String, dynamic> toJson() => toFirestore();

  @override
  TimerSession copyWith({
    String? id,
    String? workerId,
    String? toolId,
    Tool? tool,
    TimerStatus? status,
    DateTime? startTime,
    DateTime? endTime,
    DateTime? pauseTime,
    DateTime? resumeTime,
    int? totalPauseDuration,
    String? locationId,
    double? latitude,
    double? longitude,
    String? notes,
    bool? isEmergencyStop,
    String? emergencyStopReason,
    List<String>? warningsTriggered,
    List<String>? alertsTriggered,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
  }) {
    return TimerSession(
      id: id ?? this.id,
      workerId: workerId ?? this.workerId,
      toolId: toolId ?? this.toolId,
      tool: tool ?? this.tool,
      status: status ?? this.status,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      pauseTime: pauseTime ?? this.pauseTime,
      resumeTime: resumeTime ?? this.resumeTime,
      totalPauseDuration: totalPauseDuration ?? this.totalPauseDuration,
      locationId: locationId ?? this.locationId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      notes: notes ?? this.notes,
      isEmergencyStop: isEmergencyStop ?? this.isEmergencyStop,
      emergencyStopReason: emergencyStopReason ?? this.emergencyStopReason,
      warningsTriggered: warningsTriggered ?? this.warningsTriggered,
      alertsTriggered: alertsTriggered ?? this.alertsTriggered,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
    );
  }

  // Computed properties
  @override
  bool get isActive => status == TimerStatus.active;
  
  bool get isPaused => status == TimerStatus.paused;
  
  bool get isCompleted => status == TimerStatus.completed;
  
  bool get isStopped => status == TimerStatus.stopped;
  
  DateTime get effectiveEndTime => endTime ?? DateTime.now();
  
  Duration get totalDuration {
    final end = effectiveEndTime;
    return end.difference(startTime) - Duration(seconds: totalPauseDuration);
  }
  
  int get totalMinutes => totalDuration.inMinutes;
  
  int get totalSeconds => totalDuration.inSeconds;
  
  String get formattedDuration {
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    final seconds = totalSeconds % 60;
    
    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }
  
  String get formattedStartTime {
    return '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';
  }
  
  String get formattedEndTime {
    if (endTime == null) return 'Ongoing';
    return '${endTime!.hour.toString().padLeft(2, '0')}:${endTime!.minute.toString().padLeft(2, '0')}';
  }
  
  String get formattedDate {
    return '${startTime.day}/${startTime.month}/${startTime.year}';
  }
  
  bool get hasLocation => latitude != null && longitude != null;
  
  bool get hasWarnings => warningsTriggered.isNotEmpty;
  
  bool get hasAlerts => alertsTriggered.isNotEmpty;
  
  bool get isEmergencyStopped => isEmergencyStop;
  
  // Alias getters for compatibility
  List<String> get warnings => warningsTriggered;
  List<String> get alerts => alertsTriggered;

  // Helper methods
  TimerSession pause() {
    if (status != TimerStatus.active) return this;
    return copyWith(
      status: TimerStatus.paused,
      pauseTime: DateTime.now(),
    );
  }
  
  TimerSession resume() {
    if (status != TimerStatus.paused) return this;
    final pauseDuration = DateTime.now().difference(pauseTime!).inSeconds;
    return copyWith(
      status: TimerStatus.active,
      resumeTime: DateTime.now(),
      totalPauseDuration: totalPauseDuration + pauseDuration,
    );
  }
  
  TimerSession stop({String? reason}) {
    if (status == TimerStatus.completed || status == TimerStatus.stopped) return this;
    return copyWith(
      status: TimerStatus.completed,
      endTime: DateTime.now(),
      notes: reason != null ? '${notes ?? ''}\nStopped: $reason'.trim() : notes,
    );
  }
  
  TimerSession emergencyStop(String reason) {
    return copyWith(
      status: TimerStatus.stopped,
      endTime: DateTime.now(),
      isEmergencyStop: true,
      emergencyStopReason: reason,
      alertsTriggered: [...alertsTriggered, 'Emergency Stop: $reason'],
    );
  }
  
  TimerSession addWarning(String warning) {
    return copyWith(
      warningsTriggered: [...warningsTriggered, warning],
    );
  }
  
  TimerSession addAlert(String alert) {
    return copyWith(
      alertsTriggered: [...alertsTriggered, alert],
    );
  }
  
  bool isNearLimit(int limitMinutes) {
    return totalMinutes >= (limitMinutes * 0.8); // 80% of limit
  }
  
  bool isAtLimit(int limitMinutes) {
    return totalMinutes >= limitMinutes;
  }
  
  bool isOverLimit(int limitMinutes) {
    return totalMinutes > limitMinutes;
  }
  
  int getRemainingTime(int limitMinutes) {
    return (limitMinutes - totalMinutes).clamp(0, limitMinutes);
  }
  
  double getUsagePercentage(int limitMinutes) {
    return (totalMinutes / limitMinutes * 100).clamp(0, 100);
  }

  Map<String, dynamic> toFirestore() {
    return {
      'workerId': workerId,
      'toolId': toolId,
      'status': status.name,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'pauseTime': pauseTime?.toIso8601String(),
      'resumeTime': resumeTime?.toIso8601String(),
      'totalPauseDuration': totalPauseDuration,
      'locationId': locationId,
      'latitude': latitude,
      'longitude': longitude,
      'notes': notes,
      'isEmergencyStop': isEmergencyStop,
      'emergencyStopReason': emergencyStopReason,
      'warningsTriggered': warningsTriggered,
      'alertsTriggered': alertsTriggered,
      'isActive': isActive,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory TimerSession.fromFirestore(Map<String, dynamic> data, String id) {
    return TimerSession(
      id: id,
      workerId: data['workerId'] ?? '',
      toolId: data['toolId'] ?? '',
      status: TimerStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => TimerStatus.active,
      ),
      startTime: DateTime.parse(data['startTime']),
      endTime: data['endTime'] != null ? DateTime.parse(data['endTime']) : null,
      pauseTime: data['pauseTime'] != null ? DateTime.parse(data['pauseTime']) : null,
      resumeTime: data['resumeTime'] != null ? DateTime.parse(data['resumeTime']) : null,
      totalPauseDuration: data['totalPauseDuration'] ?? 0,
      locationId: data['locationId'],
      latitude: data['latitude']?.toDouble(),
      longitude: data['longitude']?.toDouble(),
      notes: data['notes'],
      isEmergencyStop: data['isEmergencyStop'] ?? false,
      emergencyStopReason: data['emergencyStopReason'],
      warningsTriggered: List<String>.from(data['warningsTriggered'] ?? []),
      alertsTriggered: List<String>.from(data['alertsTriggered'] ?? []),
      isActive: data['isActive'] ?? true,
      createdAt: data['createdAt'] != null ? DateTime.parse(data['createdAt']) : null,
      updatedAt: data['updatedAt'] != null ? DateTime.parse(data['updatedAt']) : null,
    );
  }
}
