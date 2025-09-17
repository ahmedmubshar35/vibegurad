// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tool.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Tool _$ToolFromJson(Map<String, dynamic> json) => Tool(
      id: json['id'] as String?,
      name: json['name'] as String,
      brand: json['brand'] as String,
      model: json['model'] as String,
      type: $enumDecode(_$ToolTypeEnumMap, json['type']),
      category: json['category'] as String,
      serialNumber: json['serialNumber'] as String?,
      companyId: json['companyId'] as String,
      locationId: json['locationId'] as String?,
      assignedWorkerId: json['assignedWorkerId'] as String?,
      vibrationLevel: (json['vibrationLevel'] as num).toDouble(),
      frequency: (json['frequency'] as num).toDouble(),
      dailyExposureLimit: (json['dailyExposureLimit'] as num).toInt(),
      weeklyExposureLimit: (json['weeklyExposureLimit'] as num).toInt(),
      imageUrl: json['imageUrl'] as String?,
      qrCode: json['qrCode'] as String?,
      isToolActive: json['toolActive'] as bool? ?? true,
      lastMaintenanceDate: json['lastMaintenanceDate'] == null
          ? null
          : DateTime.parse(json['lastMaintenanceDate'] as String),
      nextMaintenanceDate: json['nextMaintenanceDate'] == null
          ? null
          : DateTime.parse(json['nextMaintenanceDate'] as String),
      totalUsageHours: (json['totalUsageHours'] as num?)?.toDouble() ?? 0.0,
      specifications: json['specifications'] as Map<String, dynamic>?,
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
      isActive: json['isActive'] as bool? ?? true,
    );

Map<String, dynamic> _$ToolToJson(Tool instance) => <String, dynamic>{
      'id': instance.id,
      'createdAt': instance.createdAt?.toIso8601String(),
      'updatedAt': instance.updatedAt?.toIso8601String(),
      'isActive': instance.isActive,
      'name': instance.name,
      'brand': instance.brand,
      'model': instance.model,
      'type': _$ToolTypeEnumMap[instance.type]!,
      'category': instance.category,
      'serialNumber': instance.serialNumber,
      'companyId': instance.companyId,
      'locationId': instance.locationId,
      'assignedWorkerId': instance.assignedWorkerId,
      'vibrationLevel': instance.vibrationLevel,
      'frequency': instance.frequency,
      'dailyExposureLimit': instance.dailyExposureLimit,
      'weeklyExposureLimit': instance.weeklyExposureLimit,
      'imageUrl': instance.imageUrl,
      'qrCode': instance.qrCode,
      'toolActive': instance.isToolActive,
      'lastMaintenanceDate': instance.lastMaintenanceDate?.toIso8601String(),
      'nextMaintenanceDate': instance.nextMaintenanceDate?.toIso8601String(),
      'totalUsageHours': instance.totalUsageHours,
      'specifications': instance.specifications,
    };

const _$ToolTypeEnumMap = {
  ToolType.drill: 'drill',
  ToolType.grinder: 'grinder',
  ToolType.jackhammer: 'jackhammer',
  ToolType.saw: 'saw',
  ToolType.hammer: 'hammer',
  ToolType.sander: 'sander',
  ToolType.nailer: 'nailer',
  ToolType.compressor: 'compressor',
  ToolType.welder: 'welder',
  ToolType.other: 'other',
};
