class RecognitionResult {
  final bool success;
  final String toolType;
  final String brand;
  final double confidence;
  final String method;
  final String? error;
  final int? angleIndex;
  final int? multipleImages;
  final DateTime timestamp;
  
  RecognitionResult({
    required this.success,
    required this.toolType,
    required this.brand,
    required this.confidence,
    required this.method,
    this.error,
    this.angleIndex,
    this.multipleImages,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
  
  // Success constructor
  factory RecognitionResult.success({
    required String toolType,
    required String brand,
    required double confidence,
    required String method,
    int? angleIndex,
    int? multipleImages,
  }) {
    return RecognitionResult(
      success: true,
      toolType: toolType,
      brand: brand,
      confidence: confidence,
      method: method,
      angleIndex: angleIndex,
      multipleImages: multipleImages,
    );
  }
  
  // Failed constructor
  factory RecognitionResult.failed(String error) {
    return RecognitionResult(
      success: false,
      toolType: 'unknown',
      brand: 'unknown',
      confidence: 0.0,
      method: 'failed',
      error: error,
    );
  }
  
  // Convert to display string
  String get displayText {
    if (!success) {
      return 'Recognition Failed: ${error ?? 'Unknown error'}';
    }
    
    final confidencePercent = (confidence * 100).toStringAsFixed(1);
    return '$brand $toolType (${confidencePercent}% confidence)';
  }
  
  // Convert to map for storage/serialization
  Map<String, dynamic> toMap() {
    return {
      'success': success,
      'toolType': toolType,
      'brand': brand,
      'confidence': confidence,
      'method': method,
      'error': error,
      'angleIndex': angleIndex,
      'multipleImages': multipleImages,
      'timestamp': timestamp.toIso8601String(),
    };
  }
  
  // Create from map
  factory RecognitionResult.fromMap(Map<String, dynamic> map) {
    return RecognitionResult(
      success: map['success'] ?? false,
      toolType: map['toolType'] ?? 'unknown',
      brand: map['brand'] ?? 'unknown',
      confidence: map['confidence']?.toDouble() ?? 0.0,
      method: map['method'] ?? 'unknown',
      error: map['error'],
      angleIndex: map['angleIndex'],
      multipleImages: map['multipleImages'],
      timestamp: DateTime.tryParse(map['timestamp'] ?? '') ?? DateTime.now(),
    );
  }
  
  @override
  String toString() {
    return 'RecognitionResult(success: $success, toolType: $toolType, brand: $brand, confidence: $confidence, method: $method)';
  }
}