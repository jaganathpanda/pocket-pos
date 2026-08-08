import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../core/database/app_database.dart';
import '../../../core/firestore/firestore_ids.dart';
import '../../../core/firestore/firestore_mappers.dart';
import '../../../core/firestore/store_scope.dart';
import '../../../core/models/discount_policy.dart';
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

  /// Reads the store-configured invoice prefix from
  /// `settings/invoice_branding`. Falls back to 'INV' on any error or when
  /// the setting has not been configured yet.
  Future<String> _invoicePrefix() async {
    try {
      final snap = await storeCollection(_db, _storeId, 'settings')
          .doc('invoice_branding')
          .get();
      final prefix =
          (snap.data()?['invoicePrefix'] as String?)?.trim().toUpperCase();
      return (prefix != null && prefix.isNotEmpty) ? prefix : 'INV';
    } catch (_) {
      return 'INV';
    }
  }

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
  Future<void> updateCartDiscountPercent(int cartId, double percent) async {
    final normalized = percent.clamp(0, 100).toDouble();
    final policy = await _discountPolicy();
    if (!policy.enabled) {
      throw Exception('Bill discount is disabled in Settings.');
    }
    if (normalized > policy.maxBillDiscountPercent + 0.0001) {
      throw Exception(
        'Discount ${normalized.toStringAsFixed(2)}% exceeds max '
        '${policy.maxBillDiscountPercent.toStringAsFixed(2)}%',
      );
    }

    final itemsSnap = await _cartItems.where('cartId', isEqualTo: cartId).get();
    for (final d in itemsSnap.docs) {
      final item = cartItemFromDoc(d);
      final lineSub = (item.quantity * item.unitPrice).clamp(0, 999999999);
      final lineDiscount = (lineSub * (normalized / 100)).clamp(0, lineSub).toDouble();
      _write(d.reference.set({'discountAmount': lineDiscount}, SetOptions(merge: true)));
    }

    _write(_carts.doc('$cartId').set({
      'billDiscountPercent': normalized,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true)));
  }

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
  Future<SalesReturnResult> processSaleReturn({
    required int saleId,
    required String reason,
    required String refundMethod,
  }) async {
    final itemsSnap = await _saleItems.where('saleId', isEqualTo: saleId).get();
    final lineRequests = <SaleReturnLineRequest>[];
    for (final doc in itemsSnap.docs) {
      final item = saleItemFromDoc(doc);
      final returnedQty = fsNum(doc.data()['returnedQty']);
      final remaining = (item.quantity - returnedQty).clamp(0, item.quantity);
      if (remaining > 0) {
        lineRequests
            .add(SaleReturnLineRequest(saleItemId: item.id, quantity: remaining.toDouble()));
      }
    }
    if (lineRequests.isEmpty) {
      throw Exception('All items are already returned for this invoice.');
    }
    return processPartialSaleReturn(
      saleId: saleId,
      lines: lineRequests,
      reason: reason,
      refundMethod: refundMethod,
    );
  }

  @override
  Future<SalesReturnResult> processPartialSaleReturn({
    required int saleId,
    required List<SaleReturnLineRequest> lines,
    required String reason,
    required String refundMethod,
  }) async {
    final trimmedReason = reason.trim();
    if (trimmedReason.isEmpty) {
      throw Exception('Return reason is required');
    }
    if (lines.isEmpty) {
      throw Exception('Select at least one line item quantity to return.');
    }

    final saleDoc = await cacheSafeDoc(_sales, '$saleId');
    if (saleDoc == null || !saleDoc.exists) throw Exception('Sale not found');
    final sale = saleFromDoc(saleDoc);
    final status = sale.paymentStatus.trim().toLowerCase();
    if (status == 'returned' || status == 'refunded') {
      throw Exception('This invoice is already returned.');
    }

    final lineQtyById = <int, double>{};
    for (final line in lines) {
      if (line.quantity <= 0) continue;
      lineQtyById[line.saleItemId] =
          (lineQtyById[line.saleItemId] ?? 0) + line.quantity;
    }
    if (lineQtyById.isEmpty) {
      throw Exception('Return quantity must be greater than 0.');
    }

    final itemsSnap = await _saleItems.where('saleId', isEqualTo: saleId).get();
    final itemDocById = {
      for (final d in itemsSnap.docs)
        (int.tryParse(d.id) ?? 0): d,
    };

    var returnedAmountNow = 0.0;
    var returnedQtyTotalNow = 0.0;
    final restockLines = <({int productId, double qty})>[];

    for (final entry in lineQtyById.entries) {
      final itemDoc = itemDocById[entry.key];
      if (itemDoc == null) {
        throw Exception('Sale item not found: ${entry.key}');
      }
      final item = saleItemFromDoc(itemDoc);
      final alreadyReturnedQty = fsNum(itemDoc.data()['returnedQty']);
      final remainingQty =
          (item.quantity - alreadyReturnedQty).clamp(0, item.quantity);
      final reqQty = entry.value;

      if (reqQty > remainingQty + 0.0001) {
        throw Exception(
          'Return qty exceeds remaining qty for item ${item.productId}. Remaining: '
          '${remainingQty.toStringAsFixed(2)}',
        );
      }

      final lineReturnAmount =
          (item.lineTotal * (reqQty / item.quantity)).clamp(0, item.lineTotal);
      returnedAmountNow += lineReturnAmount;
      returnedQtyTotalNow += reqQty;
      restockLines.add((productId: item.productId, qty: reqQty));

      final nextReturnedQty = (alreadyReturnedQty + reqQty)
          .clamp(0, item.quantity)
          .toDouble();
      final nextReturnedAmount =
          fsNum(itemDoc.data()['returnedAmount']) + lineReturnAmount;
      _write(itemDoc.reference.set({
        'returnedQty': nextReturnedQty,
        'returnedAmount': nextReturnedAmount,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)));
    }

    if (returnedAmountNow <= 0) {
      throw Exception('Nothing to return for selected quantities.');
    }

    final currentReturnedAmount = (saleDoc.data()?['returnedAmount'] as num?)
            ?.toDouble() ??
        0.0;
    final nextReturnedAmount = currentReturnedAmount + returnedAmountNow;
    final nextGrandTotal = (sale.grandTotal - returnedAmountNow)
        .clamp(0, sale.grandTotal)
        .toDouble();

    final paymentsSnap = await _payments.where('saleId', isEqualTo: saleId).get();
    final netPaidBefore = paymentsSnap.docs
        .map(paymentFromDoc)
        .fold<double>(0, (sum, p) => sum + p.amount);
    final refundAmount =
        math.max(0, (netPaidBefore - nextGrandTotal)).toDouble();

    final stock = await _stockContext(sale.warehouseId);
    if (stock.track) {
      for (final r in restockLines) {
        _write(_inventory.stockIn(
          productId: r.productId,
          warehouseId: stock.warehouseId,
          quantity: r.qty,
          note: 'Sale return ${sale.invoiceNo}',
        ));
      }
    }

    if (refundAmount > 0) {
      final refundId = newIntId();
      _write(_payments.doc('$refundId').set({
        'saleId': saleId,
        'method': refundMethod.trim().isEmpty ? 'refund' : refundMethod.trim(),
        'amount': -refundAmount,
        'referenceNo': 'SALE_RETURN_PARTIAL',
        'note': trimmedReason,
        'paidAt': FieldValue.serverTimestamp(),
      }));
    }

    final netPaidAfter = netPaidBefore - refundAmount;
    final fullyReturned = nextGrandTotal <= 0.0001;
    final nextStatus = fullyReturned
        ? (refundAmount > 0 ? 'refunded' : 'returned')
        : (netPaidAfter + 0.0001 >= nextGrandTotal
            ? 'paid'
            : (netPaidAfter > 0 ? 'partial' : 'credit'));

    _write(_sales.doc('$saleId').set({
      'grandTotal': nextGrandTotal,
      'returnedAmount': nextReturnedAmount,
      'lastReturnQty': returnedQtyTotalNow,
      'lastReturnAmount': returnedAmountNow,
      'lastReturnReason': trimmedReason,
      'paymentStatus': nextStatus,
      'returnedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true)));

    return SalesReturnResult(
      returnedAmount: returnedAmountNow,
      refundAmount: refundAmount,
      stockRestocked: stock.track,
      fullyReturned: fullyReturned,
    );
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
    final policy = await _discountPolicy();

    double subTotal = 0, discountTotal = 0, taxTotal = 0;
    for (final item in items) {
      await _assertStock(item.productId, item.quantity, stock);
      final lineSub = item.quantity * item.unitPrice;
      final taxable = lineSub - item.discountAmount;
      subTotal += lineSub;
      discountTotal += item.discountAmount;
      taxTotal += taxable * (item.taxPercent / 100);
    }
    final effectiveDiscountPercent =
        subTotal <= 0 ? 0.0 : (discountTotal * 100 / subTotal);
    if (policy.enabled &&
        effectiveDiscountPercent > policy.maxBillDiscountPercent + 0.0001) {
      throw Exception(
        'Bill discount ${effectiveDiscountPercent.toStringAsFixed(2)}% exceeds '
        'max ${policy.maxBillDiscountPercent.toStringAsFixed(2)}% configured in Settings.',
      );
    }
    final grandTotal = subTotal - discountTotal + taxTotal;
    final normalizedPaid = paidAmount < 0 ? 0.0 : paidAmount;
    final isFullyPaid = normalizedPaid + 0.0001 >= grandTotal;
    if (!isFullyPaid && paymentMode != 'credit') {
      throw Exception('Paid amount is less than total. Select Credit payment mode for udhar.');
    }
    final paymentStatus =
        isFullyPaid ? 'paid' : (normalizedPaid > 0 ? 'partial' : 'credit');
    final invoiceNo = '${await _invoicePrefix()}-$_now';
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
      'billDiscountPercent': effectiveDiscountPercent,
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

  Future<DiscountPolicy> _discountPolicy() async {
    try {
      final snap = await storeCollection(_db, _storeId, 'settings')
          .doc('discount_policy')
          .get();
      return DiscountPolicy.fromFirestoreMap(snap.data());
    } catch (_) {
      return const DiscountPolicy.defaults();
    }
  }
}
