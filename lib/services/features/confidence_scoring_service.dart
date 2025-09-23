import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:injectable/injectable.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';
import 'package:get_it/get_it.dart';

import '../../models/ai/recognition_result.dart';
import '../../models/ai/tool_image_database.dart';
import '../../models/tool/tool.dart';
import '../../enums/tool_type.dart';
import '../core/notification_manager.dart';

@lazySingleton
class ConfidenceScoringService with ListenableServiceMixin {
  final SnackbarService _snackbarService = GetIt.instance<SnackbarService>();
  
  // Confidence thresholds
  static const double EXCELLENT_THRESHOLD = 0.95;
  static const double GOOD_THRESHOLD = 0.85;
  static const double FAIR_THRESHOLD = 0.70;
  static const double POOR_THRESHOLD = 0.50;
  
  // Reactive values for tracking
  final ReactiveValue<double> _averageConfidence = ReactiveValue<double>(0.0);
  final ReactiveValue<int> _totalRecognitions = ReactiveValue<int>(0);
  final ReactiveValue<int> _highConfidenceCount = ReactiveValue<int>(0);
  
  double get averageConfidence => _averageConfidence.value;
  int get totalRecognitions => _totalRecognitions.value;
  int get highConfidenceCount => _highConfidenceCount.value;
  double get highConfidenceRate => totalRecognitions > 0 ? highConfidenceCount / totalRecognitions : 0.0;
  
  // History for tracking performance
  final List<RecognitionResult> _recognitionHistory = [];
  final List<double> _confidenceHistory = [];
  
  ConfidenceScoringService() {
    listenToReactiveValues([_averageConfidence, _totalRecognitions, _highConfidenceCount]);
  }
  
  // Calculate comprehensive confidence score
  ConfidenceScore calculateConfidenceScore(
    RecognitionResult primaryResult, {
    List<RecognitionResult>? alternativeResults,
    Map<String, dynamic>? imageQualityMetrics,
    Map<String, dynamic>? environmentalFactors,
  }) {
    try {
      double baseConfidence = primaryResult.confidence;
      double adjustedConfidence = baseConfidence;
      List<String> factors = [];
      List<String> recommendations = [];
      
      // Factor 1: Multi-method consensus (30% weight)
      if (alternativeResults != null && alternativeResults.isNotEmpty) {
        final consensus = _calculateMethodConsensus(primaryResult, alternativeResults);
        adjustedConfidence = _weightedAdjustment(adjustedConfidence, consensus.score, 0.3);
        factors.addAll(consensus.factors);
        recommendations.addAll(consensus.recommendations);
      }
      
      // Factor 2: Image quality assessment (25% weight)
      if (imageQualityMetrics != null) {
        final quality = _assessImageQuality(imageQualityMetrics);
        adjustedConfidence = _weightedAdjustment(adjustedConfidence, quality.score, 0.25);
        factors.addAll(quality.factors);
        recommendations.addAll(quality.recommendations);
      }
      
      // Factor 3: Environmental conditions (20% weight)
      if (environmentalFactors != null) {
        final environmental = _assessEnvironmentalFactors(environmentalFactors);
        adjustedConfidence = _weightedAdjustment(adjustedConfidence, environmental.score, 0.20);
        factors.addAll(environmental.factors);
        recommendations.addAll(environmental.recommendations);
      }
      
      // Factor 4: Database validation (15% weight)
      final database = _validateAgainstDatabase(primaryResult);
      adjustedConfidence = _weightedAdjustment(adjustedConfidence, database.score, 0.15);
      factors.addAll(database.factors);
      recommendations.addAll(database.recommendations);
      
      // Factor 5: Historical performance (10% weight)
      final historical = _assessHistoricalPerformance(primaryResult);
      adjustedConfidence = _weightedAdjustment(adjustedConfidence, historical.score, 0.10);
      factors.addAll(historical.factors);
      recommendations.addAll(historical.recommendations);
      
      // Clamp confidence to valid range
      adjustedConfidence = math.max(0.0, math.min(1.0, adjustedConfidence));
      
      // Update statistics
      _updateStatistics(adjustedConfidence);
      
      return ConfidenceScore(
        originalConfidence: baseConfidence,
        adjustedConfidence: adjustedConfidence,
        confidenceLevel: _getConfidenceLevel(adjustedConfidence),
        factors: factors,
        recommendations: recommendations,
        isReliable: adjustedConfidence >= FAIR_THRESHOLD,
        timestamp: DateTime.now(),
      );
    } catch (e) {
      return ConfidenceScore.error('Confidence calculation failed: $e');
    }
  }
  
