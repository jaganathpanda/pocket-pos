import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../core/database/app_database.dart';
import '../../../core/firestore/firestore_ids.dart';
import '../../../core/firestore/firestore_mappers.dart';
import '../../../core/firestore/store_scope.dart';
import '../../inventory/data/firestore_inventory_repository.dart';
import '../../warehouse/data/firestore_warehouse_repository.dart';
import '../domain/sales_repository.dart';

/// Store-scoped Firestore implementation of [SalesRepository] (carts + checkout).
class FirestoreSalesRepository implements SalesRepository {
  FirestoreSalesRepository(this._db, this._storeId)
      : _inventory = FirestoreInventoryRepository(_db, _storeId),
        _warehouse = FirestoreWarehouseRepository(_db, _storeId);

  final FirebaseFirestore _db;
  final String _storeId;
  final FirestoreInventoryRepository _inventory;
  final FirestoreWarehouseRepository _warehouse;

  CollectionReference<Map<String, dynamic>> get _carts =>
      storeCollection(_db, _storeId, 'carts');
  CollectionReference<Map<String, dynamic>> get _cartItems =>
      storeCollection(_db, _storeId, 'cart_items');
  CollectionReference<Map<String, dynamic>> get _sales =>
      storeCollection(_db, _storeId, 'sales');
  CollectionReference<Map<String, dynamic>> get _saleItems =>
      storeCollection(_db, _storeId, 'sale_items');
  CollectionReference<Map<String, dynamic>> get _payments =>
      storeCollection(_db, _storeId, 'payments');
  CollectionReference<Map<String, dynamic>> get _customers =>
      storeCollection(_db, _storeId, 'customers');
  CollectionReference<Map<String, dynamic>> get _products =>
      storeCollection(_db, _storeId, 'products');

  int get _now => DateTime.now().millisecondsSinceEpoch;

