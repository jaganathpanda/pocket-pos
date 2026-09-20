class QuickCheckoutConfig {
  const QuickCheckoutConfig({
    required this.enabled,
    required this.quickInvoiceEnabled,
  });

  const QuickCheckoutConfig.defaults()
      : enabled = false,
        quickInvoiceEnabled = false;

  final bool enabled;
  final bool quickInvoiceEnabled;

  static QuickCheckoutConfig fromFirestoreMap(Map<String, dynamic>? map) {
    if (map == null) return const QuickCheckoutConfig.defaults();
    return QuickCheckoutConfig(
      enabled: map['enabled'] == true,
      quickInvoiceEnabled: map['quickInvoiceEnabled'] == true,
    );
  }

  Map<String, dynamic> toFirestoreMap() {
    return {
      'enabled': enabled,
      'quickInvoiceEnabled': quickInvoiceEnabled,
    };
  }
}
