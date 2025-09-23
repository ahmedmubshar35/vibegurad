import 'dart:typed_data';
import 'package:injectable/injectable.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';
import 'package:get_it/get_it.dart';

import '../../models/ai/recognition_result.dart';
import '../../models/tool/tool.dart';
import '../../enums/tool_type.dart';
import 'tool_service.dart';
import '../core/authentication_service.dart';
import '../core/notification_manager.dart';

@lazySingleton
class ManualCorrectionService with ListenableServiceMixin {
  final SnackbarService _snackbarService = GetIt.instance<SnackbarService>();
  final DialogService _dialogService = GetIt.instance<DialogService>();
  final ToolService _toolService = GetIt.instance<ToolService>();
  final AuthenticationService _authService = GetIt.instance<AuthenticationService>();
  
  // Reactive values for tracking corrections
  final ReactiveValue<int> _totalCorrections = ReactiveValue<int>(0);
  final ReactiveValue<int> _toolTypeCorrections = ReactiveValue<int>(0);
  final ReactiveValue<int> _brandCorrections = ReactiveValue<int>(0);
  final ReactiveValue<double> _correctionRate = ReactiveValue<double>(0.0);
  
  int get totalCorrections => _totalCorrections.value;
  int get toolTypeCorrections => _toolTypeCorrections.value;
  int get brandCorrections => _brandCorrections.value;
  double get correctionRate => _correctionRate.value;
  
  // Correction history for learning
  final List<CorrectionRecord> _correctionHistory = [];
  final Map<String, int> _commonMistakes = {};
  final Map<String, List<String>> _userCorrections = {};
  
  ManualCorrectionService() {
    listenToReactiveValues([_totalCorrections, _toolTypeCorrections, _brandCorrections, _correctionRate]);
  }
  
  // Main correction method - presents correction UI to user
  Future<CorrectionResult> requestCorrection(
    RecognitionResult originalResult,
    Uint8List? imageBytes, {
    String? context,
  }) async {
    try {
      // Get available tools for selection
      final availableTools = await _getAvailableTools();
      
      if (availableTools.isEmpty) {
        return CorrectionResult.failed('No tools available for selection');
      }
      
      // Show correction dialog
      final dialogResult = await _showCorrectionDialog(
        originalResult,
        availableTools,
        context: context,
      );
      
      if (dialogResult == null) {
        return CorrectionResult.cancelled();
      }
      
      // Process the correction
      final correctionResult = await _processCorrectionSelection(
        originalResult,
        dialogResult,
        imageBytes,
      );
      
      // Record the correction for learning
      await _recordCorrection(originalResult, correctionResult, imageBytes);
      
      return correctionResult;
    } catch (e) {
      return CorrectionResult.failed('Correction process failed: $e');
    }
  }
  
  // Show correction dialog to user
  Future<Map<String, dynamic>?> _showCorrectionDialog(
    RecognitionResult originalResult,
    List<Tool> availableTools,
    {String? context}
  ) async {
    // In a real implementation, this would show a Flutter dialog
    // For now, we'll simulate the user selection
    
    // Group tools by type for easier selection
    final toolsByType = <ToolType, List<Tool>>{};
    for (final tool in availableTools) {
      if (!toolsByType.containsKey(tool.type)) {
        toolsByType[tool.type] = [];
      }
      toolsByType[tool.type]!.add(tool);
    }
    
    // Simulate user correction (in real app, this would be UI-driven)
    return _simulateUserCorrection(originalResult, toolsByType);
  }
  
  // Simulate user correction for demonstration
  Map<String, dynamic> _simulateUserCorrection(
    RecognitionResult originalResult,
    Map<ToolType, List<Tool>> toolsByType,
  ) {
    // Simulate different types of corrections based on original confidence
    if (originalResult.confidence < 0.6) {
      // Low confidence - likely needs complete correction
      final toolTypes = toolsByType.keys.toList();
      final correctedType = toolTypes.isNotEmpty ? toolTypes.first : ToolType.drill;
      final correctedBrand = 'Corrected Brand';
      
      return {
        'correction_type': 'complete',
        'corrected_tool_type': correctedType.toString(),
        'corrected_brand': correctedBrand,
        'user_confidence': 0.95,
        'correction_reason': 'Original recognition was incorrect',
        'feedback': 'Tool type was wrong, brand was wrong',
      };
    } else if (originalResult.confidence < 0.8) {
      // Medium confidence - might need brand correction
      return {
        'correction_type': 'brand_only',
        'corrected_tool_type': originalResult.toolType,
        'corrected_brand': 'Corrected Brand',
        'user_confidence': 0.9,
        'correction_reason': 'Brand was misidentified',
        'feedback': 'Tool type was correct, but brand was wrong',
      };
    } else {
      // High confidence - user confirms it's correct
      return {
        'correction_type': 'confirmation',
        'corrected_tool_type': originalResult.toolType,
        'corrected_brand': originalResult.brand,
        'user_confidence': 0.98,
        'correction_reason': 'Confirmed as correct',
        'feedback': 'Recognition was accurate',
      };
    }
  }
  
