import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/base_model.dart';

/// Tool inventory management models
class ToolInventory extends BaseModel {
  final String toolId;
  final String toolName;
  final String category;
  final String model;
  final String brand;
  final String serialNumber;
  final String barcode;
  final String qrCode;
  final ToolStatus status;
  final ToolCondition condition;
  final String currentLocation;
  final int quantity;
  final int minStockLevel;
  final String? assignedToWorkerId;
  final String? assignedToTeamId;
  final DateTime? lastInspection;
  final DateTime? nextServiceDue;
  final double acquisitionCost;
  final DateTime acquisitionDate;
  final List<String> tags;
  final Map<String, dynamic> specifications;
  final Map<String, dynamic> metadata;

  ToolInventory({
    super.id,
    required this.toolId,
    required this.toolName,
    required this.category,
    required this.model,
    required this.brand,
    required this.serialNumber,
    required this.barcode,
    required this.qrCode,
    required this.status,
    required this.condition,
    required this.currentLocation,
    required this.quantity,
    required this.minStockLevel,
    this.assignedToWorkerId,
    this.assignedToTeamId,
    this.lastInspection,
    this.nextServiceDue,
    required this.acquisitionCost,
    required this.acquisitionDate,
    required this.tags,
    required this.specifications,
    required this.metadata,
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
      'category': category,
      'model': model,
      'brand': brand,
      'serialNumber': serialNumber,
      'barcode': barcode,
      'qrCode': qrCode,
      'status': status.name,
      'condition': condition.name,
      'currentLocation': currentLocation,
      'quantity': quantity,
      'minStockLevel': minStockLevel,
      'assignedToWorkerId': assignedToWorkerId,
      'assignedToTeamId': assignedToTeamId,
      'lastInspection': lastInspection != null ? Timestamp.fromDate(lastInspection!) : null,
      'nextServiceDue': nextServiceDue != null ? Timestamp.fromDate(nextServiceDue!) : null,
      'acquisitionCost': acquisitionCost,
      'acquisitionDate': Timestamp.fromDate(acquisitionDate),
      'tags': tags,
      'specifications': specifications,
      'metadata': metadata,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
      'isActive': super.isActive,
    };
  }

  factory ToolInventory.fromFirestore(Map<String, dynamic> data, String id) {
    return ToolInventory(
      id: id,
      toolId: data['toolId'] ?? '',
      toolName: data['toolName'] ?? '',
      category: data['category'] ?? '',
      model: data['model'] ?? '',
      brand: data['brand'] ?? '',
      serialNumber: data['serialNumber'] ?? '',
      barcode: data['barcode'] ?? '',
      qrCode: data['qrCode'] ?? '',
      status: ToolStatus.fromString(data['status'] ?? 'available'),
      condition: ToolCondition.fromString(data['condition'] ?? 'good'),
      currentLocation: data['currentLocation'] ?? '',
      quantity: data['quantity'] ?? 1,
      minStockLevel: data['minStockLevel'] ?? 1,
      assignedToWorkerId: data['assignedToWorkerId'],
      assignedToTeamId: data['assignedToTeamId'],
      lastInspection: data['lastInspection'] != null 
          ? (data['lastInspection'] as Timestamp).toDate() 
          : null,
      nextServiceDue: data['nextServiceDue'] != null 
          ? (data['nextServiceDue'] as Timestamp).toDate() 
          : null,
      acquisitionCost: (data['acquisitionCost'] ?? 0.0).toDouble(),
      acquisitionDate: (data['acquisitionDate'] as Timestamp).toDate(),
      tags: List<String>.from(data['tags'] ?? []),
      specifications: data['specifications'] as Map<String, dynamic>? ?? {},
      metadata: data['metadata'] as Map<String, dynamic>? ?? {},
      createdAt: data['createdAt'] != null 
          ? (data['createdAt'] as Timestamp).toDate() 
          : null,
      updatedAt: data['updatedAt'] != null 
          ? (data['updatedAt'] as Timestamp).toDate() 
          : null,
      isActive: data['isActive'] ?? true,
    );
  }

  @override
  ToolInventory copyWith({
    String? id,
    String? toolId,
    String? toolName,
    String? category,
    String? model,
    String? brand,
    String? serialNumber,
    String? barcode,
    String? qrCode,
    ToolStatus? status,
    ToolCondition? condition,
    String? currentLocation,
    String? assignedToWorkerId,
    String? assignedToTeamId,
    DateTime? lastInspection,
    DateTime? nextServiceDue,
    double? acquisitionCost,
    DateTime? acquisitionDate,
    List<String>? tags,
    Map<String, dynamic>? specifications,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
  }) {
    return ToolInventory(
      id: id ?? this.id,
      toolId: toolId ?? this.toolId,
      toolName: toolName ?? this.toolName,
      category: category ?? this.category,
      model: model ?? this.model,
      brand: brand ?? this.brand,
      serialNumber: serialNumber ?? this.serialNumber,
      barcode: barcode ?? this.barcode,
      qrCode: qrCode ?? this.qrCode,
      status: status ?? this.status,
      condition: condition ?? this.condition,
      currentLocation: currentLocation ?? this.currentLocation,
      quantity: quantity ?? this.quantity,
      minStockLevel: minStockLevel ?? this.minStockLevel,
      assignedToWorkerId: assignedToWorkerId ?? this.assignedToWorkerId,
      assignedToTeamId: assignedToTeamId ?? this.assignedToTeamId,
      lastInspection: lastInspection ?? this.lastInspection,
      nextServiceDue: nextServiceDue ?? this.nextServiceDue,
      acquisitionCost: acquisitionCost ?? this.acquisitionCost,
      acquisitionDate: acquisitionDate ?? this.acquisitionDate,
      tags: tags ?? this.tags,
      specifications: specifications ?? this.specifications,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
    );
  }

