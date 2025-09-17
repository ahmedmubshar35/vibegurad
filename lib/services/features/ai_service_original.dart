import 'dart:io';
import 'dart:typed_data';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import 'package:injectable/injectable.dart';
import 'package:stacked_services/stacked_services.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import '../../models/tool/tool.dart';
import '../../enums/tool_type.dart';

@lazySingleton
class AiService {
  SnackbarService get _snackbarService => GetIt.instance<SnackbarService>();
  
  // ML Kit components
  final ImageLabeler _imageLabeler = ImageLabeler(
    options: ImageLabelerOptions(confidenceThreshold: 0.7),
  );
  final ObjectDetector _objectDetector = ObjectDetector(
    options: ObjectDetectorOptions(
      mode: DetectionMode.stream,
      classifyObjects: true,
      multipleObjects: true,
    ),
  );

  AiService();

  // Enhanced tool recognition with object detection (fallback method)
  Future<Tool?> recognizeToolEnhanced(Uint8List imageBytes) async {
    try {
      // Use image labeling only for byte arrays (simpler and more reliable)
      final inputImage = InputImage.fromBytes(
        bytes: imageBytes,
        metadata: InputImageMetadata(
          size: Size((imageBytes.length ~/ 4).toDouble(), 1.0), // Simple fallback
          rotation: InputImageRotation.rotation0deg,
          format: InputImageFormat.nv21, // More compatible format
          bytesPerRow: imageBytes.length,
        ),
      );

      // Use only image labeling for byte arrays (object detection can be problematic)
      final labels = await _imageLabeler.processImage(inputImage);

      // Process labels to identify tools
      final recognizedTool = _processLabelsOnly(labels);

      return recognizedTool;
    } catch (e) {
      // Try with different format if first attempt fails
      try {
        final inputImage = InputImage.fromBytes(
          bytes: imageBytes,
          metadata: InputImageMetadata(
            size: const Size(640, 480), // Common camera resolution
            rotation: InputImageRotation.rotation0deg,
            format: InputImageFormat.yuv420, // Try different format
            bytesPerRow: 640,
          ),
        );

        final labels = await _imageLabeler.processImage(inputImage);
        return _processLabelsOnly(labels);
      } catch (e2) {
        _snackbarService.showSnackbar(
          message: 'AI recognition failed: Image format not supported',
        );
        return null;
      }
    }
  }
  
  // Process only labels (simpler, more reliable)
  Tool? _processLabelsOnly(List<ImageLabel> labels) {
    final Map<String, double> toolScores = {};

    // Process image labels
    for (final label in labels) {
      _addToToolScores(toolScores, label.label, label.confidence);
    }

    // Find best match
    if (toolScores.isNotEmpty) {
      final bestMatch = toolScores.entries
          .reduce((a, b) => a.value > b.value ? a : b);

      // Lower confidence threshold for more matches
      if (bestMatch.value > 0.5) {
        return _createToolFromType(bestMatch.key);
      }
    }

    return null;
  }

  // Process enhanced results from both labeling and object detection
  Tool? _processEnhancedResults(List<ImageLabel> labels, List<DetectedObject> objects) {
    final Map<String, double> toolScores = {};

    // Process image labels
    for (final label in labels) {
      _addToToolScores(toolScores, label.label, label.confidence);
    }

    // Process detected objects
    for (final object in objects) {
      for (final label in object.labels) {
        _addToToolScores(toolScores, label.text, label.confidence);
      }
    }

    // Find best match
    if (toolScores.isNotEmpty) {
      final bestMatch = toolScores.entries
          .reduce((a, b) => a.value > b.value ? a : b);

      // Higher confidence threshold for enhanced recognition
      if (bestMatch.value > 0.8) {
        return _createToolFromType(bestMatch.key);
      }
    }

    return null;
  }

  // Add label to tool scores
  void _addToToolScores(Map<String, double> scores, String label, double confidence) {
    const toolKeywords = {
      'drill': ['drill', 'drilling', 'power drill', 'electric drill', 'cordless drill', 'screwdriver'],
      'grinder': ['grinder', 'grinding', 'angle grinder', 'bench grinder', 'polisher'],
      'jackhammer': ['jackhammer', 'demolition hammer', 'pneumatic hammer', 'breaker'],
      'saw': ['saw', 'circular saw', 'reciprocating saw', 'jigsaw', 'table saw', 'chainsaw'],
      'hammer': ['hammer', 'impact hammer', 'demolition hammer', 'sledgehammer'],
      'sander': ['sander', 'sanding', 'orbital sander', 'belt sander', 'palm sander'],
      'nailer': ['nailer', 'nail gun', 'stapler', 'nailgun'],
      'compressor': ['compressor', 'air compressor', 'pump'],
      'welder': ['welder', 'welding', 'arc welder', 'mig welder', 'tig welder'],
    };

    final labelText = label.toLowerCase();
    
    for (final entry in toolKeywords.entries) {
      final toolType = entry.key;
      final keywords = entry.value;

      for (final keyword in keywords) {
        if (labelText.contains(keyword)) {
          scores[toolType] = (scores[toolType] ?? 0) + confidence;
        }
      }
    }
  }

  // Create tool from recognized type
  Tool _createToolFromType(String toolType) {
    final type = ToolType.fromString(toolType);
    
    return Tool(
      name: type.displayName,
      brand: 'Unknown',
      model: 'Unknown',
      type: type,
      category: type.displayName,
      companyId: 'default',
      vibrationLevel: type.defaultVibrationLevel,
      frequency: type.defaultFrequency,
      dailyExposureLimit: type.defaultDailyLimit,
      weeklyExposureLimit: type.defaultDailyLimit * 5,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  // Analyze image quality - TestFlight fallback version
  Future<Map<String, dynamic>> analyzeImageQuality(Uint8List imageBytes) async {
    // TestFlight fallback: Return good quality metrics
    return {
      'averageConfidence': 0.85,
      'numLabels': 5,
      'qualityLevel': 'Good (Demo)',
      'isGoodForRecognition': true,
    };
  }

  // Recognize tools from image file - TestFlight fallback version
  Future<List<Tool>> recognizeToolsFromImage(dynamic imageFile) async {
    // TestFlight fallback: Return demo tools
    _snackbarService.showSnackbar(
      message: 'Demo Mode: Recognized Saw',
    );

    final tool = _createToolFromType('saw');
    return [tool];
  }
  
  // Method for InputImage - TestFlight fallback version
  Future<Tool?> recognizeToolFromInputImage(dynamic inputImage) async {
    // TestFlight fallback: Return demo hammer
    _snackbarService.showSnackbar(
      message: 'Demo Mode: Recognized Hammer',
    );

    return _createToolFromType('hammer');
  }

  // Get tool recognition suggestions
  List<String> getToolRecognitionSuggestions() {
    return [
      'Ensure good lighting conditions',
      'Position tool in the center of the frame',
      'Avoid shadows and reflections',
      'Keep camera steady and focused',
      'Include the entire tool in the frame',
      'Avoid cluttered backgrounds',
      'Use the back camera for better quality',
      'Clean the camera lens if needed',
    ];
  }

  // Dispose resources
  Future<void> dispose() async {
    await _imageLabeler.close();
    await _objectDetector.close();
  }
}
