enum PrinterConnectionOption { bluetooth, usb }

class PrinterConfig {
  const PrinterConfig({
    required this.enabled,
    required this.allowPdfFallback,
    required this.connection,
    required this.deviceIdentifier,
  });

  const PrinterConfig.defaults()
      : enabled = false,
        allowPdfFallback = false,
        connection = PrinterConnectionOption.bluetooth,
        deviceIdentifier = '';

  final bool enabled;
  final bool allowPdfFallback;
  final PrinterConnectionOption connection;
  final String deviceIdentifier;

  bool get hasDeviceIdentifier => deviceIdentifier.trim().isNotEmpty;

  PrinterConfig copyWith({
    bool? enabled,
    bool? allowPdfFallback,
    PrinterConnectionOption? connection,
    String? deviceIdentifier,
  }) {
    return PrinterConfig(
      enabled: enabled ?? this.enabled,
      allowPdfFallback: allowPdfFallback ?? this.allowPdfFallback,
      connection: connection ?? this.connection,
      deviceIdentifier: deviceIdentifier ?? this.deviceIdentifier,
    );
  }

  static PrinterConfig fromFirestoreMap(Map<String, dynamic>? map) {
    if (map == null) return const PrinterConfig.defaults();

    final enabled = map['enabled'] == true;
  final allowPdfFallback = map['allowPdfFallback'] == true;
    final rawConnection = (map['connection'] as String?)?.trim().toLowerCase();
    final connection = rawConnection == 'usb'
        ? PrinterConnectionOption.usb
        : PrinterConnectionOption.bluetooth;
    final identifier = (map['deviceIdentifier'] as String?)?.trim() ?? '';

    return PrinterConfig(
      enabled: enabled,
      allowPdfFallback: allowPdfFallback,
      connection: connection,
      deviceIdentifier: identifier,
    );
  }

  Map<String, dynamic> toFirestoreMap() {
    return {
      'enabled': enabled,
      'allowPdfFallback': allowPdfFallback,
      'connection': connection.name,
      'deviceIdentifier': deviceIdentifier.trim(),
    };
  }
}