  // Helper properties for ToolInventory
  bool get isOverdue {
    if (nextServiceDue == null) return false;
    return DateTime.now().isAfter(nextServiceDue!);
  }

  bool get isLowStock {
    return quantity <= minStockLevel;
  }
}

/// Check-in/Check-out system models
class ToolCheckout extends BaseModel {
  final String checkoutId;
  final String toolId;
  final String workerId;
  final String workerName;
  final String jobSiteId;
  final String jobSiteName;
  final String? teamId;
  final String? projectId;
  final DateTime checkoutTime;
  final DateTime? expectedReturnTime;
  final DateTime? actualReturnTime;
  final CheckoutStatus status;
  final String? checkoutNotes;
  final String? returnNotes;
  final ToolCondition? conditionAtCheckout;
  final ToolCondition? conditionAtReturn;
  final List<String> damagePhotos;
  final Map<String, dynamic> metadata;

  ToolCheckout({
    super.id,
    required this.checkoutId,
    required this.toolId,
    required this.workerId,
    required this.workerName,
    required this.jobSiteId,
    required this.jobSiteName,
    this.teamId,
    this.projectId,
    required this.checkoutTime,
    this.expectedReturnTime,
    this.actualReturnTime,
    required this.status,
    this.checkoutNotes,
    this.returnNotes,
    this.conditionAtCheckout,
    this.conditionAtReturn,
    required this.damagePhotos,
    required this.metadata,
    super.createdAt,
    super.updatedAt,
    super.isActive = true,
  });

  @override
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'checkoutId': checkoutId,
      'toolId': toolId,
      'workerId': workerId,
      'workerName': workerName,
      'jobSiteId': jobSiteId,
      'jobSiteName': jobSiteName,
      'teamId': teamId,
      'projectId': projectId,
      'checkoutTime': Timestamp.fromDate(checkoutTime),
      'expectedReturnTime': expectedReturnTime != null ? Timestamp.fromDate(expectedReturnTime!) : null,
      'actualReturnTime': actualReturnTime != null ? Timestamp.fromDate(actualReturnTime!) : null,
      'status': status.name,
      'checkoutNotes': checkoutNotes,
      'returnNotes': returnNotes,
      'conditionAtCheckout': conditionAtCheckout?.name,
      'conditionAtReturn': conditionAtReturn?.name,
      'damagePhotos': damagePhotos,
      'metadata': metadata,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
      'isActive': super.isActive,
    };
  }

  factory ToolCheckout.fromFirestore(Map<String, dynamic> data, String id) {
    return ToolCheckout(
      id: id,
      checkoutId: data['checkoutId'] ?? '',
      toolId: data['toolId'] ?? '',
      workerId: data['workerId'] ?? '',
      workerName: data['workerName'] ?? '',
      jobSiteId: data['jobSiteId'] ?? '',
      jobSiteName: data['jobSiteName'] ?? '',
      teamId: data['teamId'],
      projectId: data['projectId'],
      checkoutTime: (data['checkoutTime'] as Timestamp).toDate(),
      expectedReturnTime: data['expectedReturnTime'] != null 
          ? (data['expectedReturnTime'] as Timestamp).toDate() 
          : null,
      actualReturnTime: data['actualReturnTime'] != null 
          ? (data['actualReturnTime'] as Timestamp).toDate() 
          : null,
      status: CheckoutStatus.fromString(data['status'] ?? 'active'),
      checkoutNotes: data['checkoutNotes'],
      returnNotes: data['returnNotes'],
      conditionAtCheckout: data['conditionAtCheckout'] != null 
          ? ToolCondition.fromString(data['conditionAtCheckout']) 
          : null,
      conditionAtReturn: data['conditionAtReturn'] != null 
          ? ToolCondition.fromString(data['conditionAtReturn']) 
          : null,
      damagePhotos: List<String>.from(data['damagePhotos'] ?? []),
      metadata: data['metadata'] as Map<String, dynamic>? ?? {},
      createdAt: data['createdAt'] != null 
          ? (data['createdAt'] as Timestamp).toDate() 
          : null,
      updatedAt: data['updatedAt'] != null 
          ? (data['updatedAt'] as Timestamp).toDate() 
          : null,
      isActive: data['isActive'] ?? true,
    );
  }

  @override
  ToolCheckout copyWith({
    String? id,
    String? checkoutId,
    String? toolId,
    String? workerId,
    String? workerName,
    String? teamId,
    String? projectId,
    DateTime? checkoutTime,
    DateTime? expectedReturnTime,
    DateTime? actualReturnTime,
    CheckoutStatus? status,
    String? checkoutNotes,
    String? returnNotes,
    ToolCondition? conditionAtCheckout,
    ToolCondition? conditionAtReturn,
    List<String>? damagePhotos,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
  }) {
    return ToolCheckout(
      id: id ?? this.id,
      checkoutId: checkoutId ?? this.checkoutId,
      toolId: toolId ?? this.toolId,
      workerId: workerId ?? this.workerId,
      workerName: workerName ?? this.workerName,
      jobSiteId: jobSiteId ?? this.jobSiteId,
      jobSiteName: jobSiteName ?? this.jobSiteName,
      teamId: teamId ?? this.teamId,
      projectId: projectId ?? this.projectId,
      checkoutTime: checkoutTime ?? this.checkoutTime,
      expectedReturnTime: expectedReturnTime ?? this.expectedReturnTime,
      actualReturnTime: actualReturnTime ?? this.actualReturnTime,
      status: status ?? this.status,
      checkoutNotes: checkoutNotes ?? this.checkoutNotes,
      returnNotes: returnNotes ?? this.returnNotes,
      conditionAtCheckout: conditionAtCheckout ?? this.conditionAtCheckout,
      conditionAtReturn: conditionAtReturn ?? this.conditionAtReturn,
      damagePhotos: damagePhotos ?? this.damagePhotos,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
    );
  }

  /// Calculate checkout duration
  Duration get checkoutDuration {
    final endTime = actualReturnTime ?? DateTime.now();
    return endTime.difference(checkoutTime);
  }

  /// Check if tool is overdue
  bool get isOverdue {
    if (actualReturnTime != null || expectedReturnTime == null) return false;
    return DateTime.now().isAfter(expectedReturnTime!);
  }
}

