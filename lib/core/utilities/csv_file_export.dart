import 'csv_file_export_stub.dart'
    if (dart.library.io) 'csv_file_export_io.dart'
    if (dart.library.html) 'csv_file_export_web.dart' as impl;

Future<void> saveCsvFile({
  required String fileName,
  required String content,
}) {
  return impl.saveCsvFile(fileName: fileName, content: content);
}
