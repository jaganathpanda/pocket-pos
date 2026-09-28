class QuickCheckoutConfig {
  const QuickCheckoutConfig({required this.enabled});

  const QuickCheckoutConfig.defaults() : enabled = false;

  final bool enabled;

  static QuickCheckoutConfig fromFirestoreMap(Map<String, dynamic>? map) {
    if (map == null) return const QuickCheckoutConfig.defaults();
    return QuickCheckoutConfig(
      enabled: map['enabled'] == true,
    );
  }

  Map<String, dynamic> toFirestoreMap() {
    return {
      'enabled': enabled,
    };
  }
}