/// Tool reservation system models
class ToolReservation extends BaseModel {
  final String reservationId;
  final String toolId;
  final String workerId;
  final String workerName;
  final String? teamId;
  final String? projectId;
  final DateTime reservationStart;
  final DateTime reservationEnd;
  final ReservationStatus status;
  final ReservationPriority priority;
  final String? purpose;
  final String? notes;
  final DateTime? approvedAt;
  final String? approvedBy;
  final DateTime? cancelledAt;
  final String? cancellationReason;
  final Map<String, dynamic> metadata;

  ToolReservation({
    super.id,
    required this.reservationId,
    required this.toolId,
    required this.workerId,
    required this.workerName,
    this.teamId,
    this.projectId,
    required this.reservationStart,
    required this.reservationEnd,
    required this.status,
    required this.priority,
    this.purpose,
    this.notes,
    this.approvedAt,
    this.approvedBy,
    this.cancelledAt,
    this.cancellationReason,
    required this.metadata,
    super.createdAt,
    super.updatedAt,
    super.isActive = true,
  });

  @override
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'reservationId': reservationId,
      'toolId': toolId,
      'workerId': workerId,
      'workerName': workerName,
      'teamId': teamId,
      'projectId': projectId,
      'reservationStart': Timestamp.fromDate(reservationStart),
      'reservationEnd': Timestamp.fromDate(reservationEnd),
      'status': status.name,
      'priority': priority.name,
      'purpose': purpose,
      'notes': notes,
      'approvedAt': approvedAt != null ? Timestamp.fromDate(approvedAt!) : null,
      'approvedBy': approvedBy,
      'cancelledAt': cancelledAt != null ? Timestamp.fromDate(cancelledAt!) : null,
      'cancellationReason': cancellationReason,
      'metadata': metadata,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
      'isActive': super.isActive,
    };
  }

  factory ToolReservation.fromFirestore(Map<String, dynamic> data, String id) {
    return ToolReservation(
      id: id,
      reservationId: data['reservationId'] ?? '',
      toolId: data['toolId'] ?? '',
      workerId: data['workerId'] ?? '',
      workerName: data['workerName'] ?? '',
      teamId: data['teamId'],
      projectId: data['projectId'],
      reservationStart: (data['reservationStart'] as Timestamp).toDate(),
      reservationEnd: (data['reservationEnd'] as Timestamp).toDate(),
      status: ReservationStatus.fromString(data['status'] ?? 'pending'),
      priority: ReservationPriority.fromString(data['priority'] ?? 'normal'),
      purpose: data['purpose'],
      notes: data['notes'],
      approvedAt: data['approvedAt'] != null 
          ? (data['approvedAt'] as Timestamp).toDate() 
          : null,
      approvedBy: data['approvedBy'],
      cancelledAt: data['cancelledAt'] != null 
          ? (data['cancelledAt'] as Timestamp).toDate() 
          : null,
      cancellationReason: data['cancellationReason'],
      metadata: data['metadata'] as Map<String, dynamic>? ?? {},
      createdAt: data['createdAt'] != null 
          ? (data['createdAt'] as Timestamp).toDate() 
          : null,
      updatedAt: data['updatedAt'] != null 
          ? (data['updatedAt'] as Timestamp).toDate() 
          : null,
      isActive: data['isActive'] ?? true,
    );
  }

  @override
  ToolReservation copyWith({
    String? id,
    String? reservationId,
    String? toolId,
    String? workerId,
    String? workerName,
    String? teamId,
    String? projectId,
    DateTime? reservationStart,
    DateTime? reservationEnd,
    ReservationStatus? status,
    ReservationPriority? priority,
    String? purpose,
    String? notes,
    DateTime? approvedAt,
    String? approvedBy,
    DateTime? cancelledAt,
    String? cancellationReason,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
  }) {
    return ToolReservation(
      id: id ?? this.id,
      reservationId: reservationId ?? this.reservationId,
      toolId: toolId ?? this.toolId,
      workerId: workerId ?? this.workerId,
      workerName: workerName ?? this.workerName,
      teamId: teamId ?? this.teamId,
      projectId: projectId ?? this.projectId,
      reservationStart: reservationStart ?? this.reservationStart,
      reservationEnd: reservationEnd ?? this.reservationEnd,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      purpose: purpose ?? this.purpose,
      notes: notes ?? this.notes,
      approvedAt: approvedAt ?? this.approvedAt,
      approvedBy: approvedBy ?? this.approvedBy,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
    );
  }

  /// Get reservation duration
  Duration get duration => reservationEnd.difference(reservationStart);

  /// Check if reservation is active now
  bool get isActiveNow {
    final now = DateTime.now();
    return status == ReservationStatus.approved &&
           now.isAfter(reservationStart) &&
           now.isBefore(reservationEnd);
  }

  /// Check if reservation is upcoming
  bool get isUpcoming {
    return status == ReservationStatus.approved &&
           DateTime.now().isBefore(reservationStart);
  }
}

