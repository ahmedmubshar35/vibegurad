import 'dart:async';
import 'package:injectable/injectable.dart';
import 'package:stacked/stacked.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:get_it/get_it.dart';
import 'package:vibration/vibration.dart';

import '../../models/tool/tool.dart';
import 'tool_service.dart';
import 'timer_service.dart';
import '../core/authentication_service.dart';
import '../core/notification_manager.dart';

@lazySingleton
class QRScannerService with ListenableServiceMixin {
  final ToolService _toolService = GetIt.instance<ToolService>();
  final TimerService _timerService = GetIt.instance<TimerService>();
  final AuthenticationService _authService = GetIt.instance<AuthenticationService>();
  
  MobileScannerController? _controller;
  Timer? _scanCooldownTimer;
  String? _lastScannedCode;
  DateTime? _lastScanTime;
  
  // Stream controllers for reactive UI
  final StreamController<bool> _isScanningController = StreamController<bool>.broadcast();
  final StreamController<Tool?> _scannedToolController = StreamController<Tool?>.broadcast();
  final StreamController<String?> _lastScannedQRController = StreamController<String?>.broadcast();
  final StreamController<bool> _scannerActiveController = StreamController<bool>.broadcast();
  
  // Reactive values
  final ReactiveValue<bool> _isScanning = ReactiveValue<bool>(false);
  final ReactiveValue<Tool?> _scannedTool = ReactiveValue<Tool?>(null);
  final ReactiveValue<String?> _lastScannedQR = ReactiveValue<String?>(null);
  final ReactiveValue<bool> _scannerActive = ReactiveValue<bool>(false);
  
  bool get isScanning => _isScanning.value;
  Tool? get scannedTool => _scannedTool.value;
  String? get lastScannedQR => _lastScannedQR.value;
  bool get isScannerActive => _scannerActive.value;
  
  // Streams for reactive UI
  Stream<bool> get isScanningStream => _isScanningController.stream;
  Stream<Tool?> get scannedToolStream => _scannedToolController.stream;
  Stream<String?> get lastScannedQRStream => _lastScannedQRController.stream;
  Stream<bool> get scannerActiveStream => _scannerActiveController.stream;
  
  // Scan cooldown to prevent rapid scanning
  static const Duration _scanCooldown = Duration(seconds: 2);
  
  QRScannerService() {
    listenToReactiveValues([_isScanning, _scannedTool, _lastScannedQR, _scannerActive]);
  }
  
  // Initialize QR scanner
  Future<void> initializeScanner() async {
    try {
      _controller = MobileScannerController(
        detectionSpeed: DetectionSpeed.normal,
        facing: CameraFacing.back,
        torchEnabled: false,
      );
      
      _scannerActive.value = true;
      _scannerActiveController.add(true);
      
      // Start scanning
      await startScanning();
    } catch (e) {
      NotificationManager().showError('Failed to initialize QR scanner: $e');
    }
  }
  
  // Start scanning for QR codes
  Future<void> startScanning() async {
    if (_controller == null) {
      await initializeScanner();
    }
    
    _isScanning.value = true;
    _isScanningController.add(true);
    _controller?.start();
  }
  
  // Stop scanning
  Future<void> stopScanning() async {
    _isScanning.value = false;
    _isScanningController.add(false);
    _controller?.stop();
  }
  
  // Toggle torch/flashlight
  Future<void> toggleTorch() async {
    await _controller?.toggleTorch();
  }
  
  // Switch camera (front/back)
  Future<void> switchCamera() async {
    await _controller?.switchCamera();
  }
  
  // Handle barcode detection
  void onBarcodeDetect(BarcodeCapture capture) {
    // Skip if in cooldown period
    if (_scanCooldownTimer?.isActive == true) return;
    
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    
    final barcode = barcodes.first;
    final String? code = barcode.rawValue;
    
    if (code == null || code.isEmpty) return;
    
    // Skip if same code scanned recently
    if (_lastScannedCode == code && 
        _lastScanTime != null && 
        DateTime.now().difference(_lastScanTime!).inSeconds < 5) {
      return;
    }
    
    _lastScannedCode = code;
    _lastScanTime = DateTime.now();
    _lastScannedQR.value = code;
    _lastScannedQRController.add(code);
    
    // Process the scanned code (could be QR code or barcode)
    _processScannedCode(code, barcode.type);
    
    // Start cooldown timer
    _scanCooldownTimer = Timer(_scanCooldown, () {});
  }
  
