import 'dart:io';
import 'package:camera/camera.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:injectable/injectable.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../models/tool/tool.dart';
import '../../enums/tool_type.dart';

@lazySingleton
class CameraService with ListenableServiceMixin {
  SnackbarService get _snackbarService => GetIt.instance<SnackbarService>();
  
  CameraService() {
    listenToReactiveValues([_isInitialized, _isCapturing, _recognizedTool]);
  }

  // Reactive values
  final ReactiveValue<bool> _isInitialized = ReactiveValue<bool>(false);
  final ReactiveValue<bool> _isCapturing = ReactiveValue<bool>(false);
  final ReactiveValue<Tool?> _recognizedTool = ReactiveValue<Tool?>(null);

  bool get isInitialized => _isInitialized.value;
  bool get isCapturing => _isCapturing.value;
  Tool? get recognizedTool => _recognizedTool.value;

  // Camera controller
  CameraController? _controller;
  CameraController? get controller => _controller;

  // Available cameras
  List<CameraDescription> _cameras = [];
  List<CameraDescription> get cameras => _cameras;

  // Image labeler for tool recognition
  final ImageLabeler _imageLabeler = ImageLabeler(
    options: ImageLabelerOptions(confidenceThreshold: 0.7),
  );

  // Initialize camera
  Future<bool> initialize() async {
    try {
      // Request camera permission
      final status = await Permission.camera.request();
      if (status != PermissionStatus.granted) {
        _snackbarService.showSnackbar(
          message: 'Camera permission is required to use this feature.',
        );
        return false;
      }

      // Get available cameras
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        _snackbarService.showSnackbar(
          message: 'No cameras available on this device.',
        );
        return false;
      }

      // Initialize camera controller with back camera
      final backCamera = _cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras.first,
      );

      _controller = CameraController(
        backCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: Platform.isIOS 
            ? ImageFormatGroup.bgra8888 
            : ImageFormatGroup.yuv420,
      );

      await _controller!.initialize();
      _isInitialized.value = true;

