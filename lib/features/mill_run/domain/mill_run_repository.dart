import 'mill_run_models.dart';

abstract class MillRunRepository {
  /// Live stream of all mill runs (newest first), with outputs joined.
  Stream<List<MillRunWithOutputs>> watchAll();

  /// Create a new draft run. Returns the generated run id.
  Future<int> createRun({
    required int warehouseId,
    required int paddyProductId,
    required double paddyConsumedKg,
    required DateTime runDate,
    String? lotNumber,
    String? note,
  });

  /// Update header fields of a draft run.
  Future<void> updateRun({
    required int id,
    required int warehouseId,
    required int paddyProductId,
    required double paddyConsumedKg,
    required DateTime runDate,
    String? lotNumber,
    String? note,
  });

  /// Add an output line to a draft run.
  Future<void> addOutput({
    required int millRunId,
    required int productId,
    required double quantityKg,
    String? grade,
  });

  /// Remove an output line from a draft run.
  Future<void> removeOutput(int outputId);

  /// Complete the run:
  ///   1. Deduct paddyConsumedKg from paddy product inventory.
  ///   2. Stock-in each output product.
  ///   3. Mark status = 'completed'.
  Future<void> complete(int millRunId);

  /// Cancel a draft run (no inventory effect).
  Future<void> cancel(int millRunId);

  /// Hard-delete a draft or cancelled run and its outputs.
  Future<void> deleteRun(int millRunId);
}