  // Process scanned code (QR code or barcode)
  Future<void> _processScannedCode(String code, BarcodeType barcodeType) async {
    try {
      // Provide haptic feedback
      _provideHapticFeedback();
      
      // Determine scan type message
      String scanType = _getScanTypeMessage(barcodeType);
      
      // Parse code to find tool (try different methods based on barcode type)
      final tool = await _findToolByCode(code, barcodeType);
      
      if (tool != null) {
        _scannedTool.value = tool;
        _scannedToolController.add(tool);
        
        NotificationManager().showSuccess('✅ Scanned ($scanType): ${tool.displayName}');
        
        // Auto-start timer if enabled
        await _handleAutoTimerStart(tool);
      } else {
        NotificationManager().showError('❌ Tool not found for $scanType: $code');
        
        // Attempt to create new tool entry
        await _handleUnknownCode(code, barcodeType);
      }
    } catch (e) {
      NotificationManager().showError('Error processing QR code: $e');
    }
  }
  
  // Get scan type message for user feedback
  String _getScanTypeMessage(BarcodeType barcodeType) {
    // Simple implementation - just check the name
    final typeName = barcodeType.toString().split('.').last;
    
    switch (typeName) {
      case 'qrCode':
        return 'QR Code';
      case 'ean13':
        return 'Barcode (EAN-13)';
      case 'ean8':
        return 'Barcode (EAN-8)';
      case 'code128':
        return 'Barcode (Code-128)';
      case 'code39':
        return 'Barcode (Code-39)';
      case 'upca':
        return 'Barcode (UPC-A)';
      case 'upce':
        return 'Barcode (UPC-E)';
      default:
        return 'Barcode';
    }
  }
  
  // Find tool by any type of code
  Future<Tool?> _findToolByCode(String code, BarcodeType barcodeType) async {
    // First try QR code specific parsing
    final typeName = barcodeType.toString().split('.').last;
    if (typeName == 'qrCode') {
      final tool = await _findToolByQRCode(code);
      if (tool != null) return tool;
    }
    
    // Try barcode parsing for other types
    return await _findToolByBarcode(code, barcodeType);
  }
  
  // Find tool by barcode
  Future<Tool?> _findToolByBarcode(String barcode, BarcodeType barcodeType) async {
    try {
      final currentUser = _authService.currentUser;
      if (currentUser?.companyId != null) {
        final tools = await _toolService.getCompanyTools(currentUser!.companyId!).first;
        
        // Search by different barcode patterns based on type
        Tool? match = tools.cast<Tool?>().firstWhere(
          (tool) => _matchesBarcode(tool, barcode, barcodeType),
          orElse: () => null,
        );
        
        return match;
      }
      
      return null;
    } catch (e) {
      print('Error finding tool by barcode: $e');
      return null;
    }
  }
  
  // Check if tool matches barcode based on type
  bool _matchesBarcode(Tool? tool, String barcode, BarcodeType barcodeType) {
    if (tool == null) return false;
    
    final typeName = barcodeType.toString().split('.').last;
    
    // Try different matching strategies based on barcode type
    switch (typeName) {
      case 'ean13':
      case 'ean8':
      case 'upca':
      case 'upce':
        // These are typically manufacturer/product codes
        return tool.serialNumber?.contains(barcode) == true ||
               tool.model.contains(barcode) ||
               tool.brand.toLowerCase().contains(barcode.toLowerCase());
      
      case 'code128':
      case 'code39':
        // These might be custom tool identifiers
        return tool.serialNumber == barcode ||
               tool.id == barcode ||
               tool.qrCode?.contains(barcode) == true;
      
      case 'dataMatrix':
      case 'pdf417':
        // These might contain more structured data
        return _parseStructuredBarcode(tool, barcode);
      
      default:
        // Generic matching
        return tool.serialNumber == barcode ||
               tool.id == barcode ||
               tool.serialNumber?.contains(barcode) == true ||
               tool.model.toLowerCase().contains(barcode.toLowerCase());
    }
  }
  
  // Parse structured barcode data
  bool _parseStructuredBarcode(Tool tool, String barcode) {
    // Try to extract tool information from structured barcode
    // This could include manufacturer codes, model numbers, etc.
    
    // For now, do basic matching
    final barcodeUpper = barcode.toUpperCase();
    final toolInfo = '${tool.brand} ${tool.model} ${tool.serialNumber ?? ''}'.toUpperCase();
    
    return toolInfo.contains(barcodeUpper) ||
           barcodeUpper.contains(tool.brand.toUpperCase()) ||
           barcodeUpper.contains(tool.model.toUpperCase());
  }
  
