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
import '../../../services/core/notification_manager.dart';
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
  final NotificationManager _notificationManager = NotificationManager();

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

  // Fallback tool rotation index
  int _fallbackToolIndex = 0;
  final List<String> _fallbackTools = [
    'drill', 'grinder', 'saw', 'hammer', 'sander', 'jackhammer',
    'nailer', 'compressor', 'welder', 'other'
  ];

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
    // Turn off flash before disposing
    if (_controller != null && _currentFlashMode == FlashMode.torch) {
      _controller!.setFlashMode(FlashMode.off);
    }
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
        NotificationManager().showError('Camera permission is required to use this feature.');
        return;
      }

      // Get available cameras
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        NotificationManager().showError('No cameras available on this device.');
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

      // Ensure flash is off by default
      await _controller!.setFlashMode(FlashMode.off);
      _currentFlashMode = FlashMode.off;

      // Initialize image labeler with lower confidence threshold
      _imageLabeler = ImageLabeler(
        options: ImageLabelerOptions(confidenceThreshold: 0.3),
      );

      _isCameraInitialized = true;
      notifyListeners();
    } catch (e) {
      _notificationManager.showError('Failed to initialize camera: $e');
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
      NotificationManager().showError('Failed to switch camera: $e');
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
      NotificationManager().showError('Failed to capture image: $e');
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
      NotificationManager().showError('Failed to toggle flash: $e');
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

      // Debug: Print all detected labels
      print('🔍 ML Kit detected ${labels.length} labels:');
      for (final label in labels) {
        print('  - ${label.label}: ${(label.confidence * 100).toStringAsFixed(1)}%');
      }

      Tool? recognizedTool = _processLabels(labels);

      // Fallback: If no tool recognized, try general object detection
      if (recognizedTool == null && labels.isNotEmpty) {
        print('🔄 Trying fallback recognition...');
        recognizedTool = _fallbackRecognition(labels);
      }

      if (recognizedTool != null) {
        _detectedTools = [recognizedTool];
        if (!isContinuous) {
          // Only show toast for direct recognition, not fallback
          final isFallback = recognizedTool.name.contains('Unknown') || recognizedTool.brand == 'Unknown';
          if (!isFallback) {
            _notificationManager.showToolNotification('Tool recognized: ${recognizedTool.name}');
          }

          // Auto-start session if auto-timer is enabled
          if (_isAutoStartTimerEnabled) {
            print('🚀 Auto-starting session for detected tool: ${recognizedTool.name}');
            await Future.delayed(const Duration(milliseconds: 300)); // Small delay for UI
            await selectTool(recognizedTool);
          }
        }
        } else {
          _detectedTools = [];
          if (!isContinuous) {
            // Show different messages based on what was detected - but only once
            if (labels.isEmpty) {
              _notificationManager.showCameraNotification('No objects detected. Try scanning a tool directly.');
            } else if (labels.length < 3) {
              _notificationManager.showCameraNotification('No construction tools detected. Try scanning a real tool.');
            } else {
              _notificationManager.showCameraNotification('No construction tools recognized. Use manual selection.');
            }
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
        _notificationManager.showError('Failed to recognize tool: $e');
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

  Tool? _fallbackRecognition(List<ImageLabel> labels) {
    print('🔧 Enhanced fallback recognition - analyzing general labels...');

    // Expanded context keywords for better recognition
    const contextKeywords = {
      'electronic': ['electronic', 'electric', 'electrical', 'battery', 'computer', 'mobile phone', 'device'],
      'mechanical': ['machine', 'equipment', 'appliance', 'vehicle', 'motor', 'engine'],
      'construction': ['construction', 'building', 'site', 'industrial', 'workshop'],
      'metal': ['metal', 'steel', 'iron', 'aluminum', 'hardware'],
      'wood': ['wood', 'timber', 'lumber', 'furniture'],
      'handheld': ['handheld', 'portable', 'hand tool'],
      'power': ['power', 'cordless', 'battery-powered'],
      'cutting': ['cutting', 'sharp', 'blade'],
      'fastening': ['fastening', 'screw', 'nail', 'bolt'],
    };

    // Smart tool suggestions based on detected context
    const contextToTool = {
      'electronic': ['drill', 'grinder', 'saw'],
      'mechanical': ['grinder', 'compressor', 'jackhammer'],
      'construction': ['hammer', 'drill', 'saw', 'grinder'],
      'metal': ['grinder', 'welder', 'drill'],
      'wood': ['saw', 'drill', 'sander'],
      'handheld': ['drill', 'hammer', 'sander'],
      'power': ['drill', 'grinder', 'saw'],
      'cutting': ['saw', 'grinder'],
      'fastening': ['drill', 'nailer'],
    };

    Map<String, double> contextScores = {};

    // Analyze all detected labels for context clues
    for (final label in labels) {
      final labelText = label.label.toLowerCase();
      final confidence = label.confidence;

      print('  🔍 Analyzing: "$labelText" (${(confidence * 100).toStringAsFixed(1)}%)');

      for (final entry in contextKeywords.entries) {
        final category = entry.key;
        final keywords = entry.value;

        for (final keyword in keywords) {
          if (labelText.contains(keyword)) {
            contextScores[category] = (contextScores[category] ?? 0) + confidence;
            print('    ✅ Context match: "$keyword" -> $category (score: ${(contextScores[category]! * 100).toStringAsFixed(1)}%)');
          }
        }
      }
    }

    print('📊 Context scores: $contextScores');

    // Find the best matching context
    if (contextScores.isNotEmpty) {
      final bestContext = contextScores.entries
          .reduce((a, b) => a.value > b.value ? a : b);

      print('🏆 Best context: ${bestContext.key} with score ${(bestContext.value * 100).toStringAsFixed(1)}%');

      // Only suggest tools if we have strong construction/industrial context
      if (bestContext.value > 0.5 && (bestContext.key == 'construction' || bestContext.key == 'mechanical' || bestContext.key == 'electronic')) {
        // Get suggested tools for this context
        final suggestedTools = contextToTool[bestContext.key] ?? _fallbackTools;

        // Rotate through different tools instead of always using the first one
        final suggestedTool = suggestedTools[_fallbackToolIndex % suggestedTools.length];
        _fallbackToolIndex = (_fallbackToolIndex + 1) % suggestedTools.length;

        print('🎯 Smart suggestion: $suggestedTool (rotating index: $_fallbackToolIndex, based on context: ${bestContext.key})');

        // Don't show snackbar here - let the main flow handle it
        return _createToolFromType(suggestedTool);
      } else {
        print('❌ Context score too low or not construction-related: ${bestContext.key} (${(bestContext.value * 100).toStringAsFixed(1)}%)');

        // Still rotate through tools for fallback even with low context
        if (bestContext.value > 0.2) {
          final suggestedTool = _fallbackTools[_fallbackToolIndex % _fallbackTools.length];
          _fallbackToolIndex = (_fallbackToolIndex + 1) % _fallbackTools.length;

          print('🔄 Fallback tool rotation: $suggestedTool (index: $_fallbackToolIndex)');
          return _createToolFromType(suggestedTool);
        }
      }
    }

    // No strong construction context found - don't suggest tools
    print('❌ No strong construction/industrial context detected');
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
      NotificationManager().showError('Failed to capture image: $e');
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

      // If no tools found, add default tools for manual selection
      if (_availableTools.isEmpty) {
        _availableTools = _getDefaultTools();
      }
    } catch (e) {
      // If error, provide default tools
      _availableTools = _getDefaultTools();
      print('Using default tools due to error: $e');
    } finally {
      _isLoadingTools = false;
      notifyListeners();
    }
  }

  // Get default tools for manual selection
  List<Tool> _getDefaultTools() {
    return [
      Tool(
        id: 'default_drill_1',
        name: 'Hammer Drill',
        brand: 'DeWalt',
        model: 'DCD996B',
        category: 'Power Tools',
        type: ToolType.drill,
        companyId: 'default',
        vibrationLevel: 12.5,
        frequency: 50.0,
        dailyExposureLimit: 120,
        weeklyExposureLimit: 600,
        imageUrl: '',
      ),
      Tool(
        id: 'default_grinder_1',
        name: 'Angle Grinder',
        brand: 'Makita',
        model: '9557PB',
        category: 'Power Tools',
        type: ToolType.grinder,
        companyId: 'default',
        vibrationLevel: 8.5,
        frequency: 100.0,
        dailyExposureLimit: 180,
        weeklyExposureLimit: 900,
        imageUrl: '',
      ),
      Tool(
        id: 'default_saw_1',
        name: 'Circular Saw',
        brand: 'Milwaukee',
        model: '2732-20',
        category: 'Power Tools',
        type: ToolType.saw,
        companyId: 'default',
        vibrationLevel: 4.2,
        frequency: 60.0,
        dailyExposureLimit: 240,
        weeklyExposureLimit: 1200,
        imageUrl: '',
      ),
      Tool(
        id: 'default_sander_1',
        name: 'Orbital Sander',
        brand: 'Bosch',
        model: 'ROS20VSC',
        category: 'Power Tools',
        type: ToolType.sander,
        companyId: 'default',
        vibrationLevel: 3.5,
        frequency: 120.0,
        dailyExposureLimit: 300,
        weeklyExposureLimit: 1500,
        imageUrl: '',
      ),
      Tool(
        id: 'default_jackhammer_1',
        name: 'Demolition Hammer',
        brand: 'Hilti',
        model: 'TE 500-AVR',
        category: 'Demolition',
        type: ToolType.jackhammer,
        companyId: 'default',
        vibrationLevel: 15.8,
        frequency: 25.0,
        dailyExposureLimit: 60,
        weeklyExposureLimit: 300,
        imageUrl: '',
      ),
      Tool(
        id: 'default_hammer_1',
        name: 'Rotary Hammer',
        brand: 'DeWalt',
        model: 'DCH273B',
        category: 'Power Tools',
        type: ToolType.hammer,
        companyId: 'default',
        vibrationLevel: 9.5,
        frequency: 40.0,
        dailyExposureLimit: 150,
        weeklyExposureLimit: 750,
        imageUrl: '',
      ),
      Tool(
        id: 'default_nailer_1',
        name: 'Framing Nailer',
        brand: 'Paslode',
        model: 'CF325Li',
        category: 'Power Tools',
        type: ToolType.nailer,
        companyId: 'default',
        vibrationLevel: 5.2,
        frequency: 80.0,
        dailyExposureLimit: 200,
        weeklyExposureLimit: 1000,
        imageUrl: '',
      ),
      Tool(
        id: 'default_compressor_1',
        name: 'Air Compressor',
        brand: 'Porter-Cable',
        model: 'C2002',
        category: 'Power Tools',
        type: ToolType.compressor,
        companyId: 'default',
        vibrationLevel: 1.5,
        frequency: 20.0,
        dailyExposureLimit: 600,
        weeklyExposureLimit: 3000,
        imageUrl: '',
      ),
      Tool(
        id: 'default_welder_1',
        name: 'MIG Welder',
        brand: 'Lincoln Electric',
        model: 'MP210',
        category: 'Welding',
        type: ToolType.welder,
        companyId: 'default',
        vibrationLevel: 2.0,
        frequency: 15.0,
        dailyExposureLimit: 450,
        weeklyExposureLimit: 2250,
        imageUrl: '',
      ),
      Tool(
        id: 'default_other_1',
        name: 'Impact Driver',
        brand: 'Makita',
        model: 'XDT16Z',
        category: 'Power Tools',
        type: ToolType.other,
        companyId: 'default',
        vibrationLevel: 6.5,
        frequency: 70.0,
        dailyExposureLimit: 150,
        weeklyExposureLimit: 750,
        imageUrl: '',
      ),
    ];
  }

  Future<void> selectTool(Tool tool) async {
    await _startTimerWithTool(tool);
  }

  Future<void> selectManualTool(Tool tool) async {
    await selectTool(tool);
  }

  Future<void> _startTimerWithTool(Tool tool) async {
    setBusy(true);

    try {
      print('🚀 Starting timer session from camera with tool: ${tool.displayName}');
      print('🔧 Tool details: ${tool.brand} ${tool.model}, Vibration: ${tool.vibrationLevel} m/s²');

      // Turn off flash before starting session to prevent issues
      if (_controller != null && _currentFlashMode == FlashMode.torch) {
        await _controller!.setFlashMode(FlashMode.off);
        _currentFlashMode = FlashMode.off;
      }

      // Get current user from auth service
      final currentUser = _authService.currentUser;

      // Ensure user is set in timer service
      if (currentUser != null) {
        _timerService.setCurrentUser(currentUser);
        print('👤 Set current user in timer service: ${currentUser.email}');
      } else {
        print('❌ No current user available');
        _notificationManager.showError('Please log in to start a session');
        return;
      }

      // Start timer session with the selected tool
      final success = await _timerService.startSession(tool);

      if (success) {
        print('✅ Timer session started successfully from camera');
        // Note: Timer service already shows "Started tracking" notification

        // Navigate to home view instead of timer view
        print('🧭 Navigating to home screen');
        await _navigationService.navigateTo(Routes.homeView);
      } else {
        print('❌ Failed to start timer session from camera');
        _notificationManager.showError('Failed to start timer session. Please try again.');
      }
    } catch (e) {
      print('❌ Error in _startTimerWithTool from camera: $e');
      _notificationManager.showError('Error starting session: ${e.toString()}');
    } finally {
      setBusy(false);
    }
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