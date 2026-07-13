/// Run: dart run tool/download_sqlasm.dart
/// Downloads sql-asm.js into web/sqljs/ for offline use.
import 'dart:io';

void main() async {
  const url =
      'https://cdnjs.cloudflare.com/ajax/libs/sql.js/1.13.0/sql-asm.js';
  const dest = 'web/sqljs/sql-asm.js';

  final dir = Directory('web/sqljs');
  if (!dir.existsSync()) dir.createSync(recursive: true);

  final file = File(dest);
  if (file.existsSync()) {
    print('Already exists: $dest (${file.lengthSync()} bytes)');
    return;
  }

  print('Downloading $url ...');
  final client = HttpClient();
  try {
    final req = await client.getUrl(Uri.parse(url));
    final res = await req.close();
    if (res.statusCode != 200) {
      print('HTTP ${res.statusCode}');
      exit(1);
    }
    final sink = file.openWrite();
    await sink.addStream(res);
    await sink.close();
    print('Saved $dest (${file.lengthSync()} bytes)');
  } finally {
    client.close();
  }
}
