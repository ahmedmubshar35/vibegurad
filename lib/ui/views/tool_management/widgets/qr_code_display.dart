import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../models/tool/tool.dart';

class QRCodeDisplay extends StatelessWidget {
  final Tool tool;
  final double size;
  final bool showToolInfo;
  
  const QRCodeDisplay({
    super.key,
    required this.tool,
    this.size = 200,
    this.showToolInfo = true,
  });

  @override
  Widget build(BuildContext context) {
    final qrData = tool.qrCode ?? _generateQRData();
    
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showToolInfo) ...[
              Text(
                tool.displayName,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '${tool.brand} ${tool.model}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
            ],
            
            // QR Code
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: QrImageView(
                data: qrData,
                version: QrVersions.auto,
                size: size,
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                errorCorrectionLevel: QrErrorCorrectLevel.M,
              ),
            ),
            
            const SizedBox(height: 16),
            
            // QR Code data display
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      qrData,
                      style: const TextStyle(
                        fontSize: 10,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 16),
                    onPressed: () => _copyToClipboard(context, qrData),
                    tooltip: 'Copy QR data',
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Instructions
            Text(
              'Scan this QR code to quickly start timer for this tool',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
  
  String _generateQRData() {
    // Generate QR code data for this tool
    return 'VIBE_GUARD|${tool.id}|${tool.serialNumber ?? 'NO_SERIAL'}|${tool.companyId}';
  }
  
  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('QR code data copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}