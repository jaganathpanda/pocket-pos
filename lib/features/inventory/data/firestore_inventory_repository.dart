import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/database/app_database.dart';
import '../../../core/firestore/firestore_ids.dart';
import '../../../core/firestore/store_scope.dart';
import '../domain/inventory_repository.dart';

/// Store-scoped Firestore implementation of [InventoryRepository].
/// One inventory row per (product, warehouse) at `stores/{storeId}/inventory`.
class FirestoreInventoryRepository implements InventoryRepository {
  FirestoreInventoryRepository(this._db, this._storeId);

  final FirebaseFirestore _db;
  final String _storeId;

  CollectionReference<Map<String, dynamic>> get _col =>
      storeCollection(_db, _storeId, 'inventory');
  CollectionReference<Map<String, dynamic>> get _products =>
      storeCollection(_db, _storeId, 'products');
  CollectionReference<Map<String, dynamic>> get _warehouses =>
      storeCollection(_db, _storeId, 'warehouses');

  static double _num(dynamic v, [double or = 0]) => (v as num?)?.toDouble() ?? or;

  @override
  Stream<List<InventoryWithProduct>> watchInventory({int? warehouseId}) {
    Query<Map<String, dynamic>> q = _col;
    if (warehouseId != null) q = q.where('warehouseId', isEqualTo: warehouseId);
    return q.snapshots().asyncMap((snap) async {
      final products = await _productsById();
      final warehouseNames = await _warehouseNamesById();
      final rows = <InventoryWithProduct>[];
      for (final doc in snap.docs) {
        final inv = _invFromDoc(doc);
        final product = products[inv.productId];
        if (product == null) continue;
        rows.add(InventoryWithProduct(
          inventory: inv,
          product: product,
          warehouseName: warehouseNames[inv.warehouseId],
        ));
      }
      return rows;
    });
  }

  @override
  Future<void> stockIn({
    required int productId,
    required int warehouseId,
    required double quantity,
    double unitCost = 0,
    String? note,
  }) =>
      _applyStock(productId, warehouseId, quantity);

  @override
  Future<void> stockOut({
    required int productId,
    required int warehouseId,
    required double quantity,
    String? note,
  }) =>
      _applyStock(productId, warehouseId, -quantity);

  @override
  Future<void> setStock({
    required int productId,
    required int warehouseId,
    required double quantity,
  }) async {
    final qty = quantity.clamp(0, 999999999).toDouble();
    final row = await _row(productId, warehouseId);
    if (row == null) {
      await _create(productId, warehouseId, qty);
    } else {
      await row.reference.set({
        'currentStock': qty,
        'availableStock': qty,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  @override
  Future<void> transferStock({
    required int productId,
    required int fromWarehouseId,
    required int toWarehouseId,
    required double quantity,
    String? note,
  }) async {
    if (quantity <= 0) throw Exception('Transfer quantity must be greater than 0');
    if (fromWarehouseId == toWarehouseId) {
      throw Exception('Source and destination warehouses must differ');
    }
    final available = await availableStock(productId: productId, warehouseId: fromWarehouseId);
    if (quantity > available) {
      throw Exception('Insufficient stock in source. Available: ${available.toStringAsFixed(2)}');
    }
    await _applyStock(productId, fromWarehouseId, -quantity);
    await _applyStock(productId, toWarehouseId, quantity);
  }

  @override
  Future<double> availableStock({
    required int productId,
    required int warehouseId,
  }) async {
    final row = await _row(productId, warehouseId);
    return row == null ? 0 : _num(row.data()['availableStock']);
  }

  // ── helpers ────────────────────────────────────────────────────────────────

  Future<QueryDocumentSnapshot<Map<String, dynamic>>?> _row(
      int productId, int warehouseId) async {
    final snap = await _col
        .where('productId', isEqualTo: productId)
        .where('warehouseId', isEqualTo: warehouseId)
        .limit(1)
        .get();
    return snap.docs.isEmpty ? null : snap.docs.first;
  }

  Future<void> _create(int productId, int warehouseId, double qty) async {
    final id = newIntId();
    await _col.doc('$id').set({
      'productId': productId,
      'variantId': null,
      'warehouseId': warehouseId,
      'currentStock': qty,
      'availableStock': qty,
      'lowStockThreshold': 5.0,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _applyStock(int productId, int warehouseId, double delta) async {
    final row = await _row(productId, warehouseId);
    if (row == null) {
      await _create(productId, warehouseId, delta > 0 ? delta : 0);
      return;
    }
    final next = (_num(row.data()['currentStock']) + delta).clamp(0, 999999999).toDouble();
    await row.reference.set({
      'currentStock': next,
      'availableStock': next,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<Map<int, Product>> _productsById() async {
    final snap = await _products.get();
    return {for (final d in snap.docs) (int.tryParse(d.id) ?? 0): _productFromDoc(d)};
  }

  Future<Map<int, String>> _warehouseNamesById() async {
    final snap = await _warehouses.get();
    return {
      for (final d in snap.docs)
        (int.tryParse(d.id) ?? 0): (d.data()['name'] as String?) ?? ''
    };
  }

  InventoryData _invFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    return InventoryData(
      id: int.tryParse(doc.id) ?? 0,
      productId: (d['productId'] as num?)?.toInt() ?? 0,
      variantId: (d['variantId'] as num?)?.toInt(),
      warehouseId: (d['warehouseId'] as num?)?.toInt(),
      currentStock: _num(d['currentStock']),
      availableStock: _num(d['availableStock']),
      lowStockThreshold: _num(d['lowStockThreshold'], 5),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Product _productFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    return Product(
      id: int.tryParse(doc.id) ?? 0,
      name: (d['name'] as String?) ?? '',
      productCode: (d['productCode'] as String?) ?? '',
      sku: d['sku'] as String?,
      barcode: d['barcode'] as String?,
      categoryId: (d['categoryId'] as num?)?.toInt(),
      brand: d['brand'] as String?,
      purchasePrice: _num(d['purchasePrice']),
      sellingPrice: _num(d['sellingPrice']),
      mrp: _num(d['mrp']),
      taxPercent: _num(d['taxPercent']),
      unit: (d['unit'] as String?) ?? 'piece',
      imagePath: d['imagePath'] as String?,
      description: d['description'] as String?,
      isActive: (d['isActive'] as bool?) ?? true,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
