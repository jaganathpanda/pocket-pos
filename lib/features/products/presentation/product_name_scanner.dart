// Facade for optional on-device product-name OCR.
//
// ML Kit is mobile-only and would break the web build, so the real
// implementation lives in `_mobile.dart` and is only pulled in when `dart:io`
// is available (Android/iOS). Web/other platforms get the no-op stub.
export 'product_name_scanner_stub.dart'
    if (dart.library.io) 'product_name_scanner_mobile.dart';
