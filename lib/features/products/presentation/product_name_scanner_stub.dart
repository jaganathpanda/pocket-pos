import 'package:flutter/widgets.dart';

/// Whether on-device ML-Kit OCR is available (Android / iOS only).
bool get productNameScannerSupported => false;

/// No-op on platforms without ML Kit (e.g. web).
Future<String?> scanProductNameFromImage(BuildContext context) async => null;