  // Calculate method consensus
  _ConsensusResult _calculateMethodConsensus(
    RecognitionResult primary,
    List<RecognitionResult> alternatives,
  ) {
    double consensusScore = 0.0;
    List<String> factors = [];
    List<String> recommendations = [];
    
    int agreementCount = 0;
    int totalMethods = alternatives.length + 1;
    
    // Check tool type agreement
    for (final alt in alternatives) {
      if (alt.toolType.toLowerCase() == primary.toolType.toLowerCase()) {
        agreementCount++;
      }
    }
    
    final toolAgreement = agreementCount / alternatives.length;
    
    // Check brand agreement
    int brandAgreementCount = 0;
    for (final alt in alternatives) {
      if (alt.brand.toLowerCase() == primary.brand.toLowerCase()) {
        brandAgreementCount++;
      }
    }
    
    final brandAgreement = brandAgreementCount / alternatives.length;
    
    // Calculate overall consensus
    consensusScore = (toolAgreement + brandAgreement) / 2;
    
    if (consensusScore > 0.8) {
      factors.add('Strong consensus across recognition methods');
    } else if (consensusScore > 0.6) {
      factors.add('Moderate consensus across recognition methods');
      recommendations.add('Consider taking additional photos for better accuracy');
    } else {
      factors.add('Low consensus across recognition methods');
      recommendations.add('Results may be unreliable - try different angles or lighting');
    }
    
    return _ConsensusResult(consensusScore, factors, recommendations);
  }
  
  // Assess image quality impact on confidence
  _QualityResult _assessImageQuality(Map<String, dynamic> metrics) {
    double qualityScore = 0.0;
    List<String> factors = [];
    List<String> recommendations = [];
    
    // Brightness assessment
    final brightness = metrics['brightness'] as double? ?? 0.5;
    if (brightness > 0.2 && brightness < 0.8) {
      qualityScore += 0.3;
      factors.add('Good brightness level');
    } else {
      factors.add('Poor brightness level');
      recommendations.add(brightness < 0.2 ? 'Increase lighting' : 'Reduce lighting');
    }
    
    // Sharpness assessment
    final sharpness = metrics['sharpness'] as double? ?? 0.5;
    if (sharpness > 0.7) {
      qualityScore += 0.3;
      factors.add('Sharp image quality');
    } else {
      factors.add('Blurry image detected');
      recommendations.add('Hold camera steady and ensure focus');
    }
    
    // Contrast assessment
    final contrast = metrics['contrast'] as double? ?? 0.5;
    if (contrast > 0.6) {
      qualityScore += 0.2;
      factors.add('Good image contrast');
    } else {
      factors.add('Low image contrast');
      recommendations.add('Improve lighting conditions');
    }
    
    // Resolution assessment
    final resolution = metrics['resolution'] as int? ?? 1000000; // 1MP default
    if (resolution > 2000000) { // 2MP+
      qualityScore += 0.2;
      factors.add('High resolution image');
    } else {
      factors.add('Low resolution image');
      recommendations.add('Use higher resolution camera setting');
    }
    
    return _QualityResult(qualityScore, factors, recommendations);
  }
  
  // Assess environmental factors
  _EnvironmentalResult _assessEnvironmentalFactors(Map<String, dynamic> factors) {
    double envScore = 0.0;
    List<String> factorList = [];
    List<String> recommendations = [];
    
    // Lighting conditions
    final lightingQuality = factors['lighting_quality'] as double? ?? 0.5;
    if (lightingQuality > 0.7) {
      envScore += 0.4;
      factorList.add('Excellent lighting conditions');
    } else if (lightingQuality > 0.5) {
      envScore += 0.2;
      factorList.add('Fair lighting conditions');
    } else {
      factorList.add('Poor lighting conditions');
      recommendations.add('Move to better lit area or add lighting');
    }
    
    // Background clutter
    final backgroundClutter = factors['background_clutter'] as double? ?? 0.5;
    if (backgroundClutter < 0.3) {
      envScore += 0.3;
      factorList.add('Clean background');
    } else {
      factorList.add('Cluttered background detected');
      recommendations.add('Use plain background or better positioning');
    }
    
    // Tool visibility
    final toolVisibility = factors['tool_visibility'] as double? ?? 0.5;
    if (toolVisibility > 0.8) {
      envScore += 0.3;
      factorList.add('Tool clearly visible');
    } else {
      factorList.add('Tool partially obscured');
      recommendations.add('Ensure full tool visibility in frame');
    }
    
    return _EnvironmentalResult(envScore, factorList, recommendations);
  }
  
