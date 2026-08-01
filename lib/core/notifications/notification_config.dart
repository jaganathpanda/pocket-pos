/// Client-side notification configuration.
///
/// The email VENDOR key lives server-side only (in the `onStoreCreated` Cloud
/// Function's `RESEND_API_KEY` secret) and is never shipped in the app. This
/// file therefore holds no secrets — just non-sensitive addresses used by
/// client-side message templates.
class NotificationConfig {
  const NotificationConfig._();

  /// Platform inbox (used as reply-to / support address in templates).
  static const String adminEmail = 'info@mypocketpos.in';
}
