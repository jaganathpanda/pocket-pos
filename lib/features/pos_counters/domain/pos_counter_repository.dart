import '../../../core/database/app_database.dart';

/// A POS user together with the counter they are bound to.
class PosUserRow {
  const PosUserRow({required this.user, this.counterName});

  final User user;
  final String? counterName;
}

abstract class PosCounterRepository {
  Stream<List<PosCounter>> watchCounters();
  Future<List<PosCounter>> activeCounters();
  Future<int> addCounter(String name);
  Future<void> renameCounter(int id, String name);
  Future<void> setCounterActive(int id, bool active);

  /// POS users are those bound to a counter (`posCounterId` is not null).
  Stream<List<PosUserRow>> watchPosUsers();
  Future<void> addPosUser({
    required String username,
    required String pin,
    required int counterId,
  });
  Future<void> setUserActive(int userId, bool active);
}
