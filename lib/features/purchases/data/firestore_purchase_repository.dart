import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/database/app_database.dart';
import '../../../core/firestore/firestore_ids.dart';
import '../../../core/firestore/firestore_mappers.dart';
import '../../../core/firestore/store_scope.dart';
import '../../inventory/data/firestore_inventory_repository.dart';
import '../../warehouse/data/firestore_warehouse_repository.dart';
import '../domain/purchase_repository.dart';

/// Store-scoped Firestore implementation of [PurchaseRepository].
class FirestorePurchaseRepository implements PurchaseRepository {
  FirestorePurchaseRepository(this._db, this._storeId)
      : _inventory = FirestoreInventoryRepository(_db, _storeId),
        _warehouse = FirestoreWarehouseRepository(_db, _storeId);

  final FirebaseFirestore _db;
  final String _storeId;
  final FirestoreInventoryRepository _inventory;
  final FirestoreWarehouseRepository _warehouse;

  CollectionReference<Map<String, dynamic>> get _col =>
      storeCollection(_db, _storeId, 'purchases');
  CollectionReference<Map<String, dynamic>> get _items =>
      storeCollection(_db, _storeId, 'purchase_items');
  CollectionReference<Map<String, dynamic>> get _suppliers =>
      storeCollection(_db, _storeId, 'suppliers');
  CollectionReference<Map<String, dynamic>> get _products =>
      storeCollection(_db, _storeId, 'products');

  @override
  Stream<List<PurchaseWithSupplier>> watchAll() {
    return _col.snapshots().asyncMap((snap) async {
      final suppliers = await _suppliersById();
      final list = snap.docs.map((doc) {
        final p = _purchaseFromDoc(doc);
        return PurchaseWithSupplier(purchase: p, supplier: suppliers[p.supplierId]);
      }).toList();
      list.sort((a, b) => b.purchase.purchasedAt.compareTo(a.purchase.purchasedAt));
      return list;
    });
  }

  @override
  Stream<List<PurchaseItemWithProduct>> watchItems(int purchaseId) {
    return _items.where('purchaseId', isEqualTo: purchaseId).snapshots().asyncMap((snap) async {
      final products = await _productsById();
      final rows = <PurchaseItemWithProduct>[];
      for (final doc in snap.docs) {
        final item = _itemFromDoc(doc);
        final product = products[item.productId];
        if (product == null) continue;
        rows.add(PurchaseItemWithProduct(item: item, product: product));
      }
      return rows;
    });
  }

  @override
  Future<int> createPurchase({
    int? supplierId,
    String? invoiceNo,
    String? note,
    int? warehouseId,
  }) async {
    final id = newIntId();
    await _col.doc('$id').set({
      'supplierId': supplierId,
      'warehouseId': warehouseId,
      'invoiceNo': invoiceNo,
      'note': note,
      'status': 'draft',
      'subTotal': 0.0,
      'taxTotal': 0.0,
      'discountTotal': 0.0,
      'grandTotal': 0.0,
      'paymentStatus': 'unpaid',
      'purchasedAt': FieldValue.serverTimestamp(),
    });
    return id;
  }

  @override
  Future<void> addItem({
    required int purchaseId,
    required int productId,
    required double quantity,
    required double unitCost,
    double taxPercent = 0,
    int? variantId,
  }) async {
    final taxable = quantity * unitCost;
    final lineTotal = taxable + taxable * (taxPercent / 100);
    final id = newIntId();
    await _items.doc('$id').set({
      'purchaseId': purchaseId,
      'productId': productId,
      'variantId': variantId,
      'quantity': quantity,
      'unitCost': unitCost,
      'taxPercent': taxPercent,
      'lineTotal': lineTotal,
    });
    await _recalc(purchaseId);
  }

  @override
  Future<void> removeItem(int purchaseItemId) async {
    final doc = await _items.doc('$purchaseItemId').get();
    if (!doc.exists) return;
    final purchaseId = _itemFromDoc(doc).purchaseId;
    await doc.reference.delete();
    await _recalc(purchaseId);
  }

