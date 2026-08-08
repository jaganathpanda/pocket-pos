/// Firestore document: `stores/{storeId}/settings/discount_policy`
///
/// Controls whether bill-level discounts are enabled and the maximum allowed
/// percentage. This app uses bill-level percentage discounts only.
class DiscountPolicy {
  const DiscountPolicy({
    required this.enabled,
    required this.billLevelOnly,
    required this.percentageOnly,
    required this.maxBillDiscountPercent,
  });

  const DiscountPolicy.defaults()
      : enabled = true,
        billLevelOnly = true,
        percentageOnly = true,
        maxBillDiscountPercent = 15;

  final bool enabled;
  final bool billLevelOnly;
  final bool percentageOnly;
  final double maxBillDiscountPercent;

  static DiscountPolicy fromFirestoreMap(Map<String, dynamic>? map) {
    if (map == null) return const DiscountPolicy.defaults();
    final max = (map['maxBillDiscountPercent'] as num?)?.toDouble() ?? 15;
    return DiscountPolicy(
      enabled: map['enabled'] != false,
      billLevelOnly: map['billLevelOnly'] != false,
      percentageOnly: map['percentageOnly'] != false,
      maxBillDiscountPercent: max.clamp(0, 100).toDouble(),
    );
  }

  Map<String, dynamic> toFirestoreMap() {
    return {
      'enabled': enabled,
      'billLevelOnly': billLevelOnly,
      'percentageOnly': percentageOnly,
      'maxBillDiscountPercent': maxBillDiscountPercent.clamp(0, 100),
    };
  }

  DiscountPolicy copyWith({
    bool? enabled,
    bool? billLevelOnly,
    bool? percentageOnly,
    double? maxBillDiscountPercent,
  }) {
    return DiscountPolicy(
      enabled: enabled ?? this.enabled,
      billLevelOnly: billLevelOnly ?? this.billLevelOnly,
      percentageOnly: percentageOnly ?? this.percentageOnly,
      maxBillDiscountPercent:
          maxBillDiscountPercent ?? this.maxBillDiscountPercent,
    );
  }
}