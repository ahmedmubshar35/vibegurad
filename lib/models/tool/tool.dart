import 'package:json_annotation/json_annotation.dart';
import '../core/base_model.dart';
import '../../enums/tool_type.dart';
import '../../enums/exposure_level.dart';

part 'tool.g.dart';

@JsonSerializable()
class Tool extends BaseModel {
  @JsonKey(name: 'name')
  final String name;
  
  @JsonKey(name: 'brand')
  final String brand;
  
  @JsonKey(name: 'model')
  final String model;
  
  @JsonKey(name: 'type')
  final ToolType type;
  
  @JsonKey(name: 'category')
  final String category;
  
  @JsonKey(name: 'serialNumber')
  final String? serialNumber;
  
  @JsonKey(name: 'companyId')
  final String companyId;
  
  @JsonKey(name: 'locationId')
  final String? locationId;
  
  @JsonKey(name: 'assignedWorkerId')
  final String? assignedWorkerId;
  
  @JsonKey(name: 'vibrationLevel')
  final double vibrationLevel; // m/s²
  
  @JsonKey(name: 'frequency')
  final double frequency; // Hz
  
  @JsonKey(name: 'dailyExposureLimit')
  final int dailyExposureLimit; // minutes
  
  @JsonKey(name: 'weeklyExposureLimit')
  final int weeklyExposureLimit; // minutes
  
  @JsonKey(name: 'imageUrl')
  final String? imageUrl;
  
  @JsonKey(name: 'qrCode')
  final String? qrCode;
  
  @JsonKey(name: 'toolActive')
  final bool isToolActive;
  
  @JsonKey(name: 'lastMaintenanceDate')
  final DateTime? lastMaintenanceDate;
  
  @JsonKey(name: 'nextMaintenanceDate')
  final DateTime? nextMaintenanceDate;
  
  @JsonKey(name: 'totalUsageHours')
  final double totalUsageHours;
  
  @JsonKey(name: 'specifications')
  final Map<String, dynamic>? specifications;

  const Tool({
    super.id,
    required this.name,
    required this.brand,
    required this.model,
    required this.type,
    required this.category,
    this.serialNumber,
    required this.companyId,
    this.locationId,
    this.assignedWorkerId,
    required this.vibrationLevel,
    required this.frequency,
    required this.dailyExposureLimit,
    required this.weeklyExposureLimit,
    this.imageUrl,
    this.qrCode,
    this.isToolActive = true,
    this.lastMaintenanceDate,
    this.nextMaintenanceDate,
    this.totalUsageHours = 0.0,
    this.specifications,
    super.createdAt,
    super.updatedAt,
    super.isActive = true,
  });

  factory Tool.fromJson(Map<String, dynamic> json) =>

      _$ToolFromJson(json);
  
  @override
  Map<String, dynamic> toJson() => _$ToolToJson(this);