/// Tool condition reporting models
class ToolConditionReport extends BaseModel {
  final String reportId;
  final String toolId;
  final String reportedByWorkerId;
  final String reportedByWorkerName;
  final DateTime reportDate;
  final ToolCondition condition;
  final List<String> issues;
  final String description;
  final List<String> photos;
  final ReportSeverity severity;
  final bool requiresImmediate;
  final String? actionTaken;
  final String? actionTakenBy;
  final DateTime? actionTakenDate;
  final double? estimatedRepairCost;
  final Map<String, dynamic> metadata;

  ToolConditionReport({
    super.id,
    required this.reportId,
    required this.toolId,
    required this.reportedByWorkerId,
    required this.reportedByWorkerName,
    required this.reportDate,
    required this.condition,
    required this.issues,
    required this.description,
    required this.photos,
    required this.severity,
    required this.requiresImmediate,
    this.actionTaken,
    this.actionTakenBy,
    this.actionTakenDate,
    this.estimatedRepairCost,
    required this.metadata,
    super.createdAt,
    super.updatedAt,
    super.isActive = true,
  });

  @override
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'reportId': reportId,
      'toolId': toolId,
      'reportedByWorkerId': reportedByWorkerId,
      'reportedByWorkerName': reportedByWorkerName,
      'reportDate': Timestamp.fromDate(reportDate),
      'condition': condition.name,
      'issues': issues,
      'description': description,
      'photos': photos,
      'severity': severity.name,
      'requiresImmediate': requiresImmediate,
      'actionTaken': actionTaken,
      'actionTakenBy': actionTakenBy,
      'actionTakenDate': actionTakenDate != null ? Timestamp.fromDate(actionTakenDate!) : null,
      'estimatedRepairCost': estimatedRepairCost,
      'metadata': metadata,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
      'isActive': super.isActive,
    };
  }

  factory ToolConditionReport.fromFirestore(Map<String, dynamic> data, String id) {
    return ToolConditionReport(
      id: id,
      reportId: data['reportId'] ?? '',
      toolId: data['toolId'] ?? '',
      reportedByWorkerId: data['reportedByWorkerId'] ?? '',
      reportedByWorkerName: data['reportedByWorkerName'] ?? '',
      reportDate: (data['reportDate'] as Timestamp).toDate(),
      condition: ToolCondition.fromString(data['condition'] ?? 'good'),
      issues: List<String>.from(data['issues'] ?? []),
      description: data['description'] ?? '',
      photos: List<String>.from(data['photos'] ?? []),
      severity: ReportSeverity.fromString(data['severity'] ?? 'low'),
      requiresImmediate: data['requiresImmediate'] ?? false,
      actionTaken: data['actionTaken'],
      actionTakenBy: data['actionTakenBy'],
      actionTakenDate: data['actionTakenDate'] != null 
          ? (data['actionTakenDate'] as Timestamp).toDate() 
          : null,
      estimatedRepairCost: data['estimatedRepairCost']?.toDouble(),
      metadata: data['metadata'] as Map<String, dynamic>? ?? {},
      createdAt: data['createdAt'] != null 
          ? (data['createdAt'] as Timestamp).toDate() 
          : null,
      updatedAt: data['updatedAt'] != null 
          ? (data['updatedAt'] as Timestamp).toDate() 
          : null,
      isActive: data['isActive'] ?? true,
    );
  }

  @override
  ToolConditionReport copyWith({
    String? id,
    String? reportId,
    String? toolId,
    String? reportedByWorkerId,
    String? reportedByWorkerName,
    DateTime? reportDate,
    ToolCondition? condition,
    List<String>? issues,
    String? description,
    List<String>? photos,
    ReportSeverity? severity,
    bool? requiresImmediate,
    String? actionTaken,
    String? actionTakenBy,
    DateTime? actionTakenDate,
    double? estimatedRepairCost,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
  }) {
    return ToolConditionReport(
      id: id ?? this.id,
      reportId: reportId ?? this.reportId,
      toolId: toolId ?? this.toolId,
      reportedByWorkerId: reportedByWorkerId ?? this.reportedByWorkerId,
      reportedByWorkerName: reportedByWorkerName ?? this.reportedByWorkerName,
      reportDate: reportDate ?? this.reportDate,
      condition: condition ?? this.condition,
      issues: issues ?? this.issues,
      description: description ?? this.description,
      photos: photos ?? this.photos,
      severity: severity ?? this.severity,
      requiresImmediate: requiresImmediate ?? this.requiresImmediate,
      actionTaken: actionTaken ?? this.actionTaken,
      actionTakenBy: actionTakenBy ?? this.actionTakenBy,
      actionTakenDate: actionTakenDate ?? this.actionTakenDate,
      estimatedRepairCost: estimatedRepairCost ?? this.estimatedRepairCost,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
    );
  }
}

