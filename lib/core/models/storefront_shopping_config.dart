import 'package:cloud_firestore/cloud_firestore.dart';

class StorefrontShoppingConfig {
  const StorefrontShoppingConfig({
    required this.allowAnonymousShopping,
    required this.autoWindowEnabled,
    this.windowStartAtUtc,
    this.windowEndAtUtc,
  });

  const StorefrontShoppingConfig.defaults()
      : allowAnonymousShopping = false,
        autoWindowEnabled = false,
        windowStartAtUtc = null,
        windowEndAtUtc = null;

  final bool allowAnonymousShopping;
  final bool autoWindowEnabled;
  final DateTime? windowStartAtUtc;
  final DateTime? windowEndAtUtc;

  bool get hasValidWindow {
    final start = windowStartAtUtc;
    final end = windowEndAtUtc;
    if (start == null || end == null) return false;
    return !end.isBefore(start);
  }

  bool isEnabledNow(DateTime nowUtc) {
    if (!allowAnonymousShopping) return false;
    if (!autoWindowEnabled) return true;
    if (!hasValidWindow) return false;
    final now = nowUtc.toUtc();
    final start = windowStartAtUtc!.toUtc();
    final end = windowEndAtUtc!.toUtc();
    return !now.isBefore(start) && !now.isAfter(end);
  }

  StorefrontShoppingConfig copyWith({
    bool? allowAnonymousShopping,
    bool? autoWindowEnabled,
    DateTime? windowStartAtUtc,
    DateTime? windowEndAtUtc,
    bool clearWindowStartAtUtc = false,
    bool clearWindowEndAtUtc = false,
  }) {
    return StorefrontShoppingConfig(
      allowAnonymousShopping:
          allowAnonymousShopping ?? this.allowAnonymousShopping,
      autoWindowEnabled: autoWindowEnabled ?? this.autoWindowEnabled,
      windowStartAtUtc: clearWindowStartAtUtc
          ? null
          : (windowStartAtUtc ?? this.windowStartAtUtc),
      windowEndAtUtc:
          clearWindowEndAtUtc ? null : (windowEndAtUtc ?? this.windowEndAtUtc),
    );
  }

  Map<String, dynamic> toFirestoreMap() {
    return {
      'allowAnonymousShopping': allowAnonymousShopping,
      'autoWindowEnabled': autoWindowEnabled,
      if (windowStartAtUtc != null) 'windowStartAt': windowStartAtUtc,
      if (windowEndAtUtc != null) 'windowEndAt': windowEndAtUtc,
    };
  }

  static DateTime? _readTimestamp(dynamic raw) {
    if (raw == null) return null;
    if (raw is Timestamp) return raw.toDate().toUtc();
    if (raw is DateTime) return raw.toUtc();
    return null;
  }

  static StorefrontShoppingConfig fromFirestoreMap(Map<String, dynamic>? map) {
    if (map == null) return const StorefrontShoppingConfig.defaults();
    return StorefrontShoppingConfig(
      allowAnonymousShopping: map['allowAnonymousShopping'] == true,
      autoWindowEnabled: map['autoWindowEnabled'] == true,
      windowStartAtUtc: _readTimestamp(map['windowStartAt']),
      windowEndAtUtc: _readTimestamp(map['windowEndAt']),
    );
  }
}