      return true;
    } catch (e) {
      _snackbarService.showSnackbar(
        message: 'Failed to initialize camera: $e',
      );
      return false;
    }
  }

  // Get available cameras
  Future<List<CameraDescription>?> getAvailableCameras() async {
    try {
      _cameras = await availableCameras();
      return _cameras;
    } catch (e) {
      _snackbarService.showSnackbar(
        message: 'Error getting cameras: $e',
      );
      return null;
    }
  }

  // Request camera permission
  Future<bool> requestCameraPermission() async {
    try {
      final status = await Permission.camera.request();
      return status == PermissionStatus.granted;
    } catch (e) {
      _snackbarService.showSnackbar(
        message: 'Error requesting camera permission: $e',
      );
      return false;
    }
  }

  // Dispose camera resources
  Future<void> dispose() async {
    try {
      await _controller?.dispose();
      await _imageLabeler.close();
      _isInitialized.value = false;
    } catch (e) {
      // Silently handle disposal errors
    }
  }

  // Capture image
  Future<XFile?> captureImage() async {
    if (!isInitialized || _controller == null) {
      _snackbarService.showSnackbar(
        message: 'Camera is not initialized.',
      );
      return null;
    }

    try {
      _isCapturing.value = true;
      final image = await _controller!.takePicture();
      _isCapturing.value = false;
      return image;
    } catch (e) {
      _isCapturing.value = false;
      _snackbarService.showSnackbar(
        message: 'Failed to capture image: $e',
      );
      return null;
    }
  }

  // Recognize tool from image (simplified approach)
  Future<Tool?> recognizeTool(XFile imageFile) async {
    try {
      // Create InputImage directly from file path (most reliable method)
      final inputImage = InputImage.fromFilePath(imageFile.path);

      // Perform image labeling
      final labels = await _imageLabeler.processImage(inputImage);

      // Process labels to identify tools
      final recognizedTool = _processLabels(labels);

      if (recognizedTool != null) {
        _recognizedTool.value = recognizedTool;
        return recognizedTool;
      } else {
        _snackbarService.showSnackbar(
          message: 'No tool recognized. Please try again with a clearer image.',
        );
        return null;
      }
    } catch (e) {
      // Fallback: try with simpler approach
      try {
        final bytes = await imageFile.readAsBytes();

        // Create a simple InputImage from bytes without complex metadata
        final inputImage = InputImage.fromBytes(
          bytes: bytes,
          metadata: InputImageMetadata(
            size: const Size(640, 480), // Default size
            rotation: InputImageRotation.rotation0deg,
            format: InputImageFormat.bgra8888, // BGRA is most compatible
            bytesPerRow: 640 * 3, // RGB format
          ),
        );

        final labels = await _imageLabeler.processImage(inputImage);
        final recognizedTool = _processLabels(labels);

        if (recognizedTool != null) {
          _recognizedTool.value = recognizedTool;
          return recognizedTool;
        }

        _snackbarService.showSnackbar(
          message: 'No tool recognized. Please try again with a clearer image.',
        );
        return null;
      } catch (e2) {
        _snackbarService.showSnackbar(
          message: 'Failed to recognize tool: Image format not supported',
        );
        return null;
      }
    }
  }

  // Process ML Kit labels to identify tools
  Tool? _processLabels(List<ImageLabel> labels) {
    // Tool recognition keywords and their corresponding tool types
    const toolKeywords = {
      'drill': ['drill', 'drilling', 'power drill', 'electric drill', 'cordless drill'],
      'grinder': ['grinder', 'grinding', 'angle grinder', 'bench grinder'],
      'jackhammer': ['jackhammer', 'demolition hammer', 'pneumatic hammer'],
      'saw': ['saw', 'circular saw', 'reciprocating saw', 'jigsaw', 'table saw'],
      'hammer': ['hammer', 'impact hammer', 'demolition hammer'],
      'sander': ['sander', 'sanding', 'orbital sander', 'belt sander'],
      'nailer': ['nailer', 'nail gun', 'stapler'],
      'compressor': ['compressor', 'air compressor'],
      'welder': ['welder', 'welding', 'arc welder', 'mig welder'],
    };

    // Score each tool type based on label confidence
    final Map<String, double> toolScores = {};
    
    for (final label in labels) {
      final labelText = label.label.toLowerCase();
      final confidence = label.confidence;

      for (final entry in toolKeywords.entries) {
        final toolType = entry.key;
        final keywords = entry.value;

        for (final keyword in keywords) {
          if (labelText.contains(keyword)) {
            toolScores[toolType] = (toolScores[toolType] ?? 0) + confidence;
          }
        }
      }
    }

    // Find the tool type with highest score
    if (toolScores.isNotEmpty) {
      final bestMatch = toolScores.entries
          .reduce((a, b) => a.value > b.value ? a : b);

      // Only return if confidence is high enough
      if (bestMatch.value > 0.7) {
        return _createToolFromType(bestMatch.key);
      }
    }

    return null;
  }

  // Create a tool object from recognized type
  Tool _createToolFromType(String toolType) {
    final type = ToolType.fromString(toolType);
    
    return Tool(
      name: type.displayName,
      brand: 'Unknown',
      model: 'Unknown',
      type: type,
      category: type.displayName,
      companyId: 'default', // Will be updated when assigned to company
      vibrationLevel: type.defaultVibrationLevel,
      frequency: type.defaultFrequency,
      dailyExposureLimit: type.defaultDailyLimit,
      weeklyExposureLimit: type.defaultDailyLimit * 5, // 5 days per week
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  // Switch camera (front/back)
  Future<bool> switchCamera() async {
    if (!isInitialized || _cameras.length < 2) return false;

    try {
      await _controller?.dispose();
      
      final currentIndex = _cameras.indexOf(_controller!.description);
      final nextIndex = (currentIndex + 1) % _cameras.length;
      
      _controller = CameraController(
        _cameras[nextIndex],
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: Platform.isIOS 
            ? ImageFormatGroup.bgra8888 
            : ImageFormatGroup.yuv420,
      );

      await _controller!.initialize();
      return true;
    } catch (e) {
      _snackbarService.showSnackbar(
        message: 'Failed to switch camera: $e',
      );
      return false;
    }
  }

  // Toggle flash
  Future<void> toggleFlash() async {
    if (!isInitialized || _controller == null) return;

    try {
      if (_controller!.value.flashMode == FlashMode.off) {
        await _controller!.setFlashMode(FlashMode.torch);
      } else {
        await _controller!.setFlashMode(FlashMode.off);
      }
    } catch (e) {
      _snackbarService.showSnackbar(
        message: 'Failed to toggle flash: $e',
      );
    }
  }

  // Get camera preview widget
  Widget? getCameraPreview() {
    if (!isInitialized || _controller == null) return null;
    
    return CameraPreview(_controller!);
  }

  // Clear recognized tool
  void clearRecognizedTool() {
    _recognizedTool.value = null;
  }

  // Check if camera is ready
  bool get isReady => isInitialized && _controller?.value.isInitialized == true;

  // Get camera state
  CameraValue? get cameraValue => _controller?.value;

  // Continuous detection
  bool _isDetectionRunning = false;
  bool get isDetectionRunning => _isDetectionRunning;

  // Start continuous tool detection
  Future<void> startContinuousDetection({
    int intervalMs = 2000, // Check every 2 seconds
    Function(Tool)? onToolDetected,
    Function(double)? onVibrationDetected,
  }) async {
    if (!isInitialized || _isDetectionRunning) return;
    
    _isDetectionRunning = true;
    
    while (_isDetectionRunning && isInitialized) {
      try {
        // Capture image for analysis
        final imageFile = await captureImage();
        if (imageFile != null) {
          // Recognize tool with improved error handling
          try {
            final tool = await recognizeTool(imageFile);
            if (tool != null) {
              _recognizedTool.value = tool;
              onToolDetected?.call(tool);
              
              // Simulate vibration detection based on tool type
              final vibrationLevel = tool.vibrationLevel;
              onVibrationDetected?.call(vibrationLevel);
            }
          } catch (e) {
            // Silent fail for continuous detection to avoid spam
            // print('Continuous detection error: $e');
          }
          
          // Clean up temporary image
          try {
            await File(imageFile.path).delete();
          } catch (e) {
            // Ignore cleanup errors
          }
        }
        
        // Wait before next detection
        await Future.delayed(Duration(milliseconds: intervalMs));
      } catch (e) {
        // Continue detection even if one frame fails
        await Future.delayed(Duration(milliseconds: intervalMs));
      }
    }
  }

  // Stop continuous detection
  void stopContinuousDetection() {
    _isDetectionRunning = false;
  }

  // Enhanced tool recognition with vibration analysis
  Future<Map<String, dynamic>> analyzeToolWithVibration(XFile imageFile) async {
    try {
      final tool = await recognizeTool(imageFile);
      
      if (tool != null) {
        // Get vibration characteristics
        final vibrationData = _getVibrationCharacteristics(tool);
        
        return {
          'tool': tool,
          'vibrationLevel': tool.vibrationLevel,
          'frequency': tool.frequency,
          'exposureLimit': tool.dailyExposureLimit,
          'safetyRating': _getSafetyRating(tool.vibrationLevel),
          'recommendations': _getSafetyRecommendations(tool),
          'vibrationData': vibrationData,
          'success': true,
        };
      }
      
      return {
        'tool': null, 
        'success': false,
        'message': 'No tool detected'
      };
    } catch (e) {
      return {
        'tool': null,
        'success': false,
        'error': e.toString(),
        'message': 'Recognition failed: Image format may not be supported'
      };
    }
  }

  // Get vibration characteristics for a tool
  Map<String, dynamic> _getVibrationCharacteristics(Tool tool) {
    return {
      'magnitude': tool.vibrationLevel,
      'frequency': tool.frequency,
      'riskLevel': _getRiskLevel(tool.vibrationLevel),
      'maxSafeExposure': tool.dailyExposureLimit,
      'vibrationPattern': _getVibrationPattern(tool.type),
    };
  }

  // Get risk level based on vibration
  String _getRiskLevel(double vibrationLevel) {
    if (vibrationLevel < 2.5) return 'Low';
    if (vibrationLevel < 5.0) return 'Medium';
    if (vibrationLevel < 10.0) return 'High';
    return 'Critical';
  }

  // Get safety rating (1-5 stars)
  int _getSafetyRating(double vibrationLevel) {
    if (vibrationLevel < 2.5) return 5;
    if (vibrationLevel < 5.0) return 4;
    if (vibrationLevel < 7.5) return 3;
    if (vibrationLevel < 10.0) return 2;
    return 1;
  }

  // Get safety recommendations
  List<String> _getSafetyRecommendations(Tool tool) {
    final recommendations = <String>[];
    final vibrationLevel = tool.vibrationLevel;
    
    if (vibrationLevel > 5.0) {
      recommendations.add('Use anti-vibration gloves');
      recommendations.add('Take regular breaks every ${(tool.dailyExposureLimit / 3).round()} minutes');
    }
    
    if (vibrationLevel > 7.5) {
      recommendations.add('Limit daily exposure to ${tool.dailyExposureLimit} minutes');
      recommendations.add('Consider using lower vibration alternative tools');
    }
    
    if (vibrationLevel > 10.0) {
      recommendations.add('CRITICAL: Minimize usage and seek immediate medical advice for any symptoms');
      recommendations.add('Mandatory health monitoring required');
    }
    
    recommendations.add('Maintain proper grip and posture');
    recommendations.add('Regular tool maintenance to reduce vibration');
    
    return recommendations;
  }

  // Get vibration pattern for tool type
  String _getVibrationPattern(ToolType toolType) {
    switch (toolType) {
      case ToolType.drill:
        return 'Rotational with periodic impulses';
      case ToolType.grinder:
        return 'High-frequency continuous';
      case ToolType.jackhammer:
        return 'High-impact periodic pulses';
      case ToolType.saw:
        return 'Rapid back-and-forth motion';
      case ToolType.hammer:
        return 'Impact-based pulses';
      case ToolType.sander:
        return 'Orbital or linear oscillation';
      default:
        return 'Variable based on operation';
    }
  }
}