/// Tool performance tracking models
class ToolPerformanceMetric extends BaseModel {
  final String metricId;
  final String toolId;
  final String metricType; // 'efficiency', 'accuracy', 'speed', 'quality'
  final double value;
  final String unit;
  final DateTime recordedDate;
  final String? recordedByWorkerId;
  final String? sessionId;
  final Map<String, dynamic> context;
  final Map<String, dynamic> metadata;

  ToolPerformanceMetric({
    super.id,
    required this.metricId,
    required this.toolId,
    required this.metricType,
    required this.value,
    required this.unit,
    required this.recordedDate,
    this.recordedByWorkerId,
    this.sessionId,
    required this.context,
    required this.metadata,
    super.createdAt,
    super.updatedAt,
    super.isActive = true,
  });

  @override
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'metricId': metricId,
      'toolId': toolId,
      'metricType': metricType,
      'value': value,
      'unit': unit,
      'recordedDate': Timestamp.fromDate(recordedDate),
      'recordedByWorkerId': recordedByWorkerId,
      'sessionId': sessionId,
      'context': context,
      'metadata': metadata,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
      'isActive': super.isActive,
    };
  }

  factory ToolPerformanceMetric.fromFirestore(Map<String, dynamic> data, String id) {
    return ToolPerformanceMetric(
      id: id,
      metricId: data['metricId'] ?? '',
      toolId: data['toolId'] ?? '',
      metricType: data['metricType'] ?? '',
      value: (data['value'] ?? 0.0).toDouble(),
      unit: data['unit'] ?? '',
      recordedDate: (data['recordedDate'] as Timestamp).toDate(),
      recordedByWorkerId: data['recordedByWorkerId'],
      sessionId: data['sessionId'],
      context: data['context'] as Map<String, dynamic>? ?? {},
      metadata: data['metadata'] as Map<String, dynamic>? ?? {},
      createdAt: data['createdAt'] != null 
          ? (data['createdAt'] as Timestamp).toDate() 
          : null,
      updatedAt: data['updatedAt'] != null 
          ? (data['updatedAt'] as Timestamp).toDate() 
          : null,
      isActive: data['isActive'] ?? true,
    );
  }

  @override
  ToolPerformanceMetric copyWith({
    String? id,
    String? metricId,
    String? toolId,
    String? metricType,
    double? value,
    String? unit,
    DateTime? recordedDate,
    String? recordedByWorkerId,
    String? sessionId,
    Map<String, dynamic>? context,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
  }) {
    return ToolPerformanceMetric(
      id: id ?? this.id,
      metricId: metricId ?? this.metricId,
      toolId: toolId ?? this.toolId,
      metricType: metricType ?? this.metricType,
      value: value ?? this.value,
      unit: unit ?? this.unit,
      recordedDate: recordedDate ?? this.recordedDate,
      recordedByWorkerId: recordedByWorkerId ?? this.recordedByWorkerId,
      sessionId: sessionId ?? this.sessionId,
      context: context ?? this.context,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
    );
  }
}

/// Tool warranty tracking models
class ToolWarranty extends BaseModel {
  final String warrantyId;
  final String toolId;
  final String warrantyProvider;
  final String warrantyType; // 'manufacturer', 'extended', 'service'
  final DateTime startDate;
  final DateTime endDate;
  final String? warrantyNumber;
  final double coverageAmount;
  final List<String> coveredComponents;
  final List<String> exclusions;
  final String? documentPath;
  final Map<String, dynamic> terms;
  final Map<String, dynamic> metadata;

  ToolWarranty({
    super.id,
    required this.warrantyId,
    required this.toolId,
    required this.warrantyProvider,
    required this.warrantyType,
    required this.startDate,
    required this.endDate,
    this.warrantyNumber,
    required this.coverageAmount,
    required this.coveredComponents,
    required this.exclusions,
    this.documentPath,
    required this.terms,
    required this.metadata,
    super.createdAt,
    super.updatedAt,
    super.isActive = true,
  });

