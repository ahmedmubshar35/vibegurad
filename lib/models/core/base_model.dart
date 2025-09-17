import 'package:json_annotation/json_annotation.dart';

abstract class BaseModel {
  @JsonKey(name: 'id')
  final String? id;
  
  @JsonKey(name: 'createdAt')
  final DateTime? createdAt;
  
  @JsonKey(name: 'updatedAt')
  final DateTime? updatedAt;
  
  @JsonKey(name: 'isActive')
  final bool isActive;

  const BaseModel({
    this.id,
    this.createdAt,
    this.updatedAt,
    this.isActive = true,
  });

  // Abstract method that subclasses must implement
  Map<String, dynamic> toJson();
  
  // Factory constructor for JSON deserialization
  factory BaseModel.fromJson(Map<String, dynamic> json) {
    throw UnimplementedError('Subclasses must implement fromJson');
  }

  // Copy with method for immutable updates
  BaseModel copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
  });

  // Helper method to get formatted creation date
  String get formattedCreatedAt {
    if (createdAt == null) return 'Unknown';
    return '${createdAt!.day}/${createdAt!.month}/${createdAt!.year}';
  }

  // Helper method to get formatted updated date
  String get formattedUpdatedAt {
    if (updatedAt == null) return 'Never';
    return '${updatedAt!.day}/${updatedAt!.month}/${updatedAt!.year}';
  }

  // Helper method to check if model is new (no ID)
  bool get isNew => id == null || id!.isEmpty;

  // Helper method to check if model was created today
  bool get isCreatedToday {
    if (createdAt == null) return false;
    final now = DateTime.now();
    return createdAt!.year == now.year &&
           createdAt!.month == now.month &&
           createdAt!.day == now.day;
  }

  // Helper method to get age of the model in days
  int get ageInDays {
    if (createdAt == null) return 0;
    final now = DateTime.now();
    return now.difference(createdAt!).inDays;
  }
}
