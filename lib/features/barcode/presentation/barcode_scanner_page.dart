import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Opens the full-screen camera scanner and resolves to the scanned barcode
/// string, or `null` if the user cancelled.
Future<String?> scanBarcodeWithCamera(BuildContext context) {
  return Navigator.of(context).push<String>(
    MaterialPageRoute<String>(
      fullscreenDialog: true,
      builder: (_) => const BarcodeScannerPage(),
    ),
  );
}

/// Camera-based barcode/QR scanner built on `mobile_scanner`.
///
/// Pops with the first non-empty barcode value it detects.
class BarcodeScannerPage extends StatefulWidget {
  const BarcodeScannerPage({super.key});

  @override
  State<BarcodeScannerPage> createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends State<BarcodeScannerPage> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    String? code;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      if (value != null && value.trim().isNotEmpty) {
        code = value.trim();
        break;
      }
    }
    if (code == null) return;
    _handled = true;
    Navigator.of(context).pop(code);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Barcode'),
        actions: [
          IconButton(
            tooltip: 'Toggle torch',
            icon: const Icon(Icons.flash_on),
            onPressed: () => _controller.toggleTorch(),
          ),
          IconButton(
            tooltip: 'Switch camera',
            icon: const Icon(Icons.cameraswitch_outlined),
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          // Framing guide.
          Container(
            width: 260,
            height: 160,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.greenAccent, width: 3),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const Positioned(
            bottom: 48,
            left: 24,
            right: 24,
            child: Text(
              'Point the camera at a product barcode',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                shadows: [Shadow(blurRadius: 6, color: Colors.black)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
