import 'dart:io';
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

  // Stub methods for camera functionality
  Future<void> initialize() async {
    try {
      _snackbarService.showSnackbar(
        message: 'Camera service temporarily disabled',
      );
      _isInitialized.value = false;
    } catch (e) {
      _snackbarService.showSnackbar(
        message: 'Camera initialization failed: \$e',
      );
    }
  }

  Future<void> disposeCamera() async {
    _isInitialized.value = false;
  }

  Future<bool> requestCameraPermission() async {
    final status = await Permission.camera.request();
    return status == PermissionStatus.granted;
  }

  Future<String?> captureImage() async {
    _snackbarService.showSnackbar(
      message: 'Camera capture temporarily disabled',
    );
    return null;
  }

  Future<Tool?> recognizeToolFromImage(String imagePath) async {
    _snackbarService.showSnackbar(
      message: 'Tool recognition temporarily disabled',
    );
    return null;
  }

  void setRecognizedTool(Tool? tool) {
    _recognizedTool.value = tool;
  }

  void clearRecognizedTool() {
    _recognizedTool.value = null;
  }

  void dispose() {
    // Cleanup camera service resources
  }
}