  @override
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'warrantyId': warrantyId,
      'toolId': toolId,
      'warrantyProvider': warrantyProvider,
      'warrantyType': warrantyType,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'warrantyNumber': warrantyNumber,
      'coverageAmount': coverageAmount,
      'coveredComponents': coveredComponents,
      'exclusions': exclusions,
      'documentPath': documentPath,
      'terms': terms,
      'metadata': metadata,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
      'isActive': super.isActive,
    };
  }

  factory ToolWarranty.fromFirestore(Map<String, dynamic> data, String id) {
    return ToolWarranty(
      id: id,
      warrantyId: data['warrantyId'] ?? '',
      toolId: data['toolId'] ?? '',
      warrantyProvider: data['warrantyProvider'] ?? '',
      warrantyType: data['warrantyType'] ?? '',
      startDate: (data['startDate'] as Timestamp).toDate(),
      endDate: (data['endDate'] as Timestamp).toDate(),
      warrantyNumber: data['warrantyNumber'],
      coverageAmount: (data['coverageAmount'] ?? 0.0).toDouble(),
      coveredComponents: List<String>.from(data['coveredComponents'] ?? []),
      exclusions: List<String>.from(data['exclusions'] ?? []),
      documentPath: data['documentPath'],
      terms: data['terms'] as Map<String, dynamic>? ?? {},
      metadata: data['metadata'] as Map<String, dynamic>? ?? {},
      createdAt: data['createdAt'] != null 
          ? (data['createdAt'] as Timestamp).toDate() 
          : null,
      updatedAt: data['updatedAt'] != null 
          ? (data['updatedAt'] as Timestamp).toDate() 
          : null,
      isActive: data['isActive'] ?? true,
    );
  }

  @override
  ToolWarranty copyWith({
    String? id,
    String? warrantyId,
    String? toolId,
    String? warrantyProvider,
    String? warrantyType,
    DateTime? startDate,
    DateTime? endDate,
    String? warrantyNumber,
    double? coverageAmount,
    List<String>? coveredComponents,
    List<String>? exclusions,
    String? documentPath,
    Map<String, dynamic>? terms,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
  }) {
    return ToolWarranty(
      id: id ?? this.id,
      warrantyId: warrantyId ?? this.warrantyId,
      toolId: toolId ?? this.toolId,
      warrantyProvider: warrantyProvider ?? this.warrantyProvider,
      warrantyType: warrantyType ?? this.warrantyType,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      warrantyNumber: warrantyNumber ?? this.warrantyNumber,
      coverageAmount: coverageAmount ?? this.coverageAmount,
      coveredComponents: coveredComponents ?? this.coveredComponents,
      exclusions: exclusions ?? this.exclusions,
      documentPath: documentPath ?? this.documentPath,
      terms: terms ?? this.terms,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
    );
  }

  /// Check if warranty is currently active
  @override
  bool get isActive {
    final now = DateTime.now();
    return now.isAfter(startDate) && now.isBefore(endDate);
  }

  /// Get days until warranty expires
  int get daysUntilExpiry {
    final now = DateTime.now();
    if (now.isAfter(endDate)) return -1; // Expired
    return endDate.difference(now).inDays;
  }

  /// Check if warranty is expiring soon (within 30 days)
  bool get isExpiringSoon => daysUntilExpiry >= 0 && daysUntilExpiry <= 30;
}

/// Tool service history models
class ToolServiceRecord extends BaseModel {
  final String serviceId;
  final String toolId;
  final DateTime serviceDate;
  final ServiceType serviceType;
  final String serviceProvider;
  final String? technicianName;
  final String description;
  final List<String> workPerformed;
  final List<String> partsReplaced;
  final double laborCost;
  final double partsCost;
  final double totalCost;
  final String? invoiceNumber;
  final String? warrantyInfo;
  final DateTime? nextServiceDue;
  final List<String> documents;
  final Map<String, dynamic> metadata;

  ToolServiceRecord({
    super.id,
    required this.serviceId,
    required this.toolId,
    required this.serviceDate,
    required this.serviceType,
    required this.serviceProvider,
    this.technicianName,
    required this.description,
    required this.workPerformed,
    required this.partsReplaced,
    required this.laborCost,
    required this.partsCost,
    required this.totalCost,
    this.invoiceNumber,
    this.warrantyInfo,
    this.nextServiceDue,
    required this.documents,
    required this.metadata,
    super.createdAt,
    super.updatedAt,
    super.isActive = true,
  });

