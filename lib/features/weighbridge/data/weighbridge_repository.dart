import 'package:pocket_pos/features/weighbridge/domain/vehicle_entry.dart';

abstract class WeighbridgeRepository {
  /// Live stream of entries with optional filters.
  Stream<List<VehicleEntry>> watchAll({
    DateTime? fromDate,
    DateTime? toDate,
    String? vehicleNo,
    String? partyName,
  });

  Stream<VehicleEntry?> watchEntry(int id);
  Future<VehicleEntry?> getEntry(int id);

  Future<int> createEntry(VehicleEntryCompanion data);

  Future<void> updateEntry(VehicleEntryCompanion data);

  Future<void> deleteEntry(int id);

  /// Marks an entry as complete, optionally sets the completion code.
  Future<void> markComplete(int id, {String? completeCode});

  // ── Approval workflow ──
  /// Entries awaiting approval (status == 'pending'). If [approverUid] is given,
  /// only those routed to that miller.
  Stream<List<VehicleEntry>> watchPending({String? approverUid});

  /// Entries created by a given operator (for their dashboard).
  Stream<List<VehicleEntry>> watchByCreator(String createdByUid);

  /// Miller approves a pending entry.
  Future<void> approveEntry(int id,
      {required String approvedByUid, String? approverName});

  /// Miller rejects a pending entry with a reason.
  Future<void> rejectEntry(int id,
      {required String approvedByUid, String? reason});
}
