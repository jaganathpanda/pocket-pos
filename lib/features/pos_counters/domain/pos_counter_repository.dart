import '../../../core/database/app_database.dart';

/// A POS/staff user together with the counter they are bound to.
/// [uid] is a string so it works for both Drift (int id → string) and
/// Firestore (Firebase Auth uid).
class PosUserRow {
  const PosUserRow({
    required this.uid,
    required this.username,
    required this.isActive,
    this.counterName,
  });

  final String uid;
  final String username;
  final bool isActive;
  final String? counterName;
}

abstract class PosCounterRepository {
  Stream<List<PosCounter>> watchCounters();
  Future<List<PosCounter>> activeCounters();
  Future<int> addCounter(String name);
  Future<void> renameCounter(int id, String name);
  Future<void> setCounterActive(int id, bool active);

  /// POS users bound to a counter.
  Stream<List<PosUserRow>> watchPosUsers();
  Future<void> addPosUser({
    required String username,
    required String pin,
    required int counterId,
  });

  /// Millers (owner/super_admin/manager users) who can approve weighbridge
  /// entries — used to populate the operator's "Select Miller" dropdown.
  Stream<List<PosUserRow>> watchMillers();

  Future<void> setUserActive(String uid, bool active);
}
