import 'dart:io';
import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';
import 'package:get_it/get_it.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';

import '../../../services/features/ai_service.dart';
import '../../../services/features/advanced_ai_service.dart';
import '../../../services/features/timer_service.dart';
import '../../../services/features/tool_service.dart';
import '../../../services/core/authentication_service.dart';
import '../../../models/tool/tool.dart';
import '../../../enums/tool_type.dart';
import '../../../app/app.router.dart';

class CameraViewModel extends BaseViewModel {
  final AiService _aiService = GetIt.instance<AiService>();
  final AdvancedAIService _advancedAiService = GetIt.instance<AdvancedAIService>();
  final TimerService _timerService = GetIt.instance<TimerService>();
  final ToolService _toolService = GetIt.instance<ToolService>();
  final AuthenticationService _authService = GetIt.instance<AuthenticationService>();
  final NavigationService _navigationService = GetIt.instance<NavigationService>();
  final SnackbarService _snackbarService = GetIt.instance<SnackbarService>();

  // Camera controller and properties
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isCameraInitialized = false;
  bool _isProcessingImage = false;
  bool _showFocusCircle = false;
  double _focusX = 0;
  double _focusY = 0;
  ImageLabeler? _imageLabeler;
  Timer? _continuousDetectionTimer;
  bool _isContinuousDetectionRunning = false;

  // Getters
  CameraController? get controller => _controller;
  bool get isCameraInitialized => _isCameraInitialized;
  bool get isProcessingImage => _isProcessingImage;
  bool get showFocusCircle => _showFocusCircle;
  double get focusX => _focusX;
  double get focusY => _focusY;
  bool get canSwitchCamera => _cameras.length > 1;
  bool get isContinuousDetectionRunning => _isContinuousDetectionRunning;

  // Detected tools
  List<Tool> _detectedTools = [];
  List<Tool> get detectedTools => _detectedTools;

  // Flash mode
  FlashMode _currentFlashMode = FlashMode.off;
  String get currentFlashMode => _currentFlashMode.name;

  // Settings properties
  bool _isAutoStartTimerEnabled = false;
  bool get isAutoStartTimerEnabled => _isAutoStartTimerEnabled;
  bool get autoStartTimerEnabled => _isAutoStartTimerEnabled; // Alias for camera view

  bool _isMultiAngleCaptureMode = false;
  bool get isMultiAngleCaptureMode => _isMultiAngleCaptureMode;

  // Multi-angle capture properties
  bool _isCapturingMultipleAngles = false;
  int _currentAngleIndex = 0;
  final int _totalAnglesNeeded = 3;
  List<XFile> _capturedImages = [];

  bool get isCapturingMultipleAngles => _isCapturingMultipleAngles;
  int get currentAngleIndex => _currentAngleIndex;
  int get totalAnglesNeeded => _totalAnglesNeeded;
  List<XFile> get capturedImages => _capturedImages;

  // Tool management properties
  List<Tool> _availableTools = [];
  bool _isLoadingTools = false;

  List<Tool> get availableTools => _availableTools;
  bool get isLoadingTools => _isLoadingTools;
  bool Function(Tool) get canSelectTool => (Tool tool) => !_isLoadingTools;

  @override
  void dispose() {
    _controller?.dispose();
    _imageLabeler?.close();
    _continuousDetectionTimer?.cancel();
    super.dispose();
  }

  Future<void> initialize() async {
    await initializeCamera();
    await _loadAvailableTools();
  }

  // Camera initialization
  Future<void> initializeCamera() async {
    try {
      setBusy(true);

      // Request camera permission
      final status = await Permission.camera.request();
      if (status != PermissionStatus.granted) {
        _snackbarService.showSnackbar(
          message: 'Camera permission is required to use this feature.',
        );
        return;
      }

      // Get available cameras
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        _snackbarService.showSnackbar(
          message: 'No cameras available on this device.',
        );
        return;
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

      // Initialize image labeler
      _imageLabeler = ImageLabeler(
        options: ImageLabelerOptions(confidenceThreshold: 0.7),
      );

      _isCameraInitialized = true;
      notifyListeners();
    } catch (e) {
      _snackbarService.showSnackbar(
        message: 'Failed to initialize camera: $e',
      );
      _isCameraInitialized = false;
    } finally {
      setBusy(false);
    }
  }

