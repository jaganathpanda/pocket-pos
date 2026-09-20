import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'parent_modal_contract.dart';

/// Web implementation of the parent-modal bridge.
///
/// `package:web` is used rather than `dart:html`: the latter is deprecated and
/// is unavailable when compiling to Wasm.

/// Whether this session is running inside the marketing site's modal.
///
/// Detected from the `embed=1` query parameter that the GTM tag appends to the
/// iframe URL, not by comparing `window.parent` to `window`: JS reference
/// identity across interop is not reliable on every compiler target, and the
/// parent's location is unreadable cross-origin. A query flag is explicit and
/// works under both dart2js and dart2wasm.
bool get isEmbeddedInParent =>
    Uri.base.queryParameters['embed'] == '1';

/// Asks the host page to close the registration modal.
///
/// Safe to call unconditionally — when the app is not embedded, the message is
/// addressed to an origin the browser won't deliver to, so nothing happens.
void closeParentModal() => _postToParent(kCloseRegistrationModal);

/// Tells the host that registration succeeded, so it can retire the prompt
/// instead of leaving the sticky tab behind.
void notifyRegistrationComplete() => _postToParent(kRegistrationComplete);

void _postToParent(String message) {
  final parent = web.window.parent;
  if (parent == null) return;

  // One call per trusted origin. Only the call whose targetOrigin matches the
  // real parent is delivered; the rest are discarded by the browser. This
  // avoids ever falling back to '*', which would broadcast the message to
  // whatever page happens to be framing us.
  for (final origin in kTrustedParentOrigins) {
    parent.postMessage(message.toJS, origin.toJS);
  }
}