  @override
  Future<void> finalize(int purchaseId) async {
    final purchaseDoc = await _col.doc('$purchaseId').get();
    final itemsSnap = await _items.where('purchaseId', isEqualTo: purchaseId).get();
    final mode = await _warehouse.getMode();
    final warehouseId = _purchaseFromDoc(purchaseDoc).warehouseId ??
        await _warehouse.defaultWarehouseId();

    if (mode.tracksStock) {
      for (final doc in itemsSnap.docs) {
        final item = _itemFromDoc(doc);
        await _inventory.stockIn(
          productId: item.productId,
          warehouseId: warehouseId,
          quantity: item.quantity,
          unitCost: item.unitCost,
          note: 'Purchase #$purchaseId',
        );
      }
    }

    await _col.doc('$purchaseId').set({
      'status': 'received',
      'paymentStatus': 'unpaid',
    }, SetOptions(merge: true));
  }

  @override
  Future<void> deletePurchase(int purchaseId) async {
    final items = await _items.where('purchaseId', isEqualTo: purchaseId).get();
    for (final d in items.docs) {
      await d.reference.delete();
    }
    await _col.doc('$purchaseId').delete();
  }

  Future<void> _recalc(int purchaseId) async {
    final snap = await _items.where('purchaseId', isEqualTo: purchaseId).get();
    final items = snap.docs.map(_itemFromDoc);
    final subTotal = items.fold<double>(0, (s, i) => s + i.quantity * i.unitCost);
    final taxTotal =
        items.fold<double>(0, (s, i) => s + i.quantity * i.unitCost * (i.taxPercent / 100));
    await _col.doc('$purchaseId').set({
      'subTotal': subTotal,
      'taxTotal': taxTotal,
      'grandTotal': subTotal + taxTotal,
    }, SetOptions(merge: true));
  }

  Future<Map<int, Supplier>> _suppliersById() async {
    final snap = await _suppliers.get();
    return {for (final d in snap.docs) (int.tryParse(d.id) ?? 0): _supplierFromDoc(d)};
  }

  Future<Map<int, Product>> _productsById() async {
    final snap = await _products.get();
    return {for (final d in snap.docs) (int.tryParse(d.id) ?? 0): productFromDoc(d)};
  }

  Purchase _purchaseFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return Purchase(
      id: int.tryParse(doc.id) ?? 0,
      supplierId: (d['supplierId'] as num?)?.toInt(),
      warehouseId: (d['warehouseId'] as num?)?.toInt(),
      invoiceNo: d['invoiceNo'] as String?,
      status: (d['status'] as String?) ?? 'draft',
      subTotal: fsNum(d['subTotal']),
      taxTotal: fsNum(d['taxTotal']),
      discountTotal: fsNum(d['discountTotal']),
      grandTotal: fsNum(d['grandTotal']),
      paymentStatus: (d['paymentStatus'] as String?) ?? 'unpaid',
      note: d['note'] as String?,
      purchasedAt: (d['purchasedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  PurchaseItem _itemFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return PurchaseItem(
      id: int.tryParse(doc.id) ?? 0,
      purchaseId: (d['purchaseId'] as num?)?.toInt() ?? 0,
      productId: (d['productId'] as num?)?.toInt() ?? 0,
      variantId: (d['variantId'] as num?)?.toInt(),
      quantity: fsNum(d['quantity']),
      unitCost: fsNum(d['unitCost']),
      taxPercent: fsNum(d['taxPercent']),
      lineTotal: fsNum(d['lineTotal']),
    );
  }

  Supplier _supplierFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return Supplier(
      id: int.tryParse(doc.id) ?? 0,
      name: (d['name'] as String?) ?? '',
      mobile: d['mobile'] as String?,
      gstNumber: d['gstNumber'] as String?,
      email: d['email'] as String?,
      address: d['address'] as String?,
      contactPerson: d['contactPerson'] as String?,
      outstandingBalance: fsNum(d['outstandingBalance']),
      isActive: (d['isActive'] as bool?) ?? true,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
