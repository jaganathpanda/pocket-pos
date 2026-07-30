import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/database/app_database.dart';
import '../../../core/firestore/firestore_ids.dart';
import '../../../core/firestore/store_scope.dart';
import '../domain/inventory_mode.dart';
import '../domain/warehouse_repository.dart';

/// Store-scoped Firestore implementation of [WarehouseRepository].
/// Warehouses live at `stores/{storeId}/warehouses`; the inventory mode is a
/// single settings doc at `stores/{storeId}/settings/inventory`.
class FirestoreWarehouseRepository implements WarehouseRepository {
  FirestoreWarehouseRepository(this._db, this._storeId);

  final FirebaseFirestore _db;
  final String _storeId;

  CollectionReference<Map<String, dynamic>> get _col =>
      storeCollection(_db, _storeId, 'warehouses');

  DocumentReference<Map<String, dynamic>> get _modeDoc =>
      storeCollection(_db, _storeId, 'settings').doc('inventory');

  // ── Inventory mode ─────────────────────────────────────────────────────────

  @override
  Stream<InventoryMode> watchMode() {
    return _modeDoc.snapshots().map((snap) => snap.exists
        ? InventoryMode.fromValue((snap.data()?['mode'] as String?) ?? 'single')
        : InventoryMode.single);
  }

  @override
  Future<InventoryMode> getMode() async {
    final snap = await cacheSafeDoc(
        storeCollection(_db, _storeId, 'settings'), 'inventory');
    return (snap != null && snap.exists)
        ? InventoryMode.fromValue((snap.data()?['mode'] as String?) ?? 'single')
        : InventoryMode.single;
  }

  @override
  Future<void> setMode(InventoryMode mode) =>
      _modeDoc.set({'mode': mode.value}, SetOptions(merge: true));

  // ── Warehouses ───────────────────────────────────────────────────────────

  @override
  Stream<List<Warehouse>> watchWarehouses() {
    return _col.snapshots().map((snap) {
      final list = snap.docs.map(_fromDoc).toList();
      list.sort((a, b) {
        if (a.isDefault != b.isDefault) return a.isDefault ? -1 : 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      return list;
    });
  }

  @override
  Future<List<Warehouse>> activeWarehouses() async {
    final snap = await _col.where('isActive', isEqualTo: true).get();
    final list = snap.docs.map(_fromDoc).toList();
    list.sort((a, b) {
      if (a.isDefault != b.isDefault) return a.isDefault ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return list;
  }

  @override
  Future<int> defaultWarehouseId() async {
    final def = await _col.where('isDefault', isEqualTo: true).limit(1).get();
    if (def.docs.isNotEmpty) return int.parse(def.docs.first.id);
    final any = await _col.limit(1).get();
    if (any.docs.isNotEmpty) return int.parse(any.docs.first.id);
    return addWarehouse('Main Store', isDefault: true);
  }

  @override
  Future<int> addWarehouse(String name, {bool isDefault = false}) async {
    final existing = await _col.limit(1).get();
    final makeDefault = isDefault || existing.docs.isEmpty;
    if (makeDefault) await _clearDefaults();
    final id = newIntId();
    await _col.doc('$id').set({
      'name': name.trim(),
      'isDefault': makeDefault,
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return id;
  }

  @override
  Future<void> renameWarehouse(int id, String name) =>
      _col.doc('$id').set({'name': name.trim()}, SetOptions(merge: true));

  @override
  Future<void> setWarehouseActive(int id, bool active) =>
      _col.doc('$id').set({'isActive': active}, SetOptions(merge: true));

  @override
  Future<void> setDefaultWarehouse(int id) async {
    await _clearDefaults();
    await _col.doc('$id').set({'isDefault': true}, SetOptions(merge: true));
  }

  @override
  Future<void> deleteWarehouse(int id) async {
    final all = await _col.get();
    if (all.docs.length <= 1) {
      throw Exception('At least one warehouse is required.');
    }
    final target = all.docs.firstWhere((d) => d.id == '$id');
    if ((target.data()['isDefault'] as bool?) ?? false) {
      throw Exception('Set another warehouse as default before deleting this one.');
    }
    final hasStock = await storeCollection(_db, _storeId, 'inventory')
        .where('warehouseId', isEqualTo: id)
        .limit(1)
        .get();
    if (hasStock.docs.isNotEmpty) {
      throw Exception('This warehouse still has inventory. Transfer it out first.');
    }
    await _col.doc('$id').delete();
  }

  Future<void> _clearDefaults() async {
    final defaults = await _col.where('isDefault', isEqualTo: true).get();
    for (final d in defaults.docs) {
      await d.reference.set({'isDefault': false}, SetOptions(merge: true));
    }
  }

  Warehouse _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    return Warehouse(
      id: int.tryParse(doc.id) ?? 0,
      name: (d['name'] as String?) ?? '',
      isDefault: (d['isDefault'] as bool?) ?? false,
      isActive: (d['isActive'] as bool?) ?? true,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