  // Find tool by QR code
  Future<Tool?> _findToolByQRCode(String qrCode) async {
    try {
      // First, try to find by exact QR code match
      final currentUser = _authService.currentUser;
      if (currentUser?.companyId != null) {
        final tools = await _toolService.getCompanyTools(currentUser!.companyId!).first;
        
        // Look for exact QR code match
        Tool? exactMatch = tools.cast<Tool?>().firstWhere(
          (tool) => tool?.qrCode == qrCode,
          orElse: () => null,
        );
        
        if (exactMatch != null) return exactMatch;
        
        // Try to match by serial number or other identifiers in QR
        Tool? serialMatch = tools.cast<Tool?>().firstWhere(
          (tool) => tool?.serialNumber == qrCode,
          orElse: () => null,
        );
        
        if (serialMatch != null) return serialMatch;
        
        // Try to match by tool ID
        Tool? idMatch = tools.cast<Tool?>().firstWhere(
          (tool) => tool?.id == qrCode,
          orElse: () => null,
        );
        
        return idMatch;
      }
      
      return null;
    } catch (e) {
      print('Error finding tool by QR code: $e');
      return null;
    }
  }
  
  // Handle unknown code (QR or barcode)
  Future<void> _handleUnknownCode(String code, BarcodeType barcodeType) async {
    final scanType = _getScanTypeMessage(barcodeType);
    
    NotificationManager().showWarning('Unknown $scanType. Register this tool in tool management.');
    
    // Could implement automatic tool registration here
    // For now, we'll just log it for manual registration
    print('Unknown $scanType scanned: $code');
  }
  
  // Handle automatic timer start
  Future<void> _handleAutoTimerStart(Tool tool) async {
    try {
      // Check if timer service is available
      if (_timerService.currentSession != null) {
        NotificationManager().showWarning('Session already active with ${_timerService.currentSession!.tool?.displayName ?? 'another tool'}');
        return;
      }
      
      // Check if user is authenticated
      if (_authService.currentUser == null) {
        NotificationManager().showWarning('Please log in to start a session');
        return;
      }
      
      // Start timer session
      final success = await _timerService.startSession(tool);
      
      if (success) {
        NotificationManager().showSuccess('⏱️ Timer started for ${tool.displayName}');
        
        // Provide additional feedback
        _provideSuccessFeedback();
      } else {
        NotificationManager().showError('Failed to start timer session');
      }
    } catch (e) {
      NotificationManager().showError('Error starting timer: $e');
    }
  }
  
  // Provide haptic feedback
  void _provideHapticFeedback() {
    try {
      Vibration.hasVibrator().then((hasVibrator) {
        if (hasVibrator == true) {
          Vibration.vibrate(duration: 100);
        }
      });
    } catch (e) {
      // Ignore vibration errors
    }
  }
  
  // Provide success feedback
  void _provideSuccessFeedback() {
    try {
      Vibration.hasVibrator().then((hasVibrator) {
        if (hasVibrator == true) {
          // Double vibration for success
          Vibration.vibrate(duration: 200);
          Future.delayed(const Duration(milliseconds: 100), () {
            Vibration.vibrate(duration: 200);
          });
        }
      });
    } catch (e) {
      // Ignore vibration errors
    }
  }
  
  // Generate QR code for a tool
  String generateToolQRCode(Tool tool) {
    // Generate QR code content with tool information
    // Format: VIBE_GUARD|TOOL_ID|SERIAL_NUMBER|COMPANY_ID
    final qrContent = 'VIBE_GUARD|${tool.id}|${tool.serialNumber ?? 'NO_SERIAL'}|${tool.companyId}';
    return qrContent;
  }
  
  // Parse QR code content
  Map<String, String>? parseToolQRCode(String qrCode) {
    try {
      final parts = qrCode.split('|');
      if (parts.length >= 4 && parts[0] == 'VIBE_GUARD') {
        return {
          'toolId': parts[1],
          'serialNumber': parts[2],
          'companyId': parts[3],
        };
      }
    } catch (e) {
      print('Error parsing QR code: $e');
    }
    return null;
  }
  
  // Clear last scanned data
  void clearLastScanned() {
    _lastScannedCode = null;
    _lastScanTime = null;
    _lastScannedQR.value = null;
    _scannedTool.value = null;
    _lastScannedQRController.add(null);
    _scannedToolController.add(null);
  }
  
  // Dispose resources
  Future<void> dispose() async {
    _scanCooldownTimer?.cancel();
    _controller?.dispose();
    _scannerActive.value = false;
    _scannerActiveController.add(false);
    
    // Close stream controllers
    await _isScanningController.close();
    await _scannedToolController.close();
    await _lastScannedQRController.close();
    await _scannerActiveController.close();
  }
  
  // Get scanner controller for UI
  MobileScannerController? get controller => _controller;
}