import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'notification_config.dart';
import 'notification_models.dart';
import 'notification_providers.dart';

/// Vendor-independent notification facade.
///
/// It owns one provider per channel and routes each message to the right one.
/// Swapping a vendor = construct a different provider in
/// [notificationServiceProvider]; callers and templates never change.
class NotificationService {
  NotificationService({
    required EmailProvider email,
    required SmsProvider sms,
    required WhatsAppProvider whatsapp,
  })  : _email = email,
        _sms = sms,
        _whatsapp = whatsapp;

  final EmailProvider _email;
  final SmsProvider _sms;
  final WhatsAppProvider _whatsapp;

  // ── Channel-level API ──────────────────────────────────────────────────────
  Future<NotificationResult> sendEmail(EmailMessage m) => _email.sendEmail(m);
  Future<NotificationResult> sendSms(SmsMessage m) => _sms.sendSms(m);
  Future<NotificationResult> sendWhatsApp(WhatsAppMessage m) =>
      _whatsapp.sendWhatsApp(m);

  /// Generic dispatch when the channel is chosen at runtime.
  Future<NotificationResult> send(NotificationChannel channel,
      {EmailMessage? email, SmsMessage? sms, WhatsAppMessage? whatsapp}) {
    switch (channel) {
      case NotificationChannel.email:
        return sendEmail(email!);
      case NotificationChannel.sms:
        return sendSms(sms!);
      case NotificationChannel.whatsapp:
        return sendWhatsApp(whatsapp!);
    }
  }

  // ── App-level composition ────────────────────────────────────────────────

  /// Sent on successful registration: a welcome + store-details email to the
  /// owner, a heads-up email to the platform inbox, and (when a mobile is
  /// given) a welcome SMS + WhatsApp. Never throws — notification failures must
  /// not break registration; each result is returned for logging.
  Future<List<NotificationResult>> notifyStoreRegistered({
    required String storeId,
    required String storeName,
    required String ownerName,
    required String username,
    required String ownerEmail,
    String? ownerMobile,
  }) async {
    final results = <NotificationResult>[];

    // 1) Welcome + store details to the owner.
    results.add(await _safe(() => sendEmail(EmailMessage(
          to: ownerEmail,
          subject: 'Welcome to Pocket POS — your store "$storeName" is set up',
          html: _welcomeHtml(
            storeId: storeId,
            storeName: storeName,
            ownerName: ownerName,
            username: username,
          ),
          replyTo: NotificationConfig.adminEmail,
        ))));

    // 2) Platform heads-up to info@mypocketpos.in.
    results.add(await _safe(() => sendEmail(EmailMessage(
          to: NotificationConfig.adminEmail,
          subject: 'New store registered: $storeName ($storeId)',
          html: _adminHtml(
            storeId: storeId,
            storeName: storeName,
            ownerName: ownerName,
            username: username,
            ownerEmail: ownerEmail,
            ownerMobile: ownerMobile,
          ),
        ))));

    // 3) Optional welcome SMS + WhatsApp (no-op until a vendor is wired in).
    if (ownerMobile != null && ownerMobile.trim().isNotEmpty) {
      final line =
          'Welcome to Pocket POS! Your store $storeName is registered. '
          'Store ID: $storeId, username: $username. It will go live after approval.';
      results.add(await _safe(
          () => sendSms(SmsMessage(to: ownerMobile.trim(), body: line))));
      results.add(await _safe(() =>
          sendWhatsApp(WhatsAppMessage(to: ownerMobile.trim(), body: line))));
    }

    return results;
  }

  Future<NotificationResult> _safe(
      Future<NotificationResult> Function() send) async {
    try {
      return await send();
    } catch (e) {
      return NotificationResult.fail(NotificationChannel.email, '$e');
    }
  }

  static String _welcomeHtml({
    required String storeId,
    required String storeName,
    required String ownerName,
    required String username,
  }) {
    return '''
<div style="font-family:Inter,Arial,sans-serif;max-width:520px;margin:auto;color:#0f1c1a">
  <div style="background:#005D4D;color:#fff;padding:20px 24px;border-radius:12px 12px 0 0">
    <h2 style="margin:0">Welcome to Pocket POS 🎉</h2>
  </div>
  <div style="border:1px solid #e4efec;border-top:0;padding:24px;border-radius:0 0 12px 12px">
    <p>Hi $ownerName,</p>
    <p>Your store <strong>$storeName</strong> has been created. Keep these details safe — you'll use them to log in:</p>
    <table style="border-collapse:collapse;margin:16px 0;font-size:15px">
      <tr><td style="padding:6px 12px;color:#5b6b68">Store ID</td><td style="padding:6px 12px;font-weight:700">$storeId</td></tr>
      <tr><td style="padding:6px 12px;color:#5b6b68">Username</td><td style="padding:6px 12px;font-weight:700">$username</td></tr>
    </table>
    <p>Your store is pending approval and will go live shortly. Once approved, sign in with your Store ID, username and password.</p>
    <p style="margin-top:20px">
      <a href="https://mypocketpos.in/?app=1" style="background:#005D4D;color:#fff;text-decoration:none;padding:10px 18px;border-radius:8px;font-weight:600">Open Pocket POS</a>
    </p>
    <p style="color:#5b6b68;font-size:13px;margin-top:20px">Need help? Reply to this email or write to ${NotificationConfig.adminEmail}.</p>
  </div>
</div>''';
  }

  static String _adminHtml({
    required String storeId,
    required String storeName,
    required String ownerName,
    required String username,
    required String ownerEmail,
    String? ownerMobile,
  }) {
    return '''
<div style="font-family:Inter,Arial,sans-serif;max-width:520px;margin:auto;color:#0f1c1a">
  <h3>New store registered</h3>
  <table style="border-collapse:collapse;font-size:15px">
    <tr><td style="padding:6px 12px;color:#5b6b68">Store</td><td style="padding:6px 12px;font-weight:700">$storeName</td></tr>
    <tr><td style="padding:6px 12px;color:#5b6b68">Store ID</td><td style="padding:6px 12px">$storeId</td></tr>
    <tr><td style="padding:6px 12px;color:#5b6b68">Owner</td><td style="padding:6px 12px">$ownerName</td></tr>
    <tr><td style="padding:6px 12px;color:#5b6b68">Username</td><td style="padding:6px 12px">$username</td></tr>
    <tr><td style="padding:6px 12px;color:#5b6b68">Email</td><td style="padding:6px 12px">$ownerEmail</td></tr>
    <tr><td style="padding:6px 12px;color:#5b6b68">Mobile</td><td style="padding:6px 12px">${ownerMobile ?? '-'}</td></tr>
  </table>
  <p style="color:#5b6b68;font-size:13px">Approve it from the platform admin screen.</p>
</div>''';
  }
}

/// Single wiring point. To change a vendor, replace the provider here.
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService(
    // Registration emails are sent SERVER-SIDE by the `onStoreCreated` Cloud
    // Function (the Resend key never ships in the app), so the client email
    // channel is a no-op. If you later need on-demand client emails, add a
    // secure proxy (a callable Cloud Function) as the EmailProvider here.
    email: const NoopEmailProvider(),
    // SMS / WhatsApp: swap these for Twilio/Gupshup/etc. when ready.
    sms: const NoopSmsProvider(),
    whatsapp: const NoopWhatsAppProvider(),
  );
});