  @override
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'serviceId': serviceId,
      'toolId': toolId,
      'serviceDate': Timestamp.fromDate(serviceDate),
      'serviceType': serviceType.name,
      'serviceProvider': serviceProvider,
      'technicianName': technicianName,
      'description': description,
      'workPerformed': workPerformed,
      'partsReplaced': partsReplaced,
      'laborCost': laborCost,
      'partsCost': partsCost,
      'totalCost': totalCost,
      'invoiceNumber': invoiceNumber,
      'warrantyInfo': warrantyInfo,
      'nextServiceDue': nextServiceDue != null ? Timestamp.fromDate(nextServiceDue!) : null,
      'documents': documents,
      'metadata': metadata,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
      'isActive': super.isActive,
    };
  }

  factory ToolServiceRecord.fromFirestore(Map<String, dynamic> data, String id) {
    return ToolServiceRecord(
      id: id,
      serviceId: data['serviceId'] ?? '',
      toolId: data['toolId'] ?? '',
      serviceDate: (data['serviceDate'] as Timestamp).toDate(),
      serviceType: ServiceType.fromString(data['serviceType'] ?? 'maintenance'),
      serviceProvider: data['serviceProvider'] ?? '',
      technicianName: data['technicianName'],
      description: data['description'] ?? '',
      workPerformed: List<String>.from(data['workPerformed'] ?? []),
      partsReplaced: List<String>.from(data['partsReplaced'] ?? []),
      laborCost: (data['laborCost'] ?? 0.0).toDouble(),
      partsCost: (data['partsCost'] ?? 0.0).toDouble(),
      totalCost: (data['totalCost'] ?? 0.0).toDouble(),
      invoiceNumber: data['invoiceNumber'],
      warrantyInfo: data['warrantyInfo'],
      nextServiceDue: data['nextServiceDue'] != null 
          ? (data['nextServiceDue'] as Timestamp).toDate() 
          : null,
      documents: List<String>.from(data['documents'] ?? []),
      metadata: data['metadata'] as Map<String, dynamic>? ?? {},
      createdAt: data['createdAt'] != null 
          ? (data['createdAt'] as Timestamp).toDate() 
          : null,
      updatedAt: data['updatedAt'] != null 
          ? (data['updatedAt'] as Timestamp).toDate() 
          : null,
      isActive: data['isActive'] ?? true,
    );
  }

  @override
  ToolServiceRecord copyWith({
    String? id,
    String? serviceId,
    String? toolId,
    DateTime? serviceDate,
    ServiceType? serviceType,
    String? serviceProvider,
    String? technicianName,
    String? description,
    List<String>? workPerformed,
    List<String>? partsReplaced,
    double? laborCost,
    double? partsCost,
    double? totalCost,
    String? invoiceNumber,
    String? warrantyInfo,
    DateTime? nextServiceDue,
    List<String>? documents,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
  }) {
    return ToolServiceRecord(
      id: id ?? this.id,
      serviceId: serviceId ?? this.serviceId,
      toolId: toolId ?? this.toolId,
      serviceDate: serviceDate ?? this.serviceDate,
      serviceType: serviceType ?? this.serviceType,
      serviceProvider: serviceProvider ?? this.serviceProvider,
      technicianName: technicianName ?? this.technicianName,
      description: description ?? this.description,
      workPerformed: workPerformed ?? this.workPerformed,
      partsReplaced: partsReplaced ?? this.partsReplaced,
      laborCost: laborCost ?? this.laborCost,
      partsCost: partsCost ?? this.partsCost,
      totalCost: totalCost ?? this.totalCost,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      warrantyInfo: warrantyInfo ?? this.warrantyInfo,
      nextServiceDue: nextServiceDue ?? this.nextServiceDue,
      documents: documents ?? this.documents,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
    );
  }
}

/// Tool cost tracking models
class ToolCostRecord extends BaseModel {
  final String costId;
  final String toolId;
  final DateTime date;
  final CostType costType;
  final String category;
  final String description;
  final double amount;
  final String? vendor;
  final String? invoiceNumber;
  final String? receiptPath;
  final String? approvedBy;
  final Map<String, dynamic> metadata;

  ToolCostRecord({
    super.id,
    required this.costId,
    required this.toolId,
    required this.date,
    required this.costType,
    required this.category,
    required this.description,
    required this.amount,
    this.vendor,
    this.invoiceNumber,
    this.receiptPath,
    this.approvedBy,
    required this.metadata,
    super.createdAt,
    super.updatedAt,
    super.isActive = true,
  });

  @override
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'costId': costId,
      'toolId': toolId,
      'date': Timestamp.fromDate(date),
      'costType': costType.name,
      'category': category,
      'description': description,
      'amount': amount,
      'vendor': vendor,
      'invoiceNumber': invoiceNumber,
      'receiptPath': receiptPath,
      'approvedBy': approvedBy,
      'metadata': metadata,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
      'isActive': super.isActive,
    };
  }

  factory ToolCostRecord.fromFirestore(Map<String, dynamic> data, String id) {
    return ToolCostRecord(
      id: id,
      costId: data['costId'] ?? '',
      toolId: data['toolId'] ?? '',
      date: (data['date'] as Timestamp).toDate(),
      costType: CostType.fromString(data['costType'] ?? 'operational'),
      category: data['category'] ?? '',
      description: data['description'] ?? '',
      amount: (data['amount'] ?? 0.0).toDouble(),
      vendor: data['vendor'],
      invoiceNumber: data['invoiceNumber'],
      receiptPath: data['receiptPath'],
      approvedBy: data['approvedBy'],
      metadata: data['metadata'] as Map<String, dynamic>? ?? {},
      createdAt: data['createdAt'] != null 
          ? (data['createdAt'] as Timestamp).toDate() 
          : null,
      updatedAt: data['updatedAt'] != null 
          ? (data['updatedAt'] as Timestamp).toDate() 
          : null,
      isActive: data['isActive'] ?? true,
    );
  }

  @override
  ToolCostRecord copyWith({
    String? id,
    String? costId,
    String? toolId,
    DateTime? date,
    CostType? costType,
    String? category,
    String? description,
    double? amount,
    String? vendor,
    String? invoiceNumber,
    String? receiptPath,
    String? approvedBy,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
  }) {
    return ToolCostRecord(
      id: id ?? this.id,
      costId: costId ?? this.costId,
      toolId: toolId ?? this.toolId,
      date: date ?? this.date,
      costType: costType ?? this.costType,
      category: category ?? this.category,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      vendor: vendor ?? this.vendor,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      receiptPath: receiptPath ?? this.receiptPath,
      approvedBy: approvedBy ?? this.approvedBy,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
    );
  }
}