  Future<void> switchCamera() async {
    if (!_isCameraInitialized || _cameras.length < 2) return;

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
      notifyListeners();
    } catch (e) {
      _snackbarService.showSnackbar(
        message: 'Failed to switch camera: $e',
      );
    }
  }

  Future<void> captureAndDetectTool() async {
    await captureAndRecognize();
  }

  Future<void> captureAndAnalyze() async {
    await captureAndRecognize();
  }

  Future<void> captureAndRecognize() async {
    if (!_isCameraInitialized || _controller == null || _isProcessingImage) return;

    try {
      _isProcessingImage = true;
      notifyListeners();

      final image = await _controller!.takePicture();
      await _recognizeToolFromImage(image);
    } catch (e) {
      _snackbarService.showSnackbar(
        message: 'Failed to capture image: $e',
      );
    } finally {
      _isProcessingImage = false;
      notifyListeners();
    }
  }

  void onTapToFocus(double x, double y) {
    // Stub for focus functionality
  }

  Future<void> toggleFlash() async {
    if (!_isCameraInitialized || _controller == null) return;

    try {
      if (_currentFlashMode == FlashMode.off) {
        await _controller!.setFlashMode(FlashMode.torch);
        _currentFlashMode = FlashMode.torch;
      } else {
        await _controller!.setFlashMode(FlashMode.off);
        _currentFlashMode = FlashMode.off;
      }
      notifyListeners();
    } catch (e) {
      _snackbarService.showSnackbar(
        message: 'Failed to toggle flash: $e',
      );
    }
  }

  void toggleAutoStartTimer() {
    _isAutoStartTimerEnabled = !_isAutoStartTimerEnabled;
    notifyListeners();
  }

  void toggleMultiAngleCaptureMode() {
    _isMultiAngleCaptureMode = !_isMultiAngleCaptureMode;
    notifyListeners();
  }

  IconData getFlashIcon() {
    switch (_currentFlashMode) {
      case FlashMode.off:
        return Icons.flash_off;
      case FlashMode.auto:
        return Icons.flash_auto;
      case FlashMode.always:
        return Icons.flash_on;
      case FlashMode.torch:
        return Icons.flashlight_on;
      default:
        return Icons.flash_off;
    }
  }

  // Continuous detection functionality
  void toggleContinuousDetection() {
    if (_isContinuousDetectionRunning) {
      stopContinuousDetection();
    } else {
      startContinuousDetection();
    }
  }

  void startContinuousDetection() {
    if (!_isCameraInitialized || _isContinuousDetectionRunning) return;

    _isContinuousDetectionRunning = true;
    notifyListeners();

    _continuousDetectionTimer = Timer.periodic(
      const Duration(seconds: 2),
      (timer) async {
        if (!_isContinuousDetectionRunning || !_isCameraInitialized) {
          timer.cancel();
          return;
        }

        try {
          if (!_isProcessingImage) {
            final image = await _controller!.takePicture();
            await _recognizeToolFromImage(image, isContinuous: true);

            // Auto-start timer if enabled and tool detected
            if (_isAutoStartTimerEnabled && _detectedTools.isNotEmpty) {
              selectTool(_detectedTools.first);
            }
          }
        } catch (e) {
          // Silent fail for continuous detection to avoid spam
        }
      },
    );
  }

  void stopContinuousDetection() {
    _isContinuousDetectionRunning = false;
    _continuousDetectionTimer?.cancel();
    _continuousDetectionTimer = null;
    notifyListeners();
  }

  String getContinuousDetectionStatusText() {
    if (_detectedTools.isNotEmpty) {
      return 'Tool detected: ${_detectedTools.first.name}';
    }
    return 'Scanning for tools...';
  }

  // Tool recognition functionality
  Future<void> _recognizeToolFromImage(XFile imageFile, {bool isContinuous = false}) async {
    if (_imageLabeler == null) return;

    try {
      final inputImage = InputImage.fromFilePath(imageFile.path);
      final labels = await _imageLabeler!.processImage(inputImage);

      final recognizedTool = _processLabels(labels);

      if (recognizedTool != null) {
        _detectedTools = [recognizedTool];
        if (!isContinuous) {
          _snackbarService.showSnackbar(
            message: 'Tool recognized: ${recognizedTool.name}',
          );
        }
      } else {
        _detectedTools = [];
        if (!isContinuous) {
          _snackbarService.showSnackbar(
            message: 'No tool recognized. Please try again with a clearer image.',
          );
        }
      }

      notifyListeners();

      // Clean up temporary image
      try {
        await File(imageFile.path).delete();
      } catch (e) {
        // Ignore cleanup errors
      }
    } catch (e) {
      if (!isContinuous) {
        _snackbarService.showSnackbar(
          message: 'Failed to recognize tool: $e',
        );
      }
    }
  }

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

  // Multi-angle capture functionality
  void startMultiAngleCapture() {
    _isCapturingMultipleAngles = true;
    _currentAngleIndex = 0;
    _capturedImages = [];
    notifyListeners();
  }

  Future<void> captureCurrentAngle() async {
    if (!_isCameraInitialized || _controller == null) return;

    try {
      final image = await _controller!.takePicture();
      _capturedImages.add(image);
      _currentAngleIndex++;

      if (_currentAngleIndex >= _totalAnglesNeeded) {
        // Process all captured images
        await _processMultiAngleImages();
        _isCapturingMultipleAngles = false;
        _currentAngleIndex = 0;
      }

      notifyListeners();
    } catch (e) {
      _snackbarService.showSnackbar(
        message: 'Failed to capture image: $e',
      );
    }
  }

  Future<void> _processMultiAngleImages() async {
    // Process the first image for now
    if (_capturedImages.isNotEmpty) {
      await _recognizeToolFromImage(_capturedImages.first);
    }
  }

  void cancelMultiAngleCapture() {
    _isCapturingMultipleAngles = false;
    _currentAngleIndex = 0;
    _capturedImages = [];
    notifyListeners();
  }

  String get currentAngleInstruction {
    switch (_currentAngleIndex) {
      case 0:
        return 'Capture tool from the front';
      case 1:
        return 'Capture tool from the side';
      case 2:
        return 'Capture tool from another angle';
      default:
        return 'Capture complete';
    }
  }

  // Tool management
  Future<void> _loadAvailableTools() async {
    _isLoadingTools = true;
    notifyListeners();

    try {
      final user = _authService.currentUser;
      final companyId = user?.companyId;
      if (companyId != null && companyId.isNotEmpty) {
        final toolsStream = _toolService.getCompanyTools(companyId);
        _availableTools = await toolsStream.first;
      } else {
        _availableTools = [];
      }
    } catch (e) {
      _snackbarService.showSnackbar(
        message: 'Failed to load tools: $e',
      );
    } finally {
      _isLoadingTools = false;
      notifyListeners();
    }
  }

  void selectTool(Tool tool) {
    navigateToTimer(tool);
  }

  void selectManualTool(Tool tool) {
    selectTool(tool);
  }

  Map<String, List<Tool>> getToolsByCategory() {
    final Map<String, List<Tool>> categorizedTools = {};

    for (final tool in _availableTools) {
      if (!categorizedTools.containsKey(tool.category)) {
        categorizedTools[tool.category] = [];
      }
      categorizedTools[tool.category]!.add(tool);
    }

    return categorizedTools;
  }

  void navigateToTimer(Tool tool) {
    _navigationService.navigateTo(Routes.timerView, arguments: tool);
  }

  void navigateBack() {
    _navigationService.back();
  }
}