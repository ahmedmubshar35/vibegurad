import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';
import 'package:camera/camera.dart';
import 'package:get_it/get_it.dart';

import 'camera_viewmodel.dart';
import 'widgets/tool_selection_dialog.dart';
import 'widgets/qr_scanner_overlay.dart';
import '../../../services/features/qr_scanner_service.dart';

class CameraView extends StackedView<CameraViewModel> {
  const CameraView({super.key});

  @override
  Widget builder(BuildContext context, CameraViewModel viewModel, Widget? child) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('AI Tool Recognition'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(viewModel.getFlashIcon()),
            onPressed: viewModel.toggleFlash,
            tooltip: 'Toggle Flash',
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_ios),
            onPressed: viewModel.switchCamera,
            tooltip: 'Switch Camera',
          ),
          IconButton(
            icon: Icon(
              viewModel.isContinuousDetectionRunning 
                  ? Icons.pause_circle_filled
                  : Icons.play_circle_filled,
              color: viewModel.isContinuousDetectionRunning 
                  ? Colors.orange 
                  : Colors.green,
            ),
            onPressed: viewModel.toggleContinuousDetection,
            tooltip: viewModel.isContinuousDetectionRunning 
                ? 'Stop Detection' 
                : 'Start Detection',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onSelected: (value) {
              if (value == 'auto_timer') {
                viewModel.toggleAutoStartTimer();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'auto_timer',
                child: Row(
                  children: [
                    Icon(
                      viewModel.autoStartTimerEnabled 
                          ? Icons.timer 
                          : Icons.timer_off,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      viewModel.autoStartTimerEnabled 
                          ? 'Auto-Timer: ON' 
                          : 'Auto-Timer: OFF',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: viewModel.isBusy
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 16),
                  Text(
                    'Initializing camera...',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            )
          : Stack(
              children: [
                // Camera Preview
                if (viewModel.isCameraInitialized)
                  Positioned.fill(
                    child: AspectRatio(
                      aspectRatio: viewModel.controller!.value.aspectRatio,
                      child: CameraPreview(viewModel.controller!),
                    ),
                  )
                else
                  const Center(
                    child: Text(
                      'Camera not available',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),

                // Recognition overlay
                if (viewModel.detectedTools.isNotEmpty)
                  Positioned(
                    top: 20,
                    left: 20,
                    right: 20,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.check_circle,
                            color: Colors.white,
                            size: 24,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tool Recognized!',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            viewModel.detectedTools.first.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Multi-angle capture instruction overlay
                if (viewModel.isCapturingMultipleAngles)
                  Positioned(
                    top: 20,
                    left: 20,
                    right: 20,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.purple.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.photo_camera_back,
                                color: Colors.white,
                                size: 24,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Angle ${viewModel.currentAngleIndex + 1}/3',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            viewModel.currentAngleInstruction,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: viewModel.currentAngleIndex / viewModel.totalAnglesNeeded,
                            backgroundColor: Colors.white.withValues(alpha: 0.3),
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ],
                      ),
                    ),
                  )
                // Status overlay - either instructions or continuous detection status
                else if (viewModel.detectedTools.isEmpty)
                  Positioned(
                    top: 20,
                    left: 20,
                    right: 20,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: viewModel.isContinuousDetectionRunning 
                            ? Colors.blue.withValues(alpha: 0.9)
                            : viewModel.isMultiAngleCaptureMode
                                ? Colors.purple.withValues(alpha: 0.7)
                                : Colors.black54,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            viewModel.isContinuousDetectionRunning 
                                ? Icons.search 
                                : viewModel.isMultiAngleCaptureMode
                                    ? Icons.photo_camera_back
                                    : Icons.camera_alt,
                            color: Colors.white,
                            size: 24,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            viewModel.isContinuousDetectionRunning
                                ? 'AI Detection Active'
                                : viewModel.isMultiAngleCaptureMode
                                    ? 'Multi-Angle Mode Ready'
                                    : 'Point camera at power tool',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            viewModel.isContinuousDetectionRunning
                                ? viewModel.getContinuousDetectionStatusText()
                                : viewModel.isMultiAngleCaptureMode
                                    ? 'Tap capture to start 3-angle photo sequence'
                                    : 'Ensure good lighting and clear view',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (viewModel.isContinuousDetectionRunning && viewModel.autoStartTimerEnabled)
                            const Padding(
                              padding: EdgeInsets.only(top: 4),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.timer,
                                    color: Colors.green,
                                    size: 16,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Auto-timer enabled',
                                    style: TextStyle(
                                      color: Colors.greenAccent,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (viewModel.isMultiAngleCaptureMode && !viewModel.isContinuousDetectionRunning)
                            const Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.stars,
                                    color: Colors.yellowAccent,
                                    size: 16,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    '95%+ accuracy with advanced AI',
                                    style: TextStyle(
                                      color: Colors.yellowAccent,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                // Bottom controls
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.7),
                          Colors.black.withValues(alpha: 0.9),
                        ],
                      ),
                    ),
                    child: Column(
                      children: [
                        // Control buttons row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            // QR Scan button
                            Column(
                              children: [
                                GestureDetector(
                                  onTap: () => _showQRScanner(context, viewModel),
                                  child: Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.green,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 3,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.qr_code_scanner,
                                      size: 24,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Scan QR',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            
                            // Manual tool selection button
                            Column(
                              children: [
                                GestureDetector(
                                  onTap: () => _showManualToolSelection(context, viewModel),
                                  child: Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.blue,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 3,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.list,
                                      size: 24,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Select Tool',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            
                            // AI Capture button (main)
                            Column(
                              children: [
                                GestureDetector(
                                  onTap: viewModel.isProcessingImage 
                                      ? null 
                                      : viewModel.isMultiAngleCaptureMode
                                          ? (viewModel.isCapturingMultipleAngles 
                                              ? viewModel.captureCurrentAngle
                                              : viewModel.startMultiAngleCapture)
                                          : viewModel.captureAndRecognize,
                                  child: Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: viewModel.isProcessingImage 
                                          ? Colors.grey 
                                          : viewModel.isMultiAngleCaptureMode
                                              ? Colors.purple
                                              : Colors.white,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 4,
                                      ),
                                    ),
                                    child: viewModel.isProcessingImage
                                        ? const CircularProgressIndicator(
                                            color: Colors.blue,
                                            strokeWidth: 3,
                                          )
                                        : viewModel.isMultiAngleCaptureMode && viewModel.isCapturingMultipleAngles
                                            ? Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    Icons.camera_alt,
                                                    size: 24,
                                                    color: Colors.white,
                                                  ),
                                                  Text(
                                                    '${viewModel.currentAngleIndex + 1}/3',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              )
                                            : Icon(
                                                viewModel.isMultiAngleCaptureMode
                                                    ? Icons.photo_camera_back
                                                    : Icons.camera_alt,
                                                size: 32,
                                                color: viewModel.isMultiAngleCaptureMode
                                                    ? Colors.white
                                                    : Colors.black,
                                              ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  viewModel.isMultiAngleCaptureMode
                                      ? (viewModel.isCapturingMultipleAngles 
                                          ? 'Angle ${viewModel.currentAngleIndex + 1}/3'
                                          : 'Multi-Angle')
                                      : 'AI Detect',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            
                            // Focus/Settings button
                            Column(
                              children: [
                                GestureDetector(
                                  onTap: () => _showCameraOptions(context, viewModel),
                                  child: Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.black.withValues(alpha: 0.6),
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 3,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.tune,
                                      size: 24,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Options',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Cancel multi-angle capture button
                        if (viewModel.isCapturingMultipleAngles)
                          Column(
                            children: [
                              ElevatedButton.icon(
                                onPressed: viewModel.cancelMultiAngleCapture,
                                icon: const Icon(Icons.cancel),
                                label: const Text('Cancel Multi-Angle Capture'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Captured ${viewModel.capturedImages.length}/${viewModel.totalAnglesNeeded} angles',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          )
                        // Action buttons and instructions
                        else if (viewModel.detectedTools.isNotEmpty)
                          Column(
                            children: [
                              Text(
                                viewModel.autoStartTimerEnabled 
                                    ? 'Tool detected! Session will start automatically.'
                                    : 'Tool detected! Select it to start tracking.',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              if (!viewModel.autoStartTimerEnabled)
                                ElevatedButton.icon(
                                  onPressed: () => viewModel.selectTool(
                                    viewModel.detectedTools.first,
                                  ),
                                  icon: const Icon(Icons.play_arrow),
                                  label: Text('Start Timer with ${viewModel.detectedTools.first.name}'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 12,
                                    ),
                                  ),
                                )
                              else
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.green),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.timer,
                                        color: Colors.green,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Auto-timer will start monitoring ${viewModel.detectedTools.first.name}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          )
                        else if (!viewModel.isContinuousDetectionRunning)
                          Column(
                            children: [
                              const Text(
                                'Tap the capture button to identify your tool',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Or use continuous detection for hands-free monitoring',
                                style: TextStyle(
                                  color: Colors.white60,
                                  fontSize: 12,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          )
                        else
                          const Text(
                            'AI is continuously scanning for tools...',
                            style: TextStyle(
                              color: Colors.blueAccent,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  @override
  CameraViewModel viewModelBuilder(BuildContext context) => CameraViewModel();

  @override
  void onViewModelReady(CameraViewModel viewModel) {
    viewModel.initialize();
  }

  @override
  bool get reactive => true;

  // Show manual tool selection dialog
  void _showManualToolSelection(BuildContext context, CameraViewModel viewModel) async {
    if (viewModel.isLoadingTools) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Loading tools...'),
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }

    await showDialog(
      context: context,
      builder: (context) => ToolSelectionDialog(
        availableTools: viewModel.availableTools,
        onToolSelected: viewModel.selectManualTool,
        canSelectTool: viewModel.canSelectTool,
        toolsByCategory: viewModel.getToolsByCategory(),
      ),
    );
  }
  
  // Show QR scanner
  void _showQRScanner(BuildContext context, CameraViewModel viewModel) {
    final qrService = GetIt.instance<QRScannerService>();
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => QRScannerOverlay(
          qrService: qrService,
          onToolScanned: (tool) {
            // Handle tool scanned
            Navigator.of(context).pop(); // Close scanner
            viewModel.selectManualTool(tool); // Select the scanned tool
          },
          onClose: () {
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  // Show camera options bottom sheet
  void _showCameraOptions(BuildContext context, CameraViewModel viewModel) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Title
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Icon(Icons.camera_alt, size: 24),
                  SizedBox(width: 12),
                  Text(
                    'Camera Options',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Options
            ListTile(
              leading: Icon(viewModel.getFlashIcon()),
              title: const Text('Toggle Flash'),
              onTap: () {
                viewModel.toggleFlash();
                Navigator.pop(context);
              },
            ),
            
            if (viewModel.canSwitchCamera)
              ListTile(
                leading: const Icon(Icons.flip_camera_ios),
                title: const Text('Switch Camera'),
                onTap: () {
                  viewModel.switchCamera();
                  Navigator.pop(context);
                },
              ),
            
            ListTile(
              leading: Icon(
                viewModel.isContinuousDetectionRunning 
                    ? Icons.pause_circle_filled
                    : Icons.play_circle_filled,
                color: viewModel.isContinuousDetectionRunning 
                    ? Colors.orange 
                    : Colors.green,
              ),
              title: Text(
                viewModel.isContinuousDetectionRunning 
                    ? 'Stop Continuous Detection' 
                    : 'Start Continuous Detection',
              ),
              onTap: () {
                viewModel.toggleContinuousDetection();
                Navigator.pop(context);
              },
            ),
            
            ListTile(
              leading: Icon(
                viewModel.autoStartTimerEnabled 
                    ? Icons.timer 
                    : Icons.timer_off,
              ),
              title: Text(
                viewModel.autoStartTimerEnabled 
                    ? 'Disable Auto-Timer' 
                    : 'Enable Auto-Timer',
              ),
              subtitle: Text(
                viewModel.autoStartTimerEnabled 
                    ? 'Sessions start automatically when tools are detected'
                    : 'Manually start sessions after tool detection',
              ),
              onTap: () {
                viewModel.toggleAutoStartTimer();
                Navigator.pop(context);
              },
            ),
            
            ListTile(
              leading: Icon(
                viewModel.isMultiAngleCaptureMode 
                    ? Icons.photo_camera_back
                    : Icons.photo_camera,
                color: viewModel.isMultiAngleCaptureMode 
                    ? Colors.purple 
                    : Colors.blue,
              ),
              title: Text(
                viewModel.isMultiAngleCaptureMode 
                    ? 'Disable Multi-Angle Mode' 
                    : 'Enable Multi-Angle Mode',
              ),
              subtitle: Text(
                viewModel.isMultiAngleCaptureMode 
                    ? 'Take photos from 3 different angles for 95%+ accuracy'
                    : 'Use advanced AI with multiple angles for better recognition',
              ),
              onTap: () {
                viewModel.toggleMultiAngleCaptureMode();
                Navigator.pop(context);
              },
            ),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
