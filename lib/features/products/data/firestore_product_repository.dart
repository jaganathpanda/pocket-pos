import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/database/app_database.dart';
import '../../../core/firestore/firestore_ids.dart';
import '../../../core/firestore/firestore_mappers.dart';
import '../../../core/firestore/store_scope.dart';
import '../../warehouse/data/firestore_warehouse_repository.dart';
import '../domain/product_repository.dart';

/// Store-scoped Firestore implementation of [ProductRepository].
/// Returns the existing Drift [Product] model so the UI is unchanged.
class FirestoreProductRepository implements ProductRepository {
  FirestoreProductRepository(this._db, this._storeId);

  final FirebaseFirestore _db;
  final String _storeId;

  CollectionReference<Map<String, dynamic>> get _col =>
      storeCollection(_db, _storeId, 'products');

  @override
  Stream<List<Product>> watchAll() {
    return _col
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snap) {
      final list = snap.docs.map(_fromDoc).toList();
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return list;
    });
  }

  @override
  Future<List<Product>> search(String query) async {
    // Firestore has no LIKE; filter the (offline-cached) set client-side.
    final snap = await _col.where('isActive', isEqualTo: true).get();
    final q = query.trim().toLowerCase();
    final all = snap.docs.map(_fromDoc);
    if (q.isEmpty) return all.take(30).toList();
    return all
        .where((p) =>
            p.name.toLowerCase().contains(q) ||
            p.productCode.toLowerCase().contains(q) ||
            (p.barcode?.toLowerCase().contains(q) ?? false))
        .take(30)
        .toList();
  }

  @override
  Future<List<Product>> getByIds(List<int> ids) async {
    if (ids.isEmpty) return const [];
    final snaps = await Future.wait(ids.map((id) => cacheSafeDoc(_col, '$id')));
    return snaps
        .whereType<DocumentSnapshot<Map<String, dynamic>>>()
        .where((s) => s.exists)
        .map(productFromDoc)
        .toList();
  }

  @override
  Future<Product?> findByBarcode(String code) async {
    final c = code.trim();
    if (c.isEmpty) return null;
    // Try barcode, then product code.
    for (final field in ['barcode', 'productCode']) {
      final snap = await _col
          .where('isActive', isEqualTo: true)
          .where(field, isEqualTo: c)
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) return _fromDoc(snap.docs.first);
    }
    return null;
  }

  @override
  Future<void> add({
    required String name,
    required String productCode,
    String? barcode,
    int? categoryId,
    required double sellingPrice,
    required double purchasePrice,
    required double taxPercent,
    String unit = 'piece',
    double openingStock = 0,
  }) async {
    final id = newIntId();

    // Resolve which warehouses need an opening stock row. Done before the batch
    // because it may itself create a default warehouse when none exists.
    final warehouseRepo = FirestoreWarehouseRepository(_db, _storeId);
    final mode = await warehouseRepo.getMode();
    final warehouseIds = <int>[];
    int defaultWarehouseId = 0;
    if (mode.tracksStock) {
      if (mode.usesWarehouses) {
        final active = await warehouseRepo.activeWarehouses();
        warehouseIds.addAll(active.map((w) => w.id));
      }
      if (warehouseIds.isEmpty) {
        warehouseIds.add(await warehouseRepo.defaultWarehouseId());
      }
      defaultWarehouseId = await warehouseRepo.defaultWarehouseId();
    }

    final batch = _db.batch();
    batch.set(
        _col.doc('$id'),
        _data(
          name: name,
          productCode: productCode,
          barcode: barcode,
          categoryId: categoryId,
          sellingPrice: sellingPrice,
          purchasePrice: purchasePrice,
          taxPercent: taxPercent,
          unit: unit,
        )..['createdAt'] = FieldValue.serverTimestamp());

    // An opening inventory row per warehouse so the product shows up in the
    // Inventory screen and can be stocked via purchases / adjustments. Any
    // opening quantity goes to the default warehouse; the rest start at 0.
    final inventory = storeCollection(_db, _storeId, 'inventory');
    for (final wid in warehouseIds) {
      final qty = (wid == defaultWarehouseId && openingStock > 0)
          ? openingStock
          : 0.0;
      final invId = newIntId();
      batch.set(inventory.doc('$invId'), {
        'productId': id,
        'variantId': null,
        'warehouseId': wid,
        'currentStock': qty,
        'availableStock': qty,
        'lowStockThreshold': 5.0,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  @override
  Future<int> backfillMissingInventoryRows() async {
    final warehouseRepo = FirestoreWarehouseRepository(_db, _storeId);
    final mode = await warehouseRepo.getMode();
    if (!mode.tracksStock) return 0;

    final warehouseIds = <int>[];
    if (mode.usesWarehouses) {
      final active = await warehouseRepo.activeWarehouses();
      warehouseIds.addAll(active.map((w) => w.id));
    }
    if (warehouseIds.isEmpty) {
      warehouseIds.add(await warehouseRepo.defaultWarehouseId());
    }

    final inventory = storeCollection(_db, _storeId, 'inventory');
    final invSnap = await inventory.get();
    // Product ids that already have at least one inventory row.
    final covered = <int>{
      for (final d in invSnap.docs) (d.data()['productId'] as num?)?.toInt() ?? -1
    };

    final prodSnap = await _col.where('isActive', isEqualTo: true).get();
    var created = 0;
    var batch = _db.batch();
    var ops = 0;
    for (final p in prodSnap.docs) {
      final pid = int.tryParse(p.id) ?? 0;
      if (covered.contains(pid)) continue;
      for (final wid in warehouseIds) {
        final invId = newIntId();
        batch.set(inventory.doc('$invId'), {
          'productId': pid,
          'variantId': null,
          'warehouseId': wid,
          'currentStock': 0.0,
          'availableStock': 0.0,
          'lowStockThreshold': 5.0,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        created++;
        ops++;
        // Stay under Firestore's 500-op batch limit.
        if (ops >= 450) {
          await batch.commit();
          batch = _db.batch();
          ops = 0;
        }
      }
    }
    if (ops > 0) await batch.commit();
    return created;
  }

  @override
  Future<void> update({
    required int id,
    required String name,
    required String productCode,
    String? barcode,
    int? categoryId,
    required double sellingPrice,
    required double purchasePrice,
    required double taxPercent,
    String unit = 'piece',
  }) {
    return _col.doc('$id').set(
        _data(
          name: name,
          productCode: productCode,
          barcode: barcode,
          categoryId: categoryId,
          sellingPrice: sellingPrice,
          purchasePrice: purchasePrice,
          taxPercent: taxPercent,
          unit: unit,
        ),
        SetOptions(merge: true));
  }

  @override
  Future<void> updatePrice(int id, double sellingPrice) => _col
      .doc('$id')
      .set({'sellingPrice': sellingPrice}, SetOptions(merge: true));

  @override
  Future<void> delete(int id) =>
      _col.doc('$id').set({'isActive': false}, SetOptions(merge: true));

  Map<String, dynamic> _data({
    required String name,
    required String productCode,
    String? barcode,
    int? categoryId,
    required double sellingPrice,
    required double purchasePrice,
    required double taxPercent,
    required String unit,
  }) {
    return {
      'name': name,
      'productCode': productCode,
      'barcode': barcode,
      'categoryId': categoryId,
      'purchasePrice': purchasePrice,
      'sellingPrice': sellingPrice,
      'mrp': 0.0,
      'taxPercent': taxPercent,
      'unit': unit,
      'isActive': true,
    };
  }

  Product _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    double num_(dynamic v) => (v as num?)?.toDouble() ?? 0;
    return Product(
      id: int.tryParse(doc.id) ?? 0,
      name: (d['name'] as String?) ?? '',
      productCode: (d['productCode'] as String?) ?? '',
      sku: d['sku'] as String?,
      barcode: d['barcode'] as String?,
      categoryId: (d['categoryId'] as num?)?.toInt(),
      brand: d['brand'] as String?,
      purchasePrice: num_(d['purchasePrice']),
      sellingPrice: num_(d['sellingPrice']),
      mrp: num_(d['mrp']),
      taxPercent: num_(d['taxPercent']),
      unit: (d['unit'] as String?) ?? 'piece',
      imagePath: d['imagePath'] as String?,
      description: d['description'] as String?,
      isActive: (d['isActive'] as bool?) ?? true,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
