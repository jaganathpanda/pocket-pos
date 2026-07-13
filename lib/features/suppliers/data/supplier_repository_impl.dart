import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../domain/supplier_repository.dart';

class SupplierRepositoryImpl implements SupplierRepository {
  SupplierRepositoryImpl(this._db);

  final AppDatabase _db;

  @override
  Stream<List<Supplier>> watchAll() {
    return (_db.select(_db.suppliers)
          ..where((s) => s.isActive.equals(true))
          ..orderBy([(s) => OrderingTerm.asc(s.name)]))
        .watch();
  }

  @override
  Future<List<Supplier>> search(String query) {
    final q = '%$query%';
    return (_db.select(_db.suppliers)
          ..where((s) => s.name.like(q) | s.mobile.like(q) | s.gstNumber.like(q))
          ..limit(20))
        .get();
  }

  @override
  Future<Supplier> getById(int id) {
    return (_db.select(_db.suppliers)..where((s) => s.id.equals(id))).getSingle();
  }

  @override
  Future<int> add({
    required String name,
    String? mobile,
    String? gstNumber,
    String? email,
    String? address,
    String? contactPerson,
  }) {
    return _db.into(_db.suppliers).insert(
          SuppliersCompanion.insert(
            name: name,
            mobile: Value(mobile),
            gstNumber: Value(gstNumber),
            email: Value(email),
            address: Value(address),
            contactPerson: Value(contactPerson),
          ),
        );
  }

  @override
  Future<void> update({
    required int id,
    required String name,
    String? mobile,
    String? gstNumber,
    String? email,
    String? address,
    String? contactPerson,
  }) {
    return (_db.update(_db.suppliers)..where((s) => s.id.equals(id))).write(
      SuppliersCompanion(
        name: Value(name),
        mobile: Value(mobile),
        gstNumber: Value(gstNumber),
        email: Value(email),
        address: Value(address),
        contactPerson: Value(contactPerson),
      ),
    );
  }

  @override
  Future<void> delete(int id) {
    return (_db.update(_db.suppliers)..where((s) => s.id.equals(id))).write(
      const SuppliersCompanion(isActive: Value(false)),
    );
  }
}
