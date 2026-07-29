import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../domain/pos_counter_repository.dart';

class PosCounterRepositoryImpl implements PosCounterRepository {
  PosCounterRepositoryImpl(this._db);

  final AppDatabase _db;

  @override
  Stream<List<PosCounter>> watchCounters() {
    return (_db.select(_db.posCounters)
          ..orderBy([(c) => OrderingTerm.asc(c.name)]))
        .watch();
  }

  @override
  Future<List<PosCounter>> activeCounters() {
    return (_db.select(_db.posCounters)
          ..where((c) => c.isActive.equals(true))
          ..orderBy([(c) => OrderingTerm.asc(c.name)]))
        .get();
  }

  @override
  Future<int> addCounter(String name) {
    return _db.into(_db.posCounters).insert(
          PosCountersCompanion.insert(name: name.trim()),
        );
  }

  @override
  Future<void> renameCounter(int id, String name) {
    return (_db.update(_db.posCounters)..where((c) => c.id.equals(id)))
        .write(PosCountersCompanion(name: Value(name.trim())));
  }

  @override
  Future<void> setCounterActive(int id, bool active) {
    return (_db.update(_db.posCounters)..where((c) => c.id.equals(id)))
        .write(PosCountersCompanion(isActive: Value(active)));
  }

  @override
  Stream<List<PosUserRow>> watchPosUsers() {
    final query = _db.select(_db.users).join([
      leftOuterJoin(
        _db.posCounters,
        _db.posCounters.id.equalsExp(_db.users.posCounterId),
      ),
    ])
      ..where(_db.users.posCounterId.isNotNull())
      ..orderBy([OrderingTerm.asc(_db.users.username)]);

    return query.watch().map(
          (rows) => rows.map((r) {
            final user = r.readTable(_db.users);
            return PosUserRow(
              uid: '${user.id}',
              username: user.username,
              isActive: user.isActive,
              counterName: r.readTableOrNull(_db.posCounters)?.name,
            );
          }).toList(),
        );
  }

  @override
  Future<void> addPosUser({
    required String username,
    required String pin,
    required int counterId,
  }) async {
    final cashierRole = await (_db.select(_db.roles)
          ..where((r) => r.name.equals('cashier')))
        .getSingleOrNull();
    final roleId = cashierRole?.id ??
        await _db.into(_db.roles).insert(RolesCompanion.insert(name: 'cashier'));

    await _db.into(_db.users).insert(
          UsersCompanion.insert(
            username: username.trim(),
            passwordHash: pin.trim(),
            pinHash: pin.trim(),
            roleId: roleId,
            posCounterId: Value(counterId),
          ),
        );
  }

  @override
  Future<void> setUserActive(String uid, bool active) {
    final userId = int.tryParse(uid) ?? 0;
    return (_db.update(_db.users)..where((u) => u.id.equals(userId)))
        .write(UsersCompanion(isActive: Value(active)));
  }
}
