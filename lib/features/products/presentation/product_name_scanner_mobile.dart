import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

/// On-device OCR is available on Android and iOS.
bool get productNameScannerSupported => Platform.isAndroid || Platform.isIOS;

/// Opens the camera, runs on-device text recognition on the captured photo, and
/// returns the most prominent product-name line so it can be filled in
/// automatically. Returns null if the user cancels or nothing readable is
/// found.
Future<String?> scanProductNameFromImage(BuildContext context) async {
  final picked = await ImagePicker().pickImage(
    source: ImageSource.camera,
    imageQuality: 95,
  );
  if (picked == null) return null;

  final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  try {
    final result =
        await recognizer.processImage(InputImage.fromFilePath(picked.path));

    // A product name is normally the biggest text on the pack, so score each
    // readable line by the area of its bounding box and pick the largest.
    String? best;
    double bestScore = 0;
    for (final block in result.blocks) {
      for (final line in block.lines) {
        final text = line.text.replaceAll(RegExp(r'\s+'), ' ').trim();
        if (text.length < 2 || text.length > 80) continue;
        final alpha = RegExp(r'[A-Za-z]').allMatches(text).length;
        if (alpha == 0) continue;
        // Skip mostly-numeric lines (prices, MRP, batch/dates).
        final digits = RegExp(r'[0-9]').allMatches(text).length;
        if (digits > alpha) continue;
        final box = line.boundingBox;
        final score = box.height * box.width;
        if (score > bestScore) {
          bestScore = score;
          best = text;
        }
      }
    }
    return (best == null || best.isEmpty) ? null : best;
  } catch (_) {
    return null;
  } finally {
    await recognizer.close();
  }
}
