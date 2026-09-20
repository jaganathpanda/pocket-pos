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
    this.quickCartTokenStart = 1,
    this.financialYearStartMonth = 4,
    this.selectedFinancialYearStartYear = 0,
  });

  const InvoiceBranding.defaults()
      : displayName = '',
        address = '',
        phone = '',
        email = '',
        gstin = '',
        invoicePrefix = 'INV',
        quickCartTokenStart = 1,
        financialYearStartMonth = 4,
        selectedFinancialYearStartYear = 0;

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

  /// Starting token number for quick carts (e.g., 100, 101, 102...).
  /// Used when no customer name/mobile is provided.
  final int quickCartTokenStart;

  /// Month that starts the store's financial year. Defaults to April.
  final int financialYearStartMonth;

  /// Financial-year start year selected in settings. `0` means current year.
  final int selectedFinancialYearStartYear;

  // ── Serialization ───────────────────────────────────────────────────────────

  static InvoiceBranding fromFirestoreMap(Map<String, dynamic>? map) {
    if (map == null) return const InvoiceBranding.defaults();
    String s(String key) {
      final v = map[key];
      return (v is String) ? v.trim() : '';
    }

    int i(String key) {
      final v = map[key];
      return (v is int)
          ? v
          : (v is num)
              ? v.toInt()
              : 1;
    }

    final prefix = s('invoicePrefix').toUpperCase();
    return InvoiceBranding(
      displayName: s('displayName'),
      address: s('address'),
      phone: s('phone'),
      email: s('email'),
      gstin: s('gstin'),
      invoicePrefix: prefix.isEmpty ? 'INV' : prefix,
      quickCartTokenStart: i('quickCartTokenStart'),
      financialYearStartMonth: i('financialYearStartMonth').clamp(1, 12),
      selectedFinancialYearStartYear: i('selectedFinancialYearStartYear'),
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
      'quickCartTokenStart': quickCartTokenStart,
      'financialYearStartMonth': financialYearStartMonth.clamp(1, 12),
      'selectedFinancialYearStartYear': selectedFinancialYearStartYear,
    };
  }

  InvoiceBranding copyWith({
    String? displayName,
    String? address,
    String? phone,
    String? email,
    String? gstin,
    String? invoicePrefix,
    int? quickCartTokenStart,
    int? financialYearStartMonth,
    int? selectedFinancialYearStartYear,
  }) {
    return InvoiceBranding(
      displayName: displayName ?? this.displayName,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      gstin: gstin ?? this.gstin,
      invoicePrefix: invoicePrefix ?? this.invoicePrefix,
      quickCartTokenStart: quickCartTokenStart ?? this.quickCartTokenStart,
      financialYearStartMonth:
          financialYearStartMonth ?? this.financialYearStartMonth,
      selectedFinancialYearStartYear:
          selectedFinancialYearStartYear ?? this.selectedFinancialYearStartYear,
    );
  }
}
