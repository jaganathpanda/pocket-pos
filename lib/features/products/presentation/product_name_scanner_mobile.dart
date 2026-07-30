import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

/// On-device OCR is available on Android and iOS.
bool get productNameScannerSupported => Platform.isAndroid || Platform.isIOS;

/// Opens the camera, runs on-device text recognition, and returns the most
/// likely product name (the largest / most prominent text line). Returns null
/// if the user cancels or nothing readable is found.
Future<String?> scanProductNameFromImage(BuildContext context) async {
  final picked = await ImagePicker().pickImage(
    source: ImageSource.camera,
    imageQuality: 90,
  );
  if (picked == null) return null;

  final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  try {
    final result = await recognizer.processImage(InputImage.fromFilePath(picked.path));

    // Product names are usually the biggest text on the pack, so rank lines by
    // their bounding-box height and prefer a reasonably long alphabetic line.
    TextLine? best;
    for (final block in result.blocks) {
      for (final line in block.lines) {
        final text = line.text.trim();
        if (text.length < 2) continue;
        if (!RegExp(r'[A-Za-z]').hasMatch(text)) continue;
        if (best == null ||
            line.boundingBox.height > best.boundingBox.height) {
          best = line;
        }
      }
    }
    return best?.text.trim();
  } catch (_) {
    return null;
  } finally {
    await recognizer.close();
  }
}
