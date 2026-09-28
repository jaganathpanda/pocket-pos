import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';

Future<void> saveCsvFile({
  required String fileName,
  required String content,
}) async {
  final bytes = utf8.encode(content);
  final path = await FilePicker.platform.saveFile(
    dialogTitle: 'Save CSV file',
    fileName: fileName,
    bytes: bytes,
  );
  if (path == null || path.trim().isEmpty) {
    throw Exception('Save cancelled');
  }
  await File(path).writeAsBytes(bytes, flush: true);
}
