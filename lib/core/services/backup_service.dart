import 'dart:io';

import 'package:file_picker/file_picker.dart';

class BackupService {
  Future<File?> exportDatabase(File sourceDbFile) async {
    final result = await FilePicker.platform.saveFile(dialogTitle: 'Export SQLite Backup', fileName: 'pocket_pos_backup.sqlite');
    if (result == null) return null;

    final target = File(result);
    return sourceDbFile.copy(target.path);
  }

  Future<File?> importDatabase() async {
    final picked = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['sqlite', 'db']);
    if (picked == null || picked.files.single.path == null) return null;
    return File(picked.files.single.path!);
  }
}
