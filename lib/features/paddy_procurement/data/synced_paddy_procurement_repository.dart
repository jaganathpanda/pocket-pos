import '../domain/paddy_procurement.dart';
import '../domain/paddy_procurement_repository.dart';

/// Persists paddy procurement to BOTH local Drift and Firestore.
///
/// - Local Drift is the source of truth: it owns the integer ids and serves all
///   reads/streams so the module works fully offline and instantly.
/// - Every write is mirrored to Firestore using the SAME id (write-through), so
///   the cloud stays a copy for backup / other devices. Cloud mirroring is
///   best-effort — a cloud failure never blocks the local save.
///
/// [_cloud] is null when there is no active store (mirroring is simply skipped).
class SyncedPaddyProcurementRepository implements PaddyProcurementRepository {
  SyncedPaddyProcurementRepository(this._local, this._cloud);

  final PaddyProcurementRepository _local;
  final PaddyProcurementRepository? _cloud;

  // ── Reads: cloud when a store is active (so other devices see the data;
  // Firestore's on-device cache still serves these reads offline), else local.
  PaddyProcurementRepository get _reader => _cloud ?? _local;

  @override
  Stream<List<PaddyProcurement>> watchAll({
    DateTime? fromDate,
    DateTime? toDate,
    String? partyName,
    String? procurementType,
  }) =>
      _reader.watchAll(
        fromDate: fromDate,
        toDate: toDate,
        partyName: partyName,
        procurementType: procurementType,
      );

  @override
  Future<PaddyProcurement?> getProcurement(int id) =>
      _reader.getProcurement(id);

  @override
  Future<PaddyProcurement?> findByVehicleEntryId(int vehicleEntryId) =>
      _local.findByVehicleEntryId(vehicleEntryId);

  @override
  Future<double> getRemainingStock(int id) => _reader.getRemainingStock(id);

  // ── Writes: local first (authoritative), then mirror to cloud ───────────────
  @override
  Future<int> createProcurement(PaddyProcurementCompanion data) async {
    final id = await _local.createProcurement(data);
    _mirror(id);
    return id;
  }

  @override
  Future<void> updateProcurement(PaddyProcurementCompanion data) async {
    await _local.updateProcurement(data);
    if (data.id != null) _mirror(data.id!);
  }

  @override
  Future<void> deleteProcurement(int id) async {
    await _local.deleteProcurement(id);
    _fire(() => _cloud?.deleteProcurement(id));
  }

  @override
  Future<void> completeProcurement(int id) async {
    await _local.completeProcurement(id);
    _fire(() => _cloud?.completeProcurement(id));
  }

  @override
  Future<void> cancelProcurement(int id) async {
    await _local.cancelProcurement(id);
    _fire(() => _cloud?.cancelProcurement(id));
  }

  @override
  Future<void> deductStock(int id, double quantity) async {
    await _local.deductStock(id, quantity);
    _fire(() => _cloud?.deductStock(id, quantity));
  }

  /// Push the current local state of [id] to Firestore (create or update by id).
  void _mirror(int id) {
    final cloud = _cloud;
    if (cloud == null) return;
    _fire(() async {
      final model = await _local.getProcurement(id);
      if (model != null) {
        // updateProcurement writes with SetOptions(merge:true), so it upserts:
        // it creates the cloud doc on first mirror and updates it thereafter.
        await cloud.updateProcurement(PaddyProcurementCompanion.fromModel(model));
      }
    });
  }

  /// Fire-and-forget: mirror failures (e.g. offline) must not break the local
  /// save. Firestore's own offline queue syncs cloud writes when back online.
  void _fire(Future<void>? Function() op) {
    final future = op();
    if (future != null) future.catchError((_) {});
  }
}
