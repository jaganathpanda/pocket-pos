import 'package:flutter/widgets.dart';

/// Whether reading a product name from a photo is available on this platform.
bool get productNameScannerSupported => false;

/// No-op on platforms without ML Kit (e.g. web).
Future<String?> scanProductNameFromImage(BuildContext context) async => null;
