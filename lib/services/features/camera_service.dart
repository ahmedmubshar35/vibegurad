import 'package:injectable/injectable.dart';
import 'package:stacked/stacked.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:camera/camera.dart';

import '../../models/tool/tool.dart';
import '../core/notification_manager.dart';

@lazySingleton
class CameraService with ListenableServiceMixin {

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

  // Camera functionality methods
  Future<void> initialize() async {
    try {
      // Check camera permission first
      final hasPermission = await requestCameraPermission();
      if (hasPermission) {
        _isInitialized.value = true;
      } else {
        _isInitialized.value = false;
        // Don't show notification here - let the calling code handle it
      }
    } catch (e) {
      print('Camera initialization failed: $e');
      _isInitialized.value = false;
    }
  }

  Future<void> disposeCamera() async {
    _isInitialized.value = false;
  }

  Future<bool> requestCameraPermission() async {
    try {
      print('🔄 Requesting camera permission...');
      
      // First check current status
      final currentStatus = await Permission.camera.status;
      print('📱 Current status before request: $currentStatus');
      
      // If already granted, return true
      if (currentStatus == PermissionStatus.granted) {
        print('✅ Permission already granted');
        return true;
      }
      
      // Request permission
      final status = await Permission.camera.request();
      print('📝 Camera permission request result: $status');
      
      // On iOS, sometimes we need to wait a moment for the system to update
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Check status again after request
      final finalStatus = await Permission.camera.status;
      print('📱 Final status after request: $finalStatus');
      
      final isGranted = finalStatus == PermissionStatus.granted;
      print('✅ Permission granted: $isGranted');
      
      return isGranted;
    } catch (e) {
      print('❌ Error requesting camera permission: $e');
      return false;
    }
  }

  Future<PermissionStatus> getCameraPermissionStatus() async {
    try {
      // Force refresh the permission status (don't use cached value)
      await Future.delayed(const Duration(milliseconds: 100));
      final status = await Permission.camera.status;
      print('📱 Current camera permission status (refreshed): $status');
      return status;
    } catch (e) {
      print('❌ Error getting camera permission status: $e');
      return PermissionStatus.denied;
    }
  }

  Future<bool> openSettings() async {
    try {
      return await openAppSettings();
    } catch (e) {
      print('Error opening app settings: $e');
      return false;
    }
  }

  // Force camera access attempt to make app appear in iOS settings
  Future<void> forceCameraRegistration() async {
    try {
      print('🎯 Forcing camera registration for iOS...');
      
      // This will force iOS to register the app for camera permissions
      final cameras = await availableCameras();
      print('📹 Available cameras: ${cameras.length}');
      
      if (cameras.isNotEmpty) {
        // Try to create a camera controller briefly to trigger permission registration
        final controller = CameraController(
          cameras.first,
          ResolutionPreset.low,
          enableAudio: false,
        );
        
        try {
          await controller.initialize();
          print('✅ Camera controller initialized briefly');
          await controller.dispose();
          print('✅ Camera controller disposed');
        } catch (e) {
          print('⚠️ Camera controller failed (expected if no permission): $e');
          await controller.dispose();
        }
      }
    } catch (e) {
      print('⚠️ Force camera registration failed (expected): $e');
    }
  }

  Future<String?> captureImage() async {
    if (!_isInitialized.value) {
      print('Camera not initialized. Please check permissions.');
      return null;
    }
    
    // This is a placeholder - actual camera capture would be handled by CameraViewModel
    print('Camera capture would be handled by camera screen');
    return null;
  }

  Future<Tool?> recognizeToolFromImage(String imagePath) async {
    // This would integrate with AI service for tool recognition
    // For now, return null as this is handled by the camera screen
    return null;
  }

  void setRecognizedTool(Tool? tool) {
    _recognizedTool.value = tool;
  }

  void clearRecognizedTool() {
    _recognizedTool.value = null;
  }

  // Refresh permission status (call when app resumes from background)
  Future<void> refreshPermissionStatus() async {
    try {
      print('🔄 Refreshing camera permission status...');
      final status = await Permission.camera.status;
      print('📱 Refreshed camera permission status: $status');
      
      if (status == PermissionStatus.granted) {
        _isInitialized.value = true;
        print('✅ Camera permission granted, service initialized');
      } else {
        _isInitialized.value = false;
        print('❌ Camera permission not granted, service not initialized');
      }
      
      notifyListeners();
    } catch (e) {
      print('❌ Error refreshing permission status: $e');
    }
  }

  void dispose() {
    // Cleanup camera service resources
  }
}