  // Validate against tool database
  _DatabaseResult _validateAgainstDatabase(RecognitionResult result) {
    double dbScore = 0.0;
    List<String> factors = [];
    List<String> recommendations = [];
    
    try {
      final toolType = ToolType.fromString(result.toolType);
      final dbEntry = ToolImageDatabase.getEntry(toolType);
      
      if (dbEntry != null) {
        // Check if result matches expected patterns
        final matchesKeywords = dbEntry.keywords.any((keyword) => 
          keyword.toLowerCase().contains(result.toolType.toLowerCase()));
        
        final matchesBrand = dbEntry.brandColors.containsKey(result.brand);
        
        if (matchesKeywords && matchesBrand) {
          dbScore = 0.9;
          factors.add('Result matches database patterns perfectly');
        } else if (matchesKeywords || matchesBrand) {
          dbScore = 0.7;
          factors.add('Result partially matches database patterns');
        } else {
          dbScore = 0.3;
          factors.add('Result does not match expected patterns');
          recommendations.add('Verify tool identification manually');
        }
        
        // Check vibration level consistency
        final expectedVibration = ToolImageDatabase.getExpectedVibration(toolType, 'medium');
        if (expectedVibration > 0) {
          factors.add('Vibration data available in database');
        }
      } else {
        dbScore = 0.5;
        factors.add('Tool type not found in database');
        recommendations.add('Consider updating tool database');
      }
    } catch (e) {
      dbScore = 0.2;
      factors.add('Database validation failed');
    }
    
    return _DatabaseResult(dbScore, factors, recommendations);
  }
  
  // Assess historical performance
  _HistoricalResult _assessHistoricalPerformance(RecognitionResult result) {
    double historicalScore = 0.0;
    List<String> factors = [];
    List<String> recommendations = [];
    
    if (_recognitionHistory.isEmpty) {
      historicalScore = 0.5;
      factors.add('No historical data available');
      return _HistoricalResult(historicalScore, factors, recommendations);
    }
    
    // Calculate average confidence for this tool type
    final sameTypeResults = _recognitionHistory
        .where((r) => r.toolType.toLowerCase() == result.toolType.toLowerCase())
        .toList();
    
    if (sameTypeResults.isNotEmpty) {
      final avgConfidence = sameTypeResults
          .map((r) => r.confidence)
          .reduce((a, b) => a + b) / sameTypeResults.length;
      
      if (result.confidence >= avgConfidence) {
        historicalScore = 0.8;
        factors.add('Confidence above historical average');
      } else {
        historicalScore = 0.6;
        factors.add('Confidence below historical average');
        recommendations.add('Consider retaking photo for better results');
      }
    }
    
    // Check for consistency in brand recognition
    final sameBrandResults = _recognitionHistory
        .where((r) => r.brand.toLowerCase() == result.brand.toLowerCase())
        .toList();
    
    if (sameBrandResults.length >= 3) {
      factors.add('Consistent brand recognition pattern');
    }
    
    return _HistoricalResult(historicalScore, factors, recommendations);
  }
  
  // Apply weighted adjustment to confidence
  double _weightedAdjustment(double currentConfidence, double factor, double weight) {
    return currentConfidence + (factor - currentConfidence) * weight;
  }
  
  // Get confidence level description
  String _getConfidenceLevel(double confidence) {
    if (confidence >= EXCELLENT_THRESHOLD) return 'Excellent';
    if (confidence >= GOOD_THRESHOLD) return 'Good';
    if (confidence >= FAIR_THRESHOLD) return 'Fair';
    if (confidence >= POOR_THRESHOLD) return 'Poor';
    return 'Very Poor';
  }
  
  // Update internal statistics
  void _updateStatistics(double confidence) {
    _totalRecognitions.value += 1;
    _confidenceHistory.add(confidence);
    
    if (confidence >= GOOD_THRESHOLD) {
      _highConfidenceCount.value += 1;
    }
    
    // Calculate running average
    _averageConfidence.value = _confidenceHistory
        .reduce((a, b) => a + b) / _confidenceHistory.length;
    
    // Keep history manageable
    if (_confidenceHistory.length > 1000) {
      _confidenceHistory.removeAt(0);
    }
  }
  
  // Record recognition result for historical analysis
  void recordRecognition(RecognitionResult result) {
    _recognitionHistory.add(result);
    
    // Keep history manageable
    if (_recognitionHistory.length > 500) {
      _recognitionHistory.removeAt(0);
    }
  }
  
