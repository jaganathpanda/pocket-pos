/// Milling configuration stored in `settings/milling_config`.
/// Holds mill-wide defaults used to auto-calculate milling charge invoices.
class MillingConfig {
  const MillingConfig({
    required this.defaultBasis,
    required this.defaultRatePerUnit,
    required this.defaultDryingChargePerUnit,
    required this.defaultLoadingChargePerUnit,
    required this.defaultBaggingChargePerUnit,
    required this.defaultDeductionPerUnit,
    required this.defaultGstPercent,
    required this.tdsApplicable,
    required this.yieldWarningThresholdPercent,
  });

  /// Basis on which milling charge is calculated.
  final MillingChargeBasis defaultBasis;

  /// Base milling charge (₹ per quintal/bag, default rate).
  final double defaultRatePerUnit;

  /// Drying surcharge per unit.
  final double defaultDryingChargePerUnit;

  /// Loading/unloading charge per unit.
  final double defaultLoadingChargePerUnit;

  /// Stitching/bagging charge per unit.
  final double defaultBaggingChargePerUnit;

  /// Any contracted deduction per unit.
  final double defaultDeductionPerUnit;

  /// GST percentage applicable on milling charges (0, 5, 12, 18).
  final double defaultGstPercent;

  /// Whether TDS is to be deducted on milling invoices.
  final bool tdsApplicable;

  /// Warn if output rice yield falls below this % of input paddy.
  final double yieldWarningThresholdPercent;

  /// Factory: sensible defaults for a new rice mill store.
  factory MillingConfig.defaults() => const MillingConfig(
        defaultBasis: MillingChargeBasis.perInputQuintal,
        defaultRatePerUnit: 150.0,
        defaultDryingChargePerUnit: 0.0,
        defaultLoadingChargePerUnit: 0.0,
        defaultBaggingChargePerUnit: 0.0,
        defaultDeductionPerUnit: 0.0,
        defaultGstPercent: 5.0,
        tdsApplicable: false,
        yieldWarningThresholdPercent: 65.0,
      );

  factory MillingConfig.fromMap(Map<String, dynamic> map) => MillingConfig(
        defaultBasis: MillingChargeBasis.values.firstWhere(
          (b) => b.name == (map['defaultBasis'] as String?),
          orElse: () => MillingChargeBasis.perInputQuintal,
        ),
        defaultRatePerUnit:
            (map['defaultRatePerUnit'] as num?)?.toDouble() ?? 150.0,
        defaultDryingChargePerUnit:
            (map['defaultDryingChargePerUnit'] as num?)?.toDouble() ?? 0.0,
        defaultLoadingChargePerUnit:
            (map['defaultLoadingChargePerUnit'] as num?)?.toDouble() ?? 0.0,
        defaultBaggingChargePerUnit:
            (map['defaultBaggingChargePerUnit'] as num?)?.toDouble() ?? 0.0,
        defaultDeductionPerUnit:
            (map['defaultDeductionPerUnit'] as num?)?.toDouble() ?? 0.0,
        defaultGstPercent:
            (map['defaultGstPercent'] as num?)?.toDouble() ?? 5.0,
        tdsApplicable: (map['tdsApplicable'] as bool?) ?? false,
        yieldWarningThresholdPercent:
            (map['yieldWarningThresholdPercent'] as num?)?.toDouble() ?? 65.0,
      );

  Map<String, dynamic> toMap() => {
        'defaultBasis': defaultBasis.name,
        'defaultRatePerUnit': defaultRatePerUnit,
        'defaultDryingChargePerUnit': defaultDryingChargePerUnit,
        'defaultLoadingChargePerUnit': defaultLoadingChargePerUnit,
        'defaultBaggingChargePerUnit': defaultBaggingChargePerUnit,
        'defaultDeductionPerUnit': defaultDeductionPerUnit,
        'defaultGstPercent': defaultGstPercent,
        'tdsApplicable': tdsApplicable,
        'yieldWarningThresholdPercent': yieldWarningThresholdPercent,
      };

  MillingConfig copyWith({
    MillingChargeBasis? defaultBasis,
    double? defaultRatePerUnit,
    double? defaultDryingChargePerUnit,
    double? defaultLoadingChargePerUnit,
    double? defaultBaggingChargePerUnit,
    double? defaultDeductionPerUnit,
    double? defaultGstPercent,
    bool? tdsApplicable,
    double? yieldWarningThresholdPercent,
  }) =>
      MillingConfig(
        defaultBasis: defaultBasis ?? this.defaultBasis,
        defaultRatePerUnit: defaultRatePerUnit ?? this.defaultRatePerUnit,
        defaultDryingChargePerUnit:
            defaultDryingChargePerUnit ?? this.defaultDryingChargePerUnit,
        defaultLoadingChargePerUnit:
            defaultLoadingChargePerUnit ?? this.defaultLoadingChargePerUnit,
        defaultBaggingChargePerUnit:
            defaultBaggingChargePerUnit ?? this.defaultBaggingChargePerUnit,
        defaultDeductionPerUnit:
            defaultDeductionPerUnit ?? this.defaultDeductionPerUnit,
        defaultGstPercent: defaultGstPercent ?? this.defaultGstPercent,
        tdsApplicable: tdsApplicable ?? this.tdsApplicable,
        yieldWarningThresholdPercent:
            yieldWarningThresholdPercent ?? this.yieldWarningThresholdPercent,
      );
}

/// Determines whether milling charge is calculated on input paddy or output rice.
enum MillingChargeBasis {
  perInputQuintal,
  perOutputQuintal,
  perBag;

  String get label => switch (this) {
        MillingChargeBasis.perInputQuintal => 'Per Input Quintal (Paddy)',
        MillingChargeBasis.perOutputQuintal => 'Per Output Quintal (Rice)',
        MillingChargeBasis.perBag => 'Per Bag',
      };
}