  @override
  Tool copyWith({
    String? id,
    String? name,
    String? brand,
    String? model,
    ToolType? type,
    String? category,
    String? serialNumber,
    String? companyId,
    String? locationId,
    String? assignedWorkerId,
    double? vibrationLevel,
    double? frequency,
    int? dailyExposureLimit,
    int? weeklyExposureLimit,
    String? imageUrl,
    String? qrCode,
    bool? isToolActive,
    DateTime? lastMaintenanceDate,
    DateTime? nextMaintenanceDate,
    double? totalUsageHours,
    Map<String, dynamic>? specifications,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
  }) {
    return Tool(
      id: id ?? this.id,
      name: name ?? this.name,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      type: type ?? this.type,
      category: category ?? this.category,
      serialNumber: serialNumber ?? this.serialNumber,
      companyId: companyId ?? this.companyId,
      locationId: locationId ?? this.locationId,
      assignedWorkerId: assignedWorkerId ?? this.assignedWorkerId,
      vibrationLevel: vibrationLevel ?? this.vibrationLevel,
      frequency: frequency ?? this.frequency,
      dailyExposureLimit: dailyExposureLimit ?? this.dailyExposureLimit,
      weeklyExposureLimit: weeklyExposureLimit ?? this.weeklyExposureLimit,
      imageUrl: imageUrl ?? this.imageUrl,
      qrCode: qrCode ?? this.qrCode,
      isToolActive: isToolActive ?? this.isToolActive,
      lastMaintenanceDate: lastMaintenanceDate ?? this.lastMaintenanceDate,
      nextMaintenanceDate: nextMaintenanceDate ?? this.nextMaintenanceDate,
      totalUsageHours: totalUsageHours ?? this.totalUsageHours,
      specifications: specifications ?? this.specifications,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Computed properties
  String get fullName => '$brand $name $model';
  
  String get displayName => '$brand $name';
  
  String get toolIdentifier => serialNumber ?? id ?? '';
  
  // Alias for vibrationLevel (for compatibility)
  double? get vibrationMagnitude => vibrationLevel;
  
  bool get isAssigned => assignedWorkerId != null && assignedWorkerId!.isNotEmpty;
  
  bool get needsMaintenance {
    if (nextMaintenanceDate == null) return false;
    return DateTime.now().isAfter(nextMaintenanceDate!);
  }
  
  bool get isOverdueMaintenance {
    if (nextMaintenanceDate == null) return false;
    return DateTime.now().isAfter(nextMaintenanceDate!.add(const Duration(days: 7)));
  }
  
  ExposureLevel get exposureLevel {
    if (vibrationLevel <= 2.5) return ExposureLevel.low;
    if (vibrationLevel <= 5.0) return ExposureLevel.medium;
    if (vibrationLevel <= 10.0) return ExposureLevel.high;
    return ExposureLevel.critical;
  }
  
  String get exposureLevelDescription {
    switch (exposureLevel) {
      case ExposureLevel.low:
        return 'Low risk - Safe for extended use';
      case ExposureLevel.medium:
        return 'Medium risk - Monitor usage time';
      case ExposureLevel.high:
        return 'High risk - Limit daily exposure';
      case ExposureLevel.critical:
        return 'Critical risk - Minimize usage';
    }
  }
  
  String get formattedVibrationLevel => '${vibrationLevel.toStringAsFixed(1)} m/s²';
  
  String get formattedFrequency => '${frequency.toStringAsFixed(0)} Hz';
  
  String get formattedDailyLimit => '${dailyExposureLimit} min/day';
  
  String get formattedWeeklyLimit => '${weeklyExposureLimit} min/week';
  
  String get formattedTotalUsage => '${totalUsageHours.toStringAsFixed(1)} hours';
  
  String get formattedLastMaintenance {
    if (lastMaintenanceDate == null) return 'Never';
    return '${lastMaintenanceDate!.day}/${lastMaintenanceDate!.month}/${lastMaintenanceDate!.year}';
  }
  
  String get formattedNextMaintenance {
    if (nextMaintenanceDate == null) return 'Not scheduled';
    return '${nextMaintenanceDate!.day}/${nextMaintenanceDate!.month}/${nextMaintenanceDate!.year}';
  }

  // Helper methods
  bool isSafeForDuration(int minutes) {
    return minutes <= dailyExposureLimit;
  }
  
  int getRemainingSafeTime(int usedMinutes) {
    return (dailyExposureLimit - usedMinutes).clamp(0, dailyExposureLimit);
  }
  
  double getRiskPercentage(int usedMinutes) {
    return (usedMinutes / dailyExposureLimit * 100).clamp(0, 100);
  }
  
  bool isHighRisk(int usedMinutes) {
    return getRiskPercentage(usedMinutes) >= 80;
  }
  
  bool isCriticalRisk(int usedMinutes) {
    return getRiskPercentage(usedMinutes) >= 100;
  }

  // Safety limit methods
  bool isNearLimit(int usedMinutes) {
    return getRiskPercentage(usedMinutes) >= 80;
  }

  bool isAtLimit(int usedMinutes) {
    return getRiskPercentage(usedMinutes) >= 100;
  }

  bool isOverLimit(int usedMinutes) {
    return getRiskPercentage(usedMinutes) > 100;
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'brand': brand,
      'model': model,
      'type': type.name,
      'category': category,
      'serialNumber': serialNumber,
      'companyId': companyId,
      'locationId': locationId,
      'assignedWorkerId': assignedWorkerId,
      'vibrationLevel': vibrationLevel,
      'frequency': frequency,
      'dailyExposureLimit': dailyExposureLimit,
      'weeklyExposureLimit': weeklyExposureLimit,
      'imageUrl': imageUrl,
      'qrCode': qrCode,
      'toolActive': isToolActive,
      'lastMaintenanceDate': lastMaintenanceDate?.toIso8601String(),
      'nextMaintenanceDate': nextMaintenanceDate?.toIso8601String(),
      'totalUsageHours': totalUsageHours,
      'specifications': specifications,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory Tool.fromFirestore(Map<String, dynamic> data, String id) {
    return Tool(
      id: id,
      name: data['name'] ?? '',
      brand: data['brand'] ?? '',
      model: data['model'] ?? '',
      type: ToolType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => ToolType.other,
      ),
      category: data['category'] ?? '',
      serialNumber: data['serialNumber'],
      companyId: data['companyId'] ?? '',
      locationId: data['locationId'],
      assignedWorkerId: data['assignedWorkerId'],
      vibrationLevel: (data['vibrationLevel'] ?? 0.0).toDouble(),
      frequency: (data['frequency'] ?? 0.0).toDouble(),
      dailyExposureLimit: data['dailyExposureLimit'] ?? 480,
      weeklyExposureLimit: data['weeklyExposureLimit'] ?? 2400,
      imageUrl: data['imageUrl'],
      qrCode: data['qrCode'],
      isToolActive: data['toolActive'] ?? true,
      lastMaintenanceDate: data['lastMaintenanceDate'] != null 
          ? DateTime.parse(data['lastMaintenanceDate']) 
          : null,
      nextMaintenanceDate: data['nextMaintenanceDate'] != null 
          ? DateTime.parse(data['nextMaintenanceDate']) 
          : null,
      totalUsageHours: (data['totalUsageHours'] ?? 0.0).toDouble(),
      specifications: data['specifications'],
      createdAt: data['createdAt'] != null 
          ? DateTime.parse(data['createdAt']) 
          : null,
      updatedAt: data['updatedAt'] != null 
          ? DateTime.parse(data['updatedAt']) 
          : null,
    );
  }
}