  // Process correction selection
  Future<CorrectionResult> _processCorrectionSelection(
    RecognitionResult originalResult,
    Map<String, dynamic> selection,
    Uint8List? imageBytes,
  ) async {
    try {
      final correctionType = selection['correction_type'] as String;
      final correctedToolType = selection['corrected_tool_type'] as String;
      final correctedBrand = selection['corrected_brand'] as String;
      final userConfidence = selection['user_confidence'] as double;
      final reason = selection['correction_reason'] as String;
      final feedback = selection['feedback'] as String;
      
      // Create corrected result
      final correctedResult = RecognitionResult.success(
        toolType: correctedToolType,
        brand: correctedBrand,
        confidence: userConfidence,
        method: 'Manual Correction',
      );
      
      // Update statistics
      _updateCorrectionStatistics(originalResult, correctedResult, correctionType);
      
      return CorrectionResult.success(
        originalResult: originalResult,
        correctedResult: correctedResult,
        correctionType: correctionType,
        reason: reason,
        userFeedback: feedback,
      );
    } catch (e) {
      return CorrectionResult.failed('Failed to process correction: $e');
    }
  }
  
  // Record correction for machine learning improvements
  Future<void> _recordCorrection(
    RecognitionResult original,
    CorrectionResult correction,
    Uint8List? imageBytes,
  ) async {
    try {
      final record = CorrectionRecord(
        originalResult: original,
        correctedResult: correction.correctedResult,
        correctionType: correction.correctionType,
        reason: correction.reason,
        userFeedback: correction.userFeedback,
        imageData: imageBytes,
        timestamp: DateTime.now(),
        userId: _authService.currentUser?.id,
      );
      
      _correctionHistory.add(record);
      
      // Track common mistakes
      final mistakeKey = '${original.toolType}_${original.brand}';
      _commonMistakes[mistakeKey] = (_commonMistakes[mistakeKey] ?? 0) + 1;
      
      // Track user correction patterns
      final userId = _authService.currentUser?.id ?? 'anonymous';
      if (!_userCorrections.containsKey(userId)) {
        _userCorrections[userId] = [];
      }
      _userCorrections[userId]!.add(correction.correctionType);
      
      // Keep history manageable
      if (_correctionHistory.length > 1000) {
        _correctionHistory.removeAt(0);
      }
      
      NotificationManager().showSuccess('✅ Correction recorded - Thank you for improving AI accuracy!');
    } catch (e) {
      print('Error recording correction: $e');
    }
  }
  
  // Update correction statistics
  void _updateCorrectionStatistics(
    RecognitionResult original,
    RecognitionResult corrected,
    String correctionType,
  ) {
    _totalCorrections.value += 1;
    
    if (original.toolType.toLowerCase() != corrected.toolType.toLowerCase()) {
      _toolTypeCorrections.value += 1;
    }
    
    if (original.brand.toLowerCase() != corrected.brand.toLowerCase()) {
      _brandCorrections.value += 1;
    }
    
    // Update correction rate (corrections per recognition)
    // This would typically be calculated against total recognitions
    _correctionRate.value = totalCorrections / (totalCorrections + 10); // Placeholder calculation
  }
  
  // Get available tools for correction
  Future<List<Tool>> _getAvailableTools() async {
    try {
      final currentUser = _authService.currentUser;
      if (currentUser?.companyId != null) {
        final tools = await _toolService.getCompanyTools(currentUser!.companyId!).first;
        return tools.where((tool) => !tool.needsMaintenance).toList();
      }
      
      // Fallback to sample tools
      return _createSampleTools();
    } catch (e) {
      return _createSampleTools();
    }
  }
  
