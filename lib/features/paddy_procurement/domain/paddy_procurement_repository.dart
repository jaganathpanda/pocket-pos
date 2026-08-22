import 'package:drift/drift.dart';
import 'paddy_procurement.dart';

abstract class PaddyProcurementRepository {
  /// Live stream of all procurements with optional filters
  Stream<List<PaddyProcurement>> watchAll({
    DateTime? fromDate,
    DateTime? toDate,
    String? partyName,
    String? procurementType,
  });

  /// Get a single procurement by ID
  Future<PaddyProcurement?> getProcurement(int id);

  /// Create a new procurement draft
  Future<int> createProcurement(PaddyProcurementCompanion data);

  /// Update an existing procurement
  Future<void> updateProcurement(PaddyProcurementCompanion data);

  /// Delete a draft procurement
  Future<void> deleteProcurement(int id);

  /// Complete the procurement: updates inventory and stock
  Future<void> completeProcurement(int id);

  /// Cancel a draft procurement
  Future<void> cancelProcurement(int id);

  /// Get remaining stock for a procurement lot
  Future<double> getRemainingStock(int id);

  /// Deduct stock when used in mill run
  Future<void> deductStock(int id, double quantity);
}
