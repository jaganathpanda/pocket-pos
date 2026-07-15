import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../domain/inventory_mode.dart';
import '../domain/warehouse_repository.dart';

class WarehouseRepositoryImpl implements WarehouseRepository {
  WarehouseRepositoryImpl(this._db);

  final AppDatabase _db;

  static const _modeKey = 'inventory_mode';

  @override
  Stream<InventoryMode> watchMode() {
    return (_db.select(_db.appSettings)..where((s) => s.key.equals(_modeKey)))
        .watchSingleOrNull()
        .map((row) =>
            row == null ? InventoryMode.single : InventoryMode.fromValue(row.value));
  }

  @override
  Future<InventoryMode> getMode() async {
    final row = await (_db.select(_db.appSettings)
          ..where((s) => s.key.equals(_modeKey)))
        .getSingleOrNull();
    return row == null ? InventoryMode.single : InventoryMode.fromValue(row.value);
  }

  @override
  Future<void> setMode(InventoryMode mode) async {
    await _db.into(_db.appSettings).insertOnConflictUpdate(
          AppSettingsCompanion.insert(key: _modeKey, value: mode.value),
        );
  }

  @override
  Stream<List<Warehouse>> watchWarehouses() {
    return (_db.select(_db.warehouses)
          ..orderBy([
            (w) => OrderingTerm.desc(w.isDefault),
            (w) => OrderingTerm.asc(w.name),
          ]))
        .watch();
  }

  @override
  Future<List<Warehouse>> activeWarehouses() {
    return (_db.select(_db.warehouses)
          ..where((w) => w.isActive.equals(true))
          ..orderBy([
            (w) => OrderingTerm.desc(w.isDefault),
            (w) => OrderingTerm.asc(w.name),
          ]))
        .get();
  }

  @override
  Future<int> defaultWarehouseId() => _db.defaultWarehouseId();

  @override
  Future<int> addWarehouse(String name, {bool isDefault = false}) async {
    return _db.transaction(() async {
      final existing = await (_db.select(_db.warehouses)..limit(1)).getSingleOrNull();
      final makeDefault = isDefault || existing == null;
      if (makeDefault) {
        await _db.update(_db.warehouses).write(
              const WarehousesCompanion(isDefault: Value(false)),
            );
      }
      return _db.into(_db.warehouses).insert(
            WarehousesCompanion.insert(
              name: name.trim(),
              isDefault: Value(makeDefault),
            ),
          );
    });
  }

  @override
  Future<void> renameWarehouse(int id, String name) {
    return (_db.update(_db.warehouses)..where((w) => w.id.equals(id)))
        .write(WarehousesCompanion(name: Value(name.trim())));
  }

  @override
  Future<void> setWarehouseActive(int id, bool active) {
    return (_db.update(_db.warehouses)..where((w) => w.id.equals(id)))
        .write(WarehousesCompanion(isActive: Value(active)));
  }

  @override
  Future<void> setDefaultWarehouse(int id) async {
    await _db.transaction(() async {
      await _db.update(_db.warehouses).write(
            const WarehousesCompanion(isDefault: Value(false)),
          );
      await (_db.update(_db.warehouses)..where((w) => w.id.equals(id)))
          .write(const WarehousesCompanion(isDefault: Value(true)));
    });
  }

  @override
  Future<void> deleteWarehouse(int id) async {
    final all = await _db.select(_db.warehouses).get();
    if (all.length <= 1) {
      throw Exception('At least one warehouse is required.');
    }
    final target = all.firstWhere((w) => w.id == id);
    if (target.isDefault) {
      throw Exception('Set another warehouse as default before deleting this one.');
    }
    final hasStock = await (_db.select(_db.inventory)
          ..where((i) => i.warehouseId.equals(id))
          ..limit(1))
        .getSingleOrNull();
    if (hasStock != null) {
      throw Exception('This warehouse still has inventory. Transfer it out first.');
    }
    await (_db.delete(_db.warehouses)..where((w) => w.id.equals(id))).go();
  }
}
