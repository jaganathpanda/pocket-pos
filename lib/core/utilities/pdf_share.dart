import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

Future<void> sharePdfFile({
  required Uint8List bytes,
  required String fileName,
  String? text,
}) {
  return SharePlus.instance.share(
    ShareParams(
      text: text,
      files: [
        XFile.fromData(
          bytes,
          name: fileName,
          mimeType: 'application/pdf',
        ),
      ],
      fileNameOverrides: [fileName],
    ),
  );
}
