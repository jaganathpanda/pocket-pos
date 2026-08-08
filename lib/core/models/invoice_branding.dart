/// Firestore document: `stores/{storeId}/settings/invoice_branding`
///
/// Controls what appears on every printed receipt / PDF invoice: the display
/// name, address, phone, email, GSTIN, and the prefix used when generating
/// invoice numbers (e.g. "INV", "BILL", "REC").
class InvoiceBranding {
  const InvoiceBranding({
    this.displayName = '',
    this.address = '',
    this.phone = '',
    this.email = '',
    this.gstin = '',
    this.invoicePrefix = 'INV',
  });

  const InvoiceBranding.defaults()
      : displayName = '',
        address = '',
        phone = '',
        email = '',
        gstin = '',
        invoicePrefix = 'INV';

  /// Store display name shown on the invoice header.
  /// Falls back to the registered store name when empty.
  final String displayName;

  /// Multi-line address printed below the store name.
  final String address;

  /// Phone / mobile printed on the invoice.
  final String phone;

  /// Email printed on the invoice.
  final String email;

  /// GSTIN (GST registration number) printed on the invoice.
  final String gstin;

  /// Short prefix used when generating invoice numbers, e.g. "INV" → "INV-123456".
  /// Restricted to 1–8 uppercase characters.
  final String invoicePrefix;

  // ── Serialization ───────────────────────────────────────────────────────────

  static InvoiceBranding fromFirestoreMap(Map<String, dynamic>? map) {
    if (map == null) return const InvoiceBranding.defaults();
    String s(String key) {
      final v = map[key];
      return (v is String) ? v.trim() : '';
    }

    final prefix = s('invoicePrefix').toUpperCase();
    return InvoiceBranding(
      displayName: s('displayName'),
      address: s('address'),
      phone: s('phone'),
      email: s('email'),
      gstin: s('gstin'),
      invoicePrefix: prefix.isEmpty ? 'INV' : prefix,
    );
  }

  Map<String, dynamic> toFirestoreMap() {
    final prefix = invoicePrefix.trim().toUpperCase();
    return {
      'displayName': displayName,
      'address': address,
      'phone': phone,
      'email': email,
      'gstin': gstin,
      'invoicePrefix': prefix.isEmpty ? 'INV' : prefix,
    };
  }

  InvoiceBranding copyWith({
    String? displayName,
    String? address,
    String? phone,
    String? email,
    String? gstin,
    String? invoicePrefix,
  }) {
    return InvoiceBranding(
      displayName: displayName ?? this.displayName,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      gstin: gstin ?? this.gstin,
      invoicePrefix: invoicePrefix ?? this.invoicePrefix,
    );
  }
}