  /// Offline-first write: a Firestore write is applied to the local cache the
  /// moment it is issued (so streams and cached reads update immediately) but
  /// the returned Future only completes when the SERVER acknowledges it — which
  /// never happens while offline. Awaiting it would hang the UI (dialog won't
  /// close, "New Cart" won't appear, checkout won't finish) until the network
  /// returns. So we deliberately do NOT await the write; Firestore keeps it
  /// queued and syncs it automatically on reconnect. Late errors are swallowed
  /// so they don't surface as unhandled async exceptions.
  void _write(Future<void> op) {
    unawaited(op.catchError((Object e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('Firestore write queued/failed (will retry on sync): $e');
      }
    }));
  }

  // ── Carts ────────────────────────────────────────────────────────────────

  @override
  Stream<List<Cart>> watchActiveCarts(int? posCounterId) {
    return _carts
        .where('status', whereIn: ['active', 'hold'])
        .snapshots()
        .map((snap) {
      var carts = snap.docs.map(cartFromDoc).toList();
      if (posCounterId != null) {
        carts = carts.where((c) => c.posCounterId == posCounterId).toList();
      }
      carts.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return carts;
    });
  }

  @override
  Stream<List<CartItemWithProduct>> watchCartItems(int cartId) {
    return _cartItems
        .where('cartId', isEqualTo: cartId)
        .snapshots()
        .asyncMap((snap) async {
      final products = await _productsById();
      final rows = <CartItemWithProduct>[];
      for (final doc in snap.docs) {
        final item = cartItemFromDoc(doc);
        final product = products[item.productId];
        if (product == null) continue;
        rows.add(CartItemWithProduct(item: item, product: product));
      }
      return rows;
    });
  }

  @override
  Future<int> createCart(String name, {int? posCounterId, int? warehouseId}) =>
      _createCart(name, customerId: null, posCounterId: posCounterId, warehouseId: warehouseId);

  @override
  Future<int> createCartWithCustomer(String name, int customerId,
          {int? posCounterId, int? warehouseId}) =>
      _createCart(name, customerId: customerId, posCounterId: posCounterId, warehouseId: warehouseId);

  Future<int> _createCart(String name,
      {int? customerId, int? posCounterId, int? warehouseId}) async {
    final id = newIntId();
    _write(_carts.doc('$id').set({
      'name': name,
      'status': 'active',
      'customerId': customerId,
      'posCounterId': posCounterId,
      'warehouseId': warehouseId,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }));
    return id;
  }

  @override
  Future<Cart?> getCart(int cartId) async {
    final doc = await cacheSafeDoc(_carts, '$cartId');
    return (doc != null && doc.exists) ? cartFromDoc(doc) : null;
  }

  @override
  Future<void> setCartStatus(int cartId, String status) async =>
      _write(_carts.doc('$cartId').set({'status': status, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true)));

  @override
  Future<void> setCartCounter(int cartId, int posCounterId) async => _write(_carts
      .doc('$cartId')
      .set({'posCounterId': posCounterId, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true)));

  @override
  Future<void> renameCart(int cartId, String name) async =>
      _write(_carts.doc('$cartId').set({'name': name, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true)));

  @override
  Future<void> updateCartCustomer(int cartId, int customerId) async => _write(_carts
      .doc('$cartId')
      .set({'customerId': customerId, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true)));

  @override
  Future<void> updateCartDiscount(int cartId, double totalDiscount) async =>
      _write(_carts.doc('$cartId').set({'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true)));

  @override
  Future<void> deleteCart(int cartId) async {
    final items = await _cartItems.where('cartId', isEqualTo: cartId).get();
    for (final d in items.docs) {
      _write(d.reference.delete());
    }
    _write(_carts.doc('$cartId').delete());
  }

  // ── Cart items ─────────────────────────────────────────────────────────────

  @override
  Future<void> addItem({required int cartId, required int productId}) async {
    final productDoc = await cacheSafeDoc(_products, '$productId');
    if (productDoc == null || !productDoc.exists) {
      throw Exception('Product not found');
    }
    final product = productFromDoc(productDoc);

    final cart = await getCart(cartId);
    final stock = await _stockContext(cart?.warehouseId);

    final existingSnap = await _cartItems
        .where('cartId', isEqualTo: cartId)
        .where('productId', isEqualTo: productId)
        .where('variantId', isEqualTo: null)
        .limit(1)
        .get();

    if (existingSnap.docs.isNotEmpty) {
      final doc = existingSnap.docs.first;
      final newQty = cartItemFromDoc(doc).quantity + 1;
      await _assertStock(productId, newQty, stock);
      _write(doc.reference.set({'quantity': newQty}, SetOptions(merge: true)));
    } else {
      await _assertStock(productId, 1, stock);
      final id = newIntId();
      _write(_cartItems.doc('$id').set({
        'cartId': cartId,
        'productId': productId,
        'variantId': null,
        'quantity': 1.0,
        'unitPrice': product.sellingPrice,
        'discountAmount': 0.0,
        'taxPercent': product.taxPercent,
        'note': null,
      }));
    }
    _write(_carts.doc('$cartId').set({'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true)));
  }

  @override
  Future<void> updateItemQuantity(int cartItemId, double quantity) async {
    if (quantity <= 0) return removeItem(cartItemId);
    final doc = await cacheSafeDoc(_cartItems, '$cartItemId');
    if (doc == null || !doc.exists) throw Exception('Cart item not found');
    final item = cartItemFromDoc(doc);
    final cart = await getCart(item.cartId);
    final stock = await _stockContext(cart?.warehouseId);
    await _assertStock(item.productId, quantity, stock);
    _write(doc.reference.set({'quantity': quantity}, SetOptions(merge: true)));
  }

  @override
  Future<void> removeItem(int cartItemId) async =>
      _write(_cartItems.doc('$cartItemId').delete());

  // ── Payments / checkout ──────────────────────────────────────────────────

  @override
  Future<void> recordCreditPayment({
    required int saleId,
    required double amount,
    required String method,
    String? referenceNo,
  }) async {
    if (amount <= 0) throw Exception('Payment amount must be greater than 0');
    final saleDoc = await cacheSafeDoc(_sales, '$saleId');
    if (saleDoc == null || !saleDoc.exists) throw Exception('Sale not found');
    final sale = saleFromDoc(saleDoc);

    final payments = await _payments.where('saleId', isEqualTo: saleId).get();
    final paidBefore =
        payments.docs.fold<double>(0, (s, d) => s + fsNum(d.data()['amount']));
    final newPaid = paidBefore + amount;

    final pid = newIntId();
    _write(_payments.doc('$pid').set({
      'saleId': saleId,
      'method': method,
      'amount': amount,
      'referenceNo': referenceNo,
      'paidAt': FieldValue.serverTimestamp(),
    }));

    final status = newPaid + 0.0001 >= sale.grandTotal ? 'paid' : 'partial';
    _write(_sales.doc('$saleId').set({'paymentStatus': status}, SetOptions(merge: true)));
  }

  @override
  Future<int> checkout({
    required int cartId,
    required String paymentMode,
    required double paidAmount,
    String? customerName,
    String? customerMobile,
    String? customerAddress,
  }) async {
    final cart = await getCart(cartId);
    if (cart == null) throw Exception('Cart not found');
    final itemsSnap = await _cartItems.where('cartId', isEqualTo: cartId).get();
    if (itemsSnap.docs.isEmpty) throw Exception('Cart is empty');
    final items = itemsSnap.docs.map(cartItemFromDoc).toList();

    // Customer upsert.
    int? customerId = cart.customerId;
    if (customerMobile != null && customerMobile.isNotEmpty) {
      try {
        final existing =
            await _customers.where('mobile', isEqualTo: customerMobile).limit(1).get();
        if (existing.docs.isNotEmpty) {
          customerId = int.tryParse(existing.docs.first.id);
          if (customerName != null && customerName.isNotEmpty) {
            _write(existing.docs.first.reference.set(
                {'name': customerName, 'address': customerAddress},
                SetOptions(merge: true)));
          }
        } else if (customerName != null && customerName.isNotEmpty) {
          customerId = newIntId();
          _write(_customers.doc('$customerId').set({
            'name': customerName,
            'mobile': customerMobile,
            'address': customerAddress,
            'loyaltyPoints': 0,
          }));
        }
      } on FirebaseException catch (e) {
        // Offline fallback: if lookup cannot run, still proceed with sale.
        if (e.code != 'unavailable') rethrow;
      }
    }

    final stock = await _stockContext(cart.warehouseId);

    double subTotal = 0, discountTotal = 0, taxTotal = 0;
    for (final item in items) {
      await _assertStock(item.productId, item.quantity, stock);
      final lineSub = item.quantity * item.unitPrice;
      final taxable = lineSub - item.discountAmount;
      subTotal += lineSub;
      discountTotal += item.discountAmount;
      taxTotal += taxable * (item.taxPercent / 100);
    }
    final grandTotal = subTotal - discountTotal + taxTotal;
    final normalizedPaid = paidAmount < 0 ? 0.0 : paidAmount;
    final isFullyPaid = normalizedPaid + 0.0001 >= grandTotal;
    if (!isFullyPaid && paymentMode != 'credit') {
      throw Exception('Paid amount is less than total. Select Credit payment mode for udhar.');
    }
    final paymentStatus =
        isFullyPaid ? 'paid' : (normalizedPaid > 0 ? 'partial' : 'credit');
    final invoiceNo = 'INV-$_now';
    final saleId = newIntId();

    // Sale + items + payment + cart status in one atomic batch.
    final batch = _db.batch();
    batch.set(_sales.doc('$saleId'), {
      'cartId': cartId,
      'invoiceNo': invoiceNo,
      'customerId': customerId,
      'posCounterId': cart.posCounterId,
      'warehouseId': stock.track ? stock.warehouseId : null,
      'subTotal': subTotal,
      'discountTotal': discountTotal,
      'taxTotal': taxTotal,
      'grandTotal': grandTotal,
      'paymentStatus': paymentStatus,
      'soldAt': FieldValue.serverTimestamp(),
    });
    for (final item in items) {
      final lineSub = item.quantity * item.unitPrice;
      final taxable = lineSub - item.discountAmount;
      final lineTotal = taxable + taxable * (item.taxPercent / 100);
      final siId = newIntId();
      batch.set(_saleItems.doc('$siId'), {
        'saleId': saleId,
        'productId': item.productId,
        'variantId': item.variantId,
        'quantity': item.quantity,
        'unitPrice': item.unitPrice,
        'discountAmount': item.discountAmount,
        'taxPercent': item.taxPercent,
        'lineTotal': lineTotal,
      });
    }
    final payId = newIntId();
    batch.set(_payments.doc('$payId'), {
      'saleId': saleId,
      'method': paymentMode,
      'amount': paidAmount,
      'referenceNo': null,
      'paidAt': FieldValue.serverTimestamp(),
    });
    batch.set(_carts.doc('$cartId'), {'status': 'completed'}, SetOptions(merge: true));
    // Offline-first: the batch is applied to the local cache immediately (so the
    // sale, its items and the completed-cart status are all visible at once) and
    // syncs on reconnect. Do NOT await server acknowledgement — that would hang
    // checkout until the network returns.
    _write(batch.commit());

    // Decrement stock (each is a read-modify-write applied locally too).
    if (stock.track) {
      for (final item in items) {
        _write(_inventory.stockOut(
          productId: item.productId,
          warehouseId: stock.warehouseId,
          quantity: item.quantity,
          note: 'Sale $invoiceNo',
        ));
      }
    }

    return saleId;
  }

  // ── helpers ────────────────────────────────────────────────────────────────

  Future<({bool track, int warehouseId})> _stockContext(int? cartWarehouseId) async {
    final mode = await _warehouse.getMode();
    final warehouseId = cartWarehouseId ?? await _warehouse.defaultWarehouseId();
    return (track: mode.tracksStock, warehouseId: warehouseId);
  }

  Future<void> _assertStock(
      int productId, double requestedQty, ({bool track, int warehouseId}) stock) async {
    if (requestedQty < 0) throw Exception('Quantity cannot be negative');
    if (!stock.track) return;
    double available;
    try {
      available = await _inventory.availableStock(
          productId: productId, warehouseId: stock.warehouseId);
    } on FirebaseException catch (e) {
      // Offline fallback: let queued writes continue when live stock read is
      // unavailable. Final stock reconciliation happens when network restores.
      if (e.code == 'unavailable') return;
      rethrow;
    }
    if (requestedQty > available) {
      throw Exception('Insufficient stock. Available: ${available.toStringAsFixed(2)}, '
          'requested: ${requestedQty.toStringAsFixed(2)}');
    }
  }

  Future<Map<int, Product>> _productsById() async {
    final snap = await _products.get();
    return {for (final d in snap.docs) (int.tryParse(d.id) ?? 0): productFromDoc(d)};
  }
}
