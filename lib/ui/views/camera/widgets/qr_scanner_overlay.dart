import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../../services/features/qr_scanner_service.dart';
import '../../../../models/tool/tool.dart';

class QRScannerOverlay extends StatefulWidget {
  final QRScannerService qrService;
  final Function(Tool)? onToolScanned;
  final VoidCallback? onClose;
  final bool showToolInfo;
  
  const QRScannerOverlay({
    super.key,
    required this.qrService,
    this.onToolScanned,
    this.onClose,
    this.showToolInfo = true,
  });

  @override
  State<QRScannerOverlay> createState() => _QRScannerOverlayState();
}

class _QRScannerOverlayState extends State<QRScannerOverlay>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  
  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    
    _animationController.repeat(reverse: true);
    
    // Initialize scanner
    _initializeScanner();
  }
  
  Future<void> _initializeScanner() async {
    await widget.qrService.initializeScanner();
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scan QR/Barcode'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: widget.qrService.toggleTorch,
            tooltip: 'Toggle Flash',
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_ios),
            onPressed: widget.qrService.switchCamera,
            tooltip: 'Switch Camera',
          ),
          if (widget.onClose != null)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: widget.onClose,
              tooltip: 'Close Scanner',
            ),
        ],
      ),
      body: Stack(
        children: [
          // Mobile Scanner
          if (widget.qrService.controller != null)
            MobileScanner(
              controller: widget.qrService.controller!,
              onDetect: (BarcodeCapture capture) {
                widget.qrService.onBarcodeDetect(capture);
                
                // Handle tool scanned callback
                if (widget.onToolScanned != null && 
                    widget.qrService.scannedTool != null) {
                  widget.onToolScanned!(widget.qrService.scannedTool!);
                }
              },
            ),
          
          // Scanning overlay
          _buildScanningOverlay(),
          
          // Tool information panel
          if (widget.showToolInfo)
            _buildToolInfoPanel(),
          
          // Instructions
          _buildInstructions(),
        ],
      ),
    );
  }
  
  Widget _buildScanningOverlay() {
    return CustomPaint(
      painter: QRScannerPainter(),
      child: Container(),
    );
  }
  
  Widget _buildToolInfoPanel() {
    return StreamBuilder<Tool?>(
      stream: widget.qrService.scannedToolStream,
      builder: (context, snapshot) {
        final tool = snapshot.data;
        if (tool == null) return const SizedBox.shrink();
        
        return Positioned(
          bottom: 120,
          left: 16,
          right: 16,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green, width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Tool Detected',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  tool.displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${tool.brand} ${tool.model}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.vibration,
                      size: 16,
                      color: _getVibrationColor(tool.vibrationLevel),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${tool.vibrationLevel.toStringAsFixed(1)} m/s²',
                      style: TextStyle(
                        color: _getVibrationColor(tool.vibrationLevel),
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Icon(
                      Icons.timer,
                      size: 16,
                      color: Colors.blue,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${tool.dailyExposureLimit}min/day',
                      style: const TextStyle(
                        color: Colors.blue,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildInstructions() {
    return Positioned(
      bottom: 40,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                return Opacity(
                  opacity: 0.5 + (_animation.value * 0.5),
                  child: const Text(
                    'Point camera at QR code or barcode on machine',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                );
              },
            ),
            const SizedBox(height: 4),
            Text(
              widget.qrService.lastScannedQR != null 
                  ? 'Last scanned: ${widget.qrService.lastScannedQR}'
                  : 'Ensure good lighting and steady aim',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
  
  Color _getVibrationColor(double vibrationLevel) {
    if (vibrationLevel <= 2.5) return Colors.green;
    if (vibrationLevel <= 5.0) return Colors.orange;
    return Colors.red;
  }
}

class QRScannerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke;
    
    final shadowPaint = Paint()
      ..color = Colors.black54
      ..strokeWidth = 6.0
      ..style = PaintingStyle.stroke;
    
    // Calculate square dimensions (centered)
    final squareSize = size.width * 0.7;
    final left = (size.width - squareSize) / 2;
    final top = (size.height - squareSize) / 2;
    final right = left + squareSize;
    final bottom = top + squareSize;
    
    // Corner length
    final cornerLength = squareSize * 0.1;
    
    // Draw shadow corners first
    canvas.drawPath(
      Path()
        // Top left corner
        ..moveTo(left, top + cornerLength)
        ..lineTo(left, top)
        ..lineTo(left + cornerLength, top)
        // Top right corner  
        ..moveTo(right - cornerLength, top)
        ..lineTo(right, top)
        ..lineTo(right, top + cornerLength)
        // Bottom right corner
        ..moveTo(right, bottom - cornerLength)
        ..lineTo(right, bottom)
        ..lineTo(right - cornerLength, bottom)
        // Bottom left corner
        ..moveTo(left + cornerLength, bottom)
        ..lineTo(left, bottom)
        ..lineTo(left, bottom - cornerLength),
      shadowPaint,
    );
    
    // Draw white corners
    canvas.drawPath(
      Path()
        // Top left corner
        ..moveTo(left, top + cornerLength)
        ..lineTo(left, top)
        ..lineTo(left + cornerLength, top)
        // Top right corner  
        ..moveTo(right - cornerLength, top)
        ..lineTo(right, top)
        ..lineTo(right, top + cornerLength)
        // Bottom right corner
        ..moveTo(right, bottom - cornerLength)
        ..lineTo(right, bottom)
        ..lineTo(right - cornerLength, bottom)
        // Bottom left corner
        ..moveTo(left + cornerLength, bottom)
        ..lineTo(left, bottom)
        ..lineTo(left, bottom - cornerLength),
      paint,
    );
    
    // Draw scanning line (animated)
    final scanLinePaint = Paint()
      ..color = Colors.green.withOpacity(0.8)
      ..strokeWidth = 2.0;
      
    canvas.drawLine(
      Offset(left, top + (squareSize * 0.5)),
      Offset(right, top + (squareSize * 0.5)),
      scanLinePaint,
    );
  }
  
  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}