/// Bridge for running this app inside an iframe on the marketing site.
///
/// The marketing site opens `/#/store-register` in a modal iframe (injected by
/// a GTM tag) and listens for a `postMessage` signal to close it again. This
/// library owns the app's half of that contract.
///
/// Import this barrel — never the `_web` / `_stub` files directly. The
/// conditional export keeps `dart:js_interop` out of the mobile and desktop
/// builds, where it does not exist.
library;

export 'parent_modal_bridge_stub.dart'
    if (dart.library.js_interop) 'parent_modal_bridge_web.dart';
export 'parent_modal_contract.dart';
