/// Vendor-independent message + result types shared by every channel.
///
/// The rest of the app talks in these types only — never in a specific
/// vendor's request/response shape — so swapping Resend/Twilio/etc. touches
/// only the provider implementation.

/// Which delivery channel a message uses.
enum NotificationChannel { email, sms, whatsapp }

class EmailMessage {
  const EmailMessage({
    required this.to,
    required this.subject,
    required this.html,
    this.from,
    this.replyTo,
  });

  final String to;
  final String subject;
  final String html;

  /// Optional override of the provider's default sender (e.g.
  /// "Pocket POS <no-reply@mypocketpos.in>").
  final String? from;
  final String? replyTo;
}

class SmsMessage {
  const SmsMessage({required this.to, required this.body});
  final String to; // E.164, e.g. +9198...
  final String body;
}

class WhatsAppMessage {
  const WhatsAppMessage({required this.to, required this.body});
  final String to; // E.164, e.g. +9198...
  final String body;
}

/// Uniform result so callers can handle success/failure the same way for any
/// channel or vendor.
class NotificationResult {
  const NotificationResult._({
    required this.success,
    required this.channel,
    this.id,
    this.error,
  });

  factory NotificationResult.ok(NotificationChannel channel, {String? id}) =>
      NotificationResult._(success: true, channel: channel, id: id);

  factory NotificationResult.fail(NotificationChannel channel, String error) =>
      NotificationResult._(success: false, channel: channel, error: error);

  /// A skipped send (channel disabled / no vendor configured yet).
  factory NotificationResult.skipped(NotificationChannel channel) =>
      NotificationResult._(
          success: true, channel: channel, id: 'skipped');

  final bool success;
  final NotificationChannel channel;
  final String? id;
  final String? error;

  @override
  String toString() => success
      ? '${channel.name}: ok${id != null ? ' ($id)' : ''}'
      : '${channel.name}: FAILED ($error)';
}
