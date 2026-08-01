import 'package:flutter/foundation.dart';

import 'notification_models.dart';

/// One tiny interface per channel. A vendor implements exactly one of these;
/// [NotificationService] never depends on a concrete vendor.
abstract class EmailProvider {
  Future<NotificationResult> sendEmail(EmailMessage message);
}

abstract class SmsProvider {
  Future<NotificationResult> sendSms(SmsMessage message);
}

abstract class WhatsAppProvider {
  Future<NotificationResult> sendWhatsApp(WhatsAppMessage message);
}

/// Default no-op providers used until a real vendor is wired in. They log in
/// debug and report "skipped" so the app keeps working with SMS/WhatsApp off.
class NoopEmailProvider implements EmailProvider {
  const NoopEmailProvider();
  @override
  Future<NotificationResult> sendEmail(EmailMessage m) async {
    if (kDebugMode) print('[notify] email skipped → ${m.to}: ${m.subject}');
    return NotificationResult.skipped(NotificationChannel.email);
  }
}

class NoopSmsProvider implements SmsProvider {
  const NoopSmsProvider();
  @override
  Future<NotificationResult> sendSms(SmsMessage m) async {
    if (kDebugMode) print('[notify] sms skipped → ${m.to}: ${m.body}');
    return NotificationResult.skipped(NotificationChannel.sms);
  }
}

class NoopWhatsAppProvider implements WhatsAppProvider {
  const NoopWhatsAppProvider();
  @override
  Future<NotificationResult> sendWhatsApp(WhatsAppMessage m) async {
    if (kDebugMode) print('[notify] whatsapp skipped → ${m.to}: ${m.body}');
    return NotificationResult.skipped(NotificationChannel.whatsapp);
  }
}
