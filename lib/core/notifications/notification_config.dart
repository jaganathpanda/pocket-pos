/// Central notification configuration.
///
/// ⚠️ SECURITY: the Resend API key below ships inside the app bundle when it is
/// hard-coded. That is fine for a quick start / internal build, but for a public
/// release you should NOT embed a secret in the client. Prefer either:
///   • pass it at build time:  `flutter build ... --dart-define=RESEND_API_KEY=...`
///     (still bundled, but keeps it out of source control), or
///   • best: move sending behind a Cloud Function / small backend and call that
///     from the app, so the key never leaves the server.
///
/// Also note: browsers block cross-origin calls to api.resend.com, so direct
/// email sending works on Android/iOS but NOT on Flutter web — another reason a
/// backend proxy is the production-correct approach.
class NotificationConfig {
  const NotificationConfig._();

  /// Resend API key. Overridable via --dart-define=RESEND_API_KEY=...
  static const String resendApiKey = String.fromEnvironment(
    'RESEND_API_KEY',
    defaultValue: 're_G91D5DJ9_CQ4eHCn3nkrJJRom5XS4NasK',
  );

  /// Sender shown to recipients. The `mypocketpos.in` domain is verified in
  /// Resend, so we send from the brand address. Overridable via
  /// --dart-define=EMAIL_FROM=...
  static const String emailFrom = String.fromEnvironment(
    'EMAIL_FROM',
    defaultValue: 'Pocket POS <info@mypocketpos.in>',
  );

  /// Platform inbox that gets a copy of new-store notifications.
  static const String adminEmail = String.fromEnvironment(
    'ADMIN_EMAIL',
    defaultValue: 'info@mypocketpos.in',
  );
}
