class NotificationFeatures {
  const NotificationFeatures({
    required this.emailEnabled,
    required this.smsEnabled,
    required this.whatsappEnabled,
    this.emailFromAddress,
    this.smsFromNumber,
    this.whatsappFromNumber,
    this.emailApiKey,
    this.smsAccountSid,
    this.smsAuthToken,
    this.whatsappAccountSid,
    this.whatsappAuthToken,
  });

  const NotificationFeatures.defaults()
      : emailEnabled = false,
        smsEnabled = false,
        whatsappEnabled = false,
        emailFromAddress = null,
        smsFromNumber = null,
        whatsappFromNumber = null,
        emailApiKey = null,
        smsAccountSid = null,
        smsAuthToken = null,
        whatsappAccountSid = null,
        whatsappAuthToken = null;

  final bool emailEnabled;
  final bool smsEnabled;
  final bool whatsappEnabled;
  final String? emailFromAddress;
  final String? smsFromNumber;
  final String? whatsappFromNumber;
  final String? emailApiKey;
  final String? smsAccountSid;
  final String? smsAuthToken;
  final String? whatsappAccountSid;
  final String? whatsappAuthToken;

  NotificationFeatures copyWith({
    bool? emailEnabled,
    bool? smsEnabled,
    bool? whatsappEnabled,
    String? emailFromAddress,
    String? smsFromNumber,
    String? whatsappFromNumber,
    String? emailApiKey,
    String? smsAccountSid,
    String? smsAuthToken,
    String? whatsappAccountSid,
    String? whatsappAuthToken,
    bool clearEmailFromAddress = false,
    bool clearSmsFromNumber = false,
    bool clearWhatsappFromNumber = false,
    bool clearEmailApiKey = false,
    bool clearSmsAccountSid = false,
    bool clearSmsAuthToken = false,
    bool clearWhatsappAccountSid = false,
    bool clearWhatsappAuthToken = false,
  }) {
    return NotificationFeatures(
      emailEnabled: emailEnabled ?? this.emailEnabled,
      smsEnabled: smsEnabled ?? this.smsEnabled,
      whatsappEnabled: whatsappEnabled ?? this.whatsappEnabled,
      emailFromAddress: clearEmailFromAddress
          ? null
          : (emailFromAddress ?? this.emailFromAddress),
      smsFromNumber:
          clearSmsFromNumber ? null : (smsFromNumber ?? this.smsFromNumber),
      whatsappFromNumber: clearWhatsappFromNumber
          ? null
          : (whatsappFromNumber ?? this.whatsappFromNumber),
      emailApiKey:
          clearEmailApiKey ? null : (emailApiKey ?? this.emailApiKey),
      smsAccountSid:
          clearSmsAccountSid ? null : (smsAccountSid ?? this.smsAccountSid),
      smsAuthToken:
          clearSmsAuthToken ? null : (smsAuthToken ?? this.smsAuthToken),
      whatsappAccountSid: clearWhatsappAccountSid
          ? null
          : (whatsappAccountSid ?? this.whatsappAccountSid),
      whatsappAuthToken: clearWhatsappAuthToken
          ? null
          : (whatsappAuthToken ?? this.whatsappAuthToken),
    );
  }

  String? get emailFromAddressOrNull {
    final v = emailFromAddress?.trim();
    return (v == null || v.isEmpty) ? null : v;
  }

  String? get smsFromNumberOrNull {
    final v = smsFromNumber?.trim();
    return (v == null || v.isEmpty) ? null : v;
  }

  String? get whatsappFromNumberOrNull {
    final v = whatsappFromNumber?.trim();
    return (v == null || v.isEmpty) ? null : v;
  }

  String? _trimmedOrNull(String? value) {
    final v = value?.trim();
    return (v == null || v.isEmpty) ? null : v;
  }

  String? get emailApiKeyOrNull => _trimmedOrNull(emailApiKey);
  String? get smsAccountSidOrNull => _trimmedOrNull(smsAccountSid);
  String? get smsAuthTokenOrNull => _trimmedOrNull(smsAuthToken);
  String? get whatsappAccountSidOrNull => _trimmedOrNull(whatsappAccountSid);
  String? get whatsappAuthTokenOrNull => _trimmedOrNull(whatsappAuthToken);

  Map<String, dynamic> toFirestoreMap() {
    return {
      'email': {
        'enabled': emailEnabled,
        if (emailFromAddressOrNull != null)
          'fromAddress': emailFromAddressOrNull,
        if (emailApiKeyOrNull != null) 'apiKey': emailApiKeyOrNull,
      },
      'sms': {
        'enabled': smsEnabled,
        if (smsFromNumberOrNull != null) 'fromNumber': smsFromNumberOrNull,
        if (smsAccountSidOrNull != null) 'accountSid': smsAccountSidOrNull,
        if (smsAuthTokenOrNull != null) 'authToken': smsAuthTokenOrNull,
      },
      'whatsapp': {
        'enabled': whatsappEnabled,
        if (whatsappFromNumberOrNull != null)
          'fromNumber': whatsappFromNumberOrNull,
        if (whatsappAccountSidOrNull != null)
          'accountSid': whatsappAccountSidOrNull,
        if (whatsappAuthTokenOrNull != null)
          'authToken': whatsappAuthTokenOrNull,
      },
    };
  }

  static NotificationFeatures fromFirestoreMap(Map<String, dynamic>? map) {
    if (map == null) return const NotificationFeatures.defaults();
    bool readEnabled(String key) {
      final nested = map[key];
      if (nested is Map) {
        final enabled = nested['enabled'];
        if (enabled is bool) return enabled;
      }
      return false;
    }

    String? readString(String key, String nestedKey) {
      final nested = map[key];
      if (nested is Map) {
        final value = nested[nestedKey];
        if (value is String) {
          final trimmed = value.trim();
          if (trimmed.isNotEmpty) return trimmed;
        }
      }
      return null;
    }

    return NotificationFeatures(
      emailEnabled: readEnabled('email'),
      smsEnabled: readEnabled('sms'),
      whatsappEnabled: readEnabled('whatsapp'),
      emailFromAddress: readString('email', 'fromAddress'),
      smsFromNumber: readString('sms', 'fromNumber'),
      whatsappFromNumber: readString('whatsapp', 'fromNumber'),
      emailApiKey: readString('email', 'apiKey'),
      smsAccountSid: readString('sms', 'accountSid'),
      smsAuthToken: readString('sms', 'authToken'),
      whatsappAccountSid: readString('whatsapp', 'accountSid'),
      whatsappAuthToken: readString('whatsapp', 'authToken'),
    );
  }
}
