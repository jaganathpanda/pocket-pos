library;

/// Non-web stub for the parent-modal bridge.
///
/// The Android/iOS/desktop builds never run inside an iframe, and cannot even
/// import `dart:js_interop`, so this keeps the call sites platform-agnostic.

/// Always false off the web — there is no host page to be embedded in.
bool get isEmbeddedInParent => false;

/// No-op off the web.
void closeParentModal() {}

/// No-op off the web.
void notifyRegistrationComplete() {}
