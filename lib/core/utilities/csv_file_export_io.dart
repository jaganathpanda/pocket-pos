import 'dart:io';

import 'package:file_picker/file_picker.dart';

Future<void> saveCsvFile({
  required String fileName,
  required String content,
}) async {
  final path = await FilePicker.platform.saveFile(
    dialogTitle: 'Save CSV file',
    fileName: fileName,
  );
  if (path == null || path.trim().isEmpty) {
    throw Exception('Save cancelled');
  }
  await File(path).writeAsString(content, flush: true);
}
