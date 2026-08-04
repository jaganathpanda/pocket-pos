/// Status of a milling run.
enum MillRunStatus {
  draft,
  completed,
  cancelled;

  String get label => switch (this) {
        MillRunStatus.draft => 'Draft',
        MillRunStatus.completed => 'Completed',
        MillRunStatus.cancelled => 'Cancelled',
      };

  static MillRunStatus fromString(String? v) => switch (v) {
        'completed' => MillRunStatus.completed,
        'cancelled' => MillRunStatus.cancelled,
        _ => MillRunStatus.draft,
      };
}

/// Header of a single milling run — records paddy consumed.
class MillRun {
  const MillRun({
    required this.id,
    required this.runDate,
    required this.warehouseId,
    required this.paddyProductId,
    required this.paddyConsumedKg,
    required this.status,
    required this.createdAt,
    this.lotNumber,
    this.note,
  });

  final int id;
  final DateTime runDate;
  final int warehouseId;

  /// Paddy product consumed as input.
  final int paddyProductId;

  /// Total paddy consumed (in kg or quintal — whatever unit the product uses).
  final double paddyConsumedKg;

  final MillRunStatus status;
  final DateTime createdAt;

  /// Optional lot/batch reference (e.g. FCI lot number).
  final String? lotNumber;
  final String? note;
}

/// One output line of a milling run (rice, bran, broken rice, husk, etc.).
class MillRunOutput {
  const MillRunOutput({
    required this.id,
    required this.millRunId,
    required this.productId,
    required this.quantityKg,
    this.grade,
  });

  final int id;
  final int millRunId;
  final int productId;
  final double quantityKg;

  /// Optional quality/grade note (e.g. "FAQ", "Grade A").
  final String? grade;
}

/// Joined view returned by the repository for list/detail screens.
class MillRunWithOutputs {
  const MillRunWithOutputs({
    required this.run,
    required this.outputs,
    this.warehouseName,
    this.paddyProductName,
    this.outputProducts = const {},
  });

  final MillRun run;
  final List<MillRunOutput> outputs;
  final String? warehouseName;
  final String? paddyProductName;

  /// Map of productId → product name for output lines.
  final Map<int, String> outputProducts;

  /// Total output across all lines.
  double get totalOutputKg =>
      outputs.fold(0, (sum, o) => sum + o.quantityKg);

  /// Yield % = totalOutput / paddyConsumed × 100
  double get yieldPercent => run.paddyConsumedKg == 0
      ? 0
      : (totalOutputKg / run.paddyConsumedKg) * 100;
}