/// Enumerations
enum ToolStatus {
  available,
  checkedOut,
  reserved,
  maintenance,
  repair,
  outOfService,
  retired;

  static ToolStatus fromString(String value) {
    return ToolStatus.values.firstWhere(
      (status) => status.name == value.toLowerCase(),
      orElse: () => ToolStatus.available,
    );
  }
}

enum ToolCondition {
  excellent,
  good,
  fair,
  poor,
  damaged,
  needsRepair;

  static ToolCondition fromString(String value) {
    return ToolCondition.values.firstWhere(
      (condition) => condition.name == value.toLowerCase(),
      orElse: () => ToolCondition.good,
    );
  }
}

enum CheckoutStatus {
  active,
  returned,
  overdue,
  lost,
  damaged;

  static CheckoutStatus fromString(String value) {
    return CheckoutStatus.values.firstWhere(
      (status) => status.name == value.toLowerCase(),
      orElse: () => CheckoutStatus.active,
    );
  }
}

enum ReservationStatus {
  pending,
  approved,
  active,
  completed,
  cancelled,
  expired;

  static ReservationStatus fromString(String value) {
    return ReservationStatus.values.firstWhere(
      (status) => status.name == value.toLowerCase(),
      orElse: () => ReservationStatus.pending,
    );
  }
}

enum ReservationPriority {
  low,
  normal,
  high,
  urgent;

  static ReservationPriority fromString(String value) {
    return ReservationPriority.values.firstWhere(
      (priority) => priority.name == value.toLowerCase(),
      orElse: () => ReservationPriority.normal,
    );
  }
}

enum ReportSeverity {
  low,
  medium,
  high,
  critical;

  static ReportSeverity fromString(String value) {
    return ReportSeverity.values.firstWhere(
      (severity) => severity.name == value.toLowerCase(),
      orElse: () => ReportSeverity.low,
    );
  }
}

enum ServiceType {
  maintenance,
  repair,
  calibration,
  inspection,
  upgrade,
  warranty;

  static ServiceType fromString(String value) {
    return ServiceType.values.firstWhere(
      (type) => type.name == value.toLowerCase(),
      orElse: () => ServiceType.maintenance,
    );
  }
}

enum CostType {
  acquisition,
  operational,
  maintenance,
  repair,
  upgrade,
  depreciation,
  insurance,
  storage;

  static CostType fromString(String value) {
    return CostType.values.firstWhere(
      (type) => type.name == value.toLowerCase(),
      orElse: () => CostType.operational,
    );
  }
}

enum WarrantyStatus {
  active,
  expired,
  claimed,
  cancelled;

  static WarrantyStatus fromString(String value) {
    return WarrantyStatus.values.firstWhere(
      (status) => status.name == value.toLowerCase(),
      orElse: () => WarrantyStatus.active,
    );
  }
}

enum WarrantyType {
  manufacturer,
  extended,
  service;

  static WarrantyType fromString(String value) {
    return WarrantyType.values.firstWhere(
      (type) => type.name == value.toLowerCase(),
      orElse: () => WarrantyType.manufacturer,
    );
  }
}

enum ServiceStatus {
  scheduled,
  inProgress,
  completed,
  cancelled;

  static ServiceStatus fromString(String value) {
    return ServiceStatus.values.firstWhere(
      (status) => status.name == value.toLowerCase(),
      orElse: () => ServiceStatus.scheduled,
    );
  }
}

enum PerformanceMetricType {
  efficiency,
  accuracy,
  speed,
  quality,
  uptime,
  reliability;

  static PerformanceMetricType fromString(String value) {
    return PerformanceMetricType.values.firstWhere(
      (type) => type.name == value.toLowerCase(),
      orElse: () => PerformanceMetricType.efficiency,
    );
  }
}

enum CostCategory {
  purchase,
  maintenance,
  repair,
  upgrade,
  consumables,
  labor;

  static CostCategory fromString(String value) {
    return CostCategory.values.firstWhere(
      (category) => category.name == value.toLowerCase(),
      orElse: () => CostCategory.purchase,
    );
  }
}