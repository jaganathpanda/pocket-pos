import 'package:pocket_pos/features/weighbridge/domain/vehicle_entry.dart';

abstract class WeighbridgeRepository {
  /// Live stream of entries with optional filters.
  Stream<List<VehicleEntry>> watchAll({
    DateTime? fromDate,
    DateTime? toDate,
    String? vehicleNo,
    String? partyName,
  });

  Future<VehicleEntry?> getEntry(int id);

  Future<int> createEntry(VehicleEntryCompanion data);

  Future<void> updateEntry(VehicleEntryCompanion data);

  Future<void> deleteEntry(int id);

  /// Marks an entry as complete, optionally sets the completion code.
  Future<void> markComplete(int id, {String? completeCode});
}
