import 'dart:convert';
import 'dart:html' as html;

Future<void> saveCsvFile({
  required String fileName,
  required String content,
}) async {
  final bytes = utf8.encode(content);
  final blob = html.Blob(<Object>[bytes], 'text/csv;charset=utf-8');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final body = html.document.body;
  if (body == null) {
    html.Url.revokeObjectUrl(url);
    throw StateError('Cannot download CSV before the page is ready.');
  }
  final anchor = html.AnchorElement(href: url)
    ..download = fileName
    ..style.display = 'none';
  body.children.add(anchor);
  anchor.click();
  anchor.remove();
  Future<void>.delayed(
    const Duration(seconds: 1),
    () => html.Url.revokeObjectUrl(url),
  );
}
