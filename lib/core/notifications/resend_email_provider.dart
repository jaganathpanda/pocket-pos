import 'dart:convert';

import 'package:http/http.dart' as http;

import 'notification_models.dart';
import 'notification_providers.dart';

/// Resend (https://resend.com) implementation of [EmailProvider].
///
/// To switch vendors later, write another `EmailProvider` (e.g.
/// `SendgridEmailProvider`) and swap it in `notificationServiceProvider` —
/// nothing else in the app changes.
class ResendEmailProvider implements EmailProvider {
  ResendEmailProvider({
    required this.apiKey,
    required this.defaultFrom,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String apiKey;

  /// Default sender, e.g. "Pocket POS <onboarding@resend.dev>". Use a verified
  /// domain sender in production ("Pocket POS <no-reply@mypocketpos.in>").
  final String defaultFrom;

  final http.Client _client;

  static final Uri _endpoint = Uri.parse('https://api.resend.com/emails');

  @override
  Future<NotificationResult> sendEmail(EmailMessage m) async {
    if (apiKey.isEmpty) {
      return NotificationResult.fail(
          NotificationChannel.email, 'Resend API key not configured');
    }
    try {
      final resp = await _client.post(
        _endpoint,
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'from': m.from ?? defaultFrom,
          'to': m.to,
          'subject': m.subject,
          'html': m.html,
          if (m.replyTo != null) 'reply_to': m.replyTo,
        }),
      );
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        String? id;
        try {
          id = (jsonDecode(resp.body) as Map<String, dynamic>)['id'] as String?;
        } catch (_) {}
        return NotificationResult.ok(NotificationChannel.email, id: id);
      }
      return NotificationResult.fail(NotificationChannel.email,
          'Resend HTTP ${resp.statusCode}: ${resp.body}');
    } catch (e) {
      return NotificationResult.fail(NotificationChannel.email, '$e');
    }
  }
}