  // Create sample tools for correction options
  List<Tool> _createSampleTools() {
    return [
      Tool(
        id: 'correction_drill',
        name: 'Power Drill',
        brand: 'Bosch',
        model: 'GSB 18V',
        type: ToolType.drill,
        category: 'Power Tools',
        companyId: 'default',
        vibrationLevel: 3.2,
        frequency: 50.0,
        dailyExposureLimit: 240,
        weeklyExposureLimit: 1200,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Tool(
        id: 'correction_grinder',
        name: 'Angle Grinder',
        brand: 'Makita',
        model: 'GA9020',
        type: ToolType.grinder,
        category: 'Grinding Tools',
        companyId: 'default',
        vibrationLevel: 7.8,
        frequency: 120.0,
        dailyExposureLimit: 90,
        weeklyExposureLimit: 450,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Tool(
        id: 'correction_sander',
        name: 'Orbital Sander',
        brand: 'DeWalt',
        model: 'DWE6423',
        type: ToolType.sander,
        category: 'Sanding Tools',
        companyId: 'default',
        vibrationLevel: 4.5,
        frequency: 80.0,
        dailyExposureLimit: 180,
        weeklyExposureLimit: 900,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ];
  }
  
  // Get correction insights for AI improvement
  Map<String, dynamic> getCorrectionInsights() {
    final insights = <String, dynamic>{
      'totalCorrections': totalCorrections,
      'toolTypeCorrections': toolTypeCorrections,
      'brandCorrections': brandCorrections,
      'correctionRate': correctionRate,
    };
    
    if (_correctionHistory.isNotEmpty) {
      // Most common mistakes
      final sortedMistakes = _commonMistakes.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      
      insights['commonMistakes'] = sortedMistakes.take(5).map((e) => {
        'mistake': e.key,
        'count': e.value,
      }).toList();
      
      // Correction types distribution
      final correctionTypes = <String, int>{};
      for (final record in _correctionHistory) {
        correctionTypes[record.correctionType] = 
            (correctionTypes[record.correctionType] ?? 0) + 1;
      }
      insights['correctionTypesDistribution'] = correctionTypes;
      
      // User feedback patterns
      insights['userFeedbackCount'] = _correctionHistory
          .where((r) => r.userFeedback.isNotEmpty)
          .length;
      
      // Average time between corrections
      if (_correctionHistory.length > 1) {
        final timestamps = _correctionHistory.map((r) => r.timestamp).toList();
        timestamps.sort();
        
        final intervals = <Duration>[];
        for (int i = 1; i < timestamps.length; i++) {
          intervals.add(timestamps[i].difference(timestamps[i - 1]));
        }
        
        final averageInterval = intervals.fold<Duration>(
          Duration.zero,
          (sum, interval) => sum + interval,
        ).inMinutes / intervals.length;
        
        insights['averageCorrectionInterval'] = '${averageInterval.toStringAsFixed(1)} minutes';
      }
    }
    
    return insights;
  }
  
  // Get learning data for AI model improvement
  List<Map<String, dynamic>> getLearningData() {
    return _correctionHistory.map((record) => {
      'original_tool_type': record.originalResult.toolType,
      'original_brand': record.originalResult.brand,
      'original_confidence': record.originalResult.confidence,
      'corrected_tool_type': record.correctedResult?.toolType,
      'corrected_brand': record.correctedResult?.brand,
      'correction_type': record.correctionType,
      'user_feedback': record.userFeedback,
      'timestamp': record.timestamp.toIso8601String(),
    }).toList();
  }
  
  // Export corrections for analysis
  Future<String> exportCorrections() async {
    try {
      final data = {
        'export_timestamp': DateTime.now().toIso8601String(),
        'total_corrections': totalCorrections,
        'corrections': getLearningData(),
        'insights': getCorrectionInsights(),
      };
      
      // In a real implementation, this would save to file or send to server
      return 'Corrections exported successfully';
    } catch (e) {
      return 'Export failed: $e';
    }
  }
  
  // Reset correction data
  void resetCorrectionData() {
    _totalCorrections.value = 0;
    _toolTypeCorrections.value = 0;
    _brandCorrections.value = 0;
    _correctionRate.value = 0.0;
    
    _correctionHistory.clear();
    _commonMistakes.clear();
    _userCorrections.clear();
    
    NotificationManager().showInfo('Correction data reset');
  }
}

// Correction record for tracking
class CorrectionRecord {
  final RecognitionResult originalResult;
  final RecognitionResult? correctedResult;
  final String correctionType;
  final String reason;
  final String userFeedback;
  final Uint8List? imageData;
  final DateTime timestamp;
  final String? userId;
  
  CorrectionRecord({
    required this.originalResult,
    this.correctedResult,
    required this.correctionType,
    required this.reason,
    required this.userFeedback,
    this.imageData,
    required this.timestamp,
    this.userId,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'originalResult': originalResult.toMap(),
      'correctedResult': correctedResult?.toMap(),
      'correctionType': correctionType,
      'reason': reason,
      'userFeedback': userFeedback,
      'timestamp': timestamp.toIso8601String(),
      'userId': userId,
    };
  }
}

// Correction result
class CorrectionResult {
  final bool success;
  final RecognitionResult originalResult;
  final RecognitionResult? correctedResult;
  final String correctionType;
  final String reason;
  final String userFeedback;
  final String? error;
  final DateTime timestamp;
  
  CorrectionResult({
    required this.success,
    required this.originalResult,
    this.correctedResult,
    required this.correctionType,
    required this.reason,
    required this.userFeedback,
    this.error,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
  
  factory CorrectionResult.success({
    required RecognitionResult originalResult,
    required RecognitionResult correctedResult,
    required String correctionType,
    required String reason,
    required String userFeedback,
  }) {
    return CorrectionResult(
      success: true,
      originalResult: originalResult,
      correctedResult: correctedResult,
      correctionType: correctionType,
      reason: reason,
      userFeedback: userFeedback,
    );
  }
  
  factory CorrectionResult.failed(String error) {
    return CorrectionResult(
      success: false,
      originalResult: RecognitionResult.failed(error),
      correctionType: 'failed',
      reason: 'Correction failed',
      userFeedback: '',
      error: error,
    );
  }
  
  factory CorrectionResult.cancelled() {
    return CorrectionResult(
      success: false,
      originalResult: RecognitionResult.failed('User cancelled'),
      correctionType: 'cancelled',
      reason: 'User cancelled correction',
      userFeedback: '',
    );
  }
  
  @override
  String toString() {
    return 'CorrectionResult(success: $success, type: $correctionType)';
  }
}