  // Get confidence statistics
  Map<String, dynamic> getConfidenceStatistics() {
    final stats = <String, dynamic>{
      'averageConfidence': averageConfidence,
      'totalRecognitions': totalRecognitions,
      'highConfidenceCount': highConfidenceCount,
      'highConfidenceRate': highConfidenceRate,
    };
    
    if (_confidenceHistory.isNotEmpty) {
      stats['minConfidence'] = _confidenceHistory.reduce(math.min);
      stats['maxConfidence'] = _confidenceHistory.reduce(math.max);
      
      // Calculate confidence distribution
      int excellent = 0, good = 0, fair = 0, poor = 0, veryPoor = 0;
      for (final confidence in _confidenceHistory) {
        if (confidence >= EXCELLENT_THRESHOLD) excellent++;
        else if (confidence >= GOOD_THRESHOLD) good++;
        else if (confidence >= FAIR_THRESHOLD) fair++;
        else if (confidence >= POOR_THRESHOLD) poor++;
        else veryPoor++;
      }
      
      stats['confidenceDistribution'] = {
        'excellent': excellent,
        'good': good,
        'fair': fair,
        'poor': poor,
        'veryPoor': veryPoor,
      };
    }
    
    return stats;
  }
  
  // Reset statistics
  void resetStatistics() {
    _averageConfidence.value = 0.0;
    _totalRecognitions.value = 0;
    _highConfidenceCount.value = 0;
    _confidenceHistory.clear();
    _recognitionHistory.clear();
    
    NotificationManager().showInfo('Confidence statistics reset');
  }
}

// Helper classes for organizing results
class _ConsensusResult {
  final double score;
  final List<String> factors;
  final List<String> recommendations;
  
  _ConsensusResult(this.score, this.factors, this.recommendations);
}

class _QualityResult {
  final double score;
  final List<String> factors;
  final List<String> recommendations;
  
  _QualityResult(this.score, this.factors, this.recommendations);
}

class _EnvironmentalResult {
  final double score;
  final List<String> factors;
  final List<String> recommendations;
  
  _EnvironmentalResult(this.score, this.factors, this.recommendations);
}

class _DatabaseResult {
  final double score;
  final List<String> factors;
  final List<String> recommendations;
  
  _DatabaseResult(this.score, this.factors, this.recommendations);
}

class _HistoricalResult {
  final double score;
  final List<String> factors;
  final List<String> recommendations;
  
  _HistoricalResult(this.score, this.factors, this.recommendations);
}

// Main confidence score result
class ConfidenceScore {
  final double originalConfidence;
  final double adjustedConfidence;
  final String confidenceLevel;
  final List<String> factors;
  final List<String> recommendations;
  final bool isReliable;
  final DateTime timestamp;
  final String? error;
  
  ConfidenceScore({
    required this.originalConfidence,
    required this.adjustedConfidence,
    required this.confidenceLevel,
    required this.factors,
    required this.recommendations,
    required this.isReliable,
    required this.timestamp,
    this.error,
  });
  
  factory ConfidenceScore.error(String error) {
    return ConfidenceScore(
      originalConfidence: 0.0,
      adjustedConfidence: 0.0,
      confidenceLevel: 'Error',
      factors: ['Error in confidence calculation'],
      recommendations: ['Please try again'],
      isReliable: false,
      timestamp: DateTime.now(),
      error: error,
    );
  }
  
  // Get confidence as percentage
  String get confidencePercentage => '${(adjustedConfidence * 100).toStringAsFixed(1)}%';
  
  // Get improvement from original
  double get improvement => adjustedConfidence - originalConfidence;
  
  // Check if confidence improved
  bool get isImproved => improvement > 0.01;
  
  // Get color for UI display
  Color get confidenceColor {
    if (adjustedConfidence >= 0.95) return Color(0xFF4CAF50); // Green
    if (adjustedConfidence >= 0.85) return Color(0xFF8BC34A); // Light Green
    if (adjustedConfidence >= 0.70) return Color(0xFFFFC107); // Amber
    if (adjustedConfidence >= 0.50) return Color(0xFFFF9800); // Orange
    return Color(0xFFF44336); // Red
  }
  
  // Convert to map for serialization
  Map<String, dynamic> toMap() {
    return {
      'originalConfidence': originalConfidence,
      'adjustedConfidence': adjustedConfidence,
      'confidenceLevel': confidenceLevel,
      'factors': factors,
      'recommendations': recommendations,
      'isReliable': isReliable,
      'timestamp': timestamp.toIso8601String(),
      'error': error,
    };
  }
  
  @override
  String toString() {
    return 'ConfidenceScore(${confidencePercentage} - $confidenceLevel)';
  }
}