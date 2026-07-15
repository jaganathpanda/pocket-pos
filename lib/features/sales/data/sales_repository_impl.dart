import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../domain/sales_repository.dart';

class SalesRepositoryImpl implements SalesRepository {
  SalesRepositoryImpl(this._db);

  final AppDatabase _db;

  @override
  Stream<List<Cart>> watchActiveCarts(int? posCounterId) {
    final query = _db.select(_db.carts)
      ..where((c) => Expression.or([c.status.equals('active'), c.status.equals('hold')]))
      ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]);
    if (posCounterId != null) {
      query.where((c) => c.posCounterId.equals(posCounterId));
    }
    return query.watch();
  }

  @override
  Stream<List<CartItemWithProduct>> watchCartItems(int cartId) {
    final query = _db.select(_db.cartItems).join([
      innerJoin(_db.products, _db.products.id.equalsExp(_db.cartItems.productId)),
    ])
      ..where(_db.cartItems.cartId.equals(cartId));

    return query.watch().map(
          (rows) => rows
              .map(
                (r) => CartItemWithProduct(
                  item: r.readTable(_db.cartItems),
                  product: r.readTable(_db.products),
                ),
              )
              .toList(),
        );
  }

  @override
  Future<int> createCart(String name, {int? posCounterId, int? warehouseId}) {
    return _db.into(_db.carts).insert(
          CartsCompanion.insert(
            name: name,
            posCounterId: Value(posCounterId),
            warehouseId: Value(warehouseId),
          ),
        );
  }

  @override
  Future<int> createCartWithCustomer(String name, int customerId,
      {int? posCounterId, int? warehouseId}) {
    return _db.into(_db.carts).insert(
          CartsCompanion.insert(
            name: name,
            customerId: Value(customerId),
            posCounterId: Value(posCounterId),
            warehouseId: Value(warehouseId),
          ),
        );
  }

  @override
  Future<void> updateCartCustomer(int cartId, int customerId) {
    return (_db.update(_db.carts)..where((c) => c.id.equals(cartId))).write(
      CartsCompanion(customerId: Value(customerId), updatedAt: Value(DateTime.now())),
    );
  }

  @override
  Future<void> updateCartDiscount(int cartId, double totalDiscount) {
    return (_db.update(_db.carts)..where((c) => c.id.equals(cartId))).write(
      CartsCompanion(updatedAt: Value(DateTime.now())),
    );
  }

  @override
  Future<Cart?> getCart(int cartId) {
    return (_db.select(_db.carts)..where((c) => c.id.equals(cartId))).getSingleOrNull();
  }

  @override
  Future<void> renameCart(int cartId, String name) {
    return (_db.update(_db.carts)..where((c) => c.id.equals(cartId))).write(
      CartsCompanion(name: Value(name), updatedAt: Value(DateTime.now())),
    );
  }

  @override
  Future<void> setCartStatus(int cartId, String status) {
    return (_db.update(_db.carts)..where((c) => c.id.equals(cartId))).write(
      CartsCompanion(status: Value(status), updatedAt: Value(DateTime.now())),
    );
  }

  @override
  Future<void> setCartCounter(int cartId, int posCounterId) {
    return (_db.update(_db.carts)..where((c) => c.id.equals(cartId))).write(
      CartsCompanion(
        posCounterId: Value(posCounterId),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  @override
  Future<void> deleteCart(int cartId) async {
    await (_db.delete(_db.cartItems)..where((i) => i.cartId.equals(cartId))).go();
    await (_db.delete(_db.carts)..where((c) => c.id.equals(cartId))).go();
  }

  @override
  Future<void> addItem({required int cartId, required int productId}) async {
    final product = await (_db.select(_db.products)..where((p) => p.id.equals(productId))).getSingle();
    final cart = await getCart(cartId);
    final stock = await _stockContext(cart?.warehouseId);

    final existing = await (_db.select(_db.cartItems)
          ..where((i) => i.cartId.equals(cartId) & i.productId.equals(productId) & i.variantId.isNull()))
        .getSingleOrNull();

    if (existing != null) {
      final requestedQty = existing.quantity + 1;
      await _assertStockAvailable(
        productId: productId,
        requestedQty: requestedQty,
        stock: stock,
      );

      await (_db.update(_db.cartItems)..where((i) => i.id.equals(existing.id))).write(
        CartItemsCompanion(quantity: Value(requestedQty)),
      );
    } else {
      await _assertStockAvailable(productId: productId, requestedQty: 1, stock: stock);

      await _db.into(_db.cartItems).insert(
            CartItemsCompanion.insert(
              cartId: cartId,
              productId: productId,
              variantId: const Value(null),
              quantity: const Value(1),
              unitPrice: Value(product.sellingPrice),
              taxPercent: Value(product.taxPercent),
            ),
          );
    }

    await (_db.update(_db.carts)..where((c) => c.id.equals(cartId))).write(CartsCompanion(updatedAt: Value(DateTime.now())));
  }

  @override
  Future<void> updateItemQuantity(int cartItemId, double quantity) async {
    if (quantity <= 0) {
      await removeItem(cartItemId);
      return;
    }

    final item = await (_db.select(_db.cartItems)..where((i) => i.id.equals(cartItemId))).getSingleOrNull();
    if (item == null) {
      throw Exception('Cart item not found');
    }

    final cart = await getCart(item.cartId);
    final stock = await _stockContext(cart?.warehouseId);
    await _assertStockAvailable(
      productId: item.productId,
      requestedQty: quantity,
      stock: stock,
    );

    await (_db.update(_db.cartItems)..where((i) => i.id.equals(cartItemId))).write(
      CartItemsCompanion(quantity: Value(quantity)),
    );
  }

  @override
  Future<void> removeItem(int cartItemId) {
    return (_db.delete(_db.cartItems)..where((i) => i.id.equals(cartItemId))).go();
  }

  @override
  Future<void> recordCreditPayment({
    required int saleId,
    required double amount,
    required String method,
    String? referenceNo,
  }) async {
    if (amount <= 0) {
      throw Exception('Payment amount must be greater than 0');
    }

    await _db.transaction(() async {
      final sale = await (_db.select(_db.sales)..where((s) => s.id.equals(saleId))).getSingleOrNull();
      if (sale == null) {
        throw Exception('Sale not found');
      }

      final payments = await (_db.select(_db.payments)..where((p) => p.saleId.equals(saleId))).get();
      final paidBefore = payments.fold<double>(0, (sum, p) => sum + p.amount);
      final newPaid = paidBefore + amount;

      await _db.into(_db.payments).insert(
            PaymentsCompanion.insert(
              saleId: saleId,
              method: method,
              amount: amount,
              referenceNo: Value(referenceNo),
            ),
          );

      final nextStatus = newPaid + 0.0001 >= sale.grandTotal ? 'paid' : 'partial';
      await (_db.update(_db.sales)..where((s) => s.id.equals(saleId))).write(
        SalesCompanion(paymentStatus: Value(nextStatus)),
      );
    });
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
    return _db.transaction(() async {
      final cart = await getCart(cartId);
      if (cart == null) {
        throw Exception('Cart not found');
      }

      final items = await (_db.select(_db.cartItems)..where((i) => i.cartId.equals(cartId))).get();
      if (items.isEmpty) {
        throw Exception('Cart is empty');
      }

      // Handle customer update/creation if mobile is provided
      int? customerId = cart.customerId;
      if (customerMobile != null && customerMobile.isNotEmpty) {
        final existing = await (_db.select(_db.customers)..where((c) => c.mobile.equals(customerMobile))).getSingleOrNull();
        if (existing != null) {
          customerId = existing.id;
          // Update customer info if new name/address provided
          if (customerName != null && customerName.isNotEmpty) {
            await (_db.update(_db.customers)..where((c) => c.id.equals(existing.id))).write(
              CustomersCompanion(
                name: Value(customerName),
                address: Value(customerAddress),
              ),
            );
          }
        } else if (customerName != null && customerName.isNotEmpty) {
          customerId = await _db.into(_db.customers).insert(
            CustomersCompanion.insert(
              name: customerName,
              mobile: Value(customerMobile),
              address: Value(customerAddress),
            ),
          );
        }
      }

      final stock = await _stockContext(cart.warehouseId);

      double subTotal = 0;
      double discountTotal = 0;
      double taxTotal = 0;

      for (final item in items) {
        await _assertStockAvailable(
          productId: item.productId,
          requestedQty: item.quantity,
          stock: stock,
        );

        final lineSub = item.quantity * item.unitPrice;
        final taxable = lineSub - item.discountAmount;
        subTotal += lineSub;
        discountTotal += item.discountAmount;
        taxTotal += taxable * (item.taxPercent / 100);
      }

      final grandTotal = subTotal - discountTotal + taxTotal;
      final normalizedPaid = paidAmount < 0 ? 0 : paidAmount;
      final isFullyPaid = normalizedPaid + 0.0001 >= grandTotal;
      if (!isFullyPaid && paymentMode != 'credit') {
        throw Exception('Paid amount is less than total. Select Credit payment mode for udhar.');
      }
      final paymentStatus = isFullyPaid
          ? 'paid'
          : (normalizedPaid > 0 ? 'partial' : 'credit');
      final invoiceNo = 'INV-${DateTime.now().millisecondsSinceEpoch}';

      final saleId = await _db.into(_db.sales).insert(
            SalesCompanion.insert(
              cartId: Value(cartId),
              invoiceNo: invoiceNo,
              customerId: Value(customerId),
              posCounterId: Value(cart.posCounterId),
              warehouseId: Value(stock.track ? stock.warehouseId : null),
              subTotal: subTotal,
              discountTotal: discountTotal,
              taxTotal: taxTotal,
              grandTotal: grandTotal,
              paymentStatus: Value(paymentStatus),
            ),
          );

      for (final item in items) {
        final lineSub = item.quantity * item.unitPrice;
        final taxable = lineSub - item.discountAmount;
        final lineTotal = taxable + taxable * (item.taxPercent / 100);

        await _db.into(_db.saleItems).insert(
              SaleItemsCompanion.insert(
                saleId: saleId,
                productId: item.productId,
                variantId: Value(item.variantId),
                quantity: item.quantity,
                unitPrice: item.unitPrice,
                discountAmount: Value(item.discountAmount),
                taxPercent: Value(item.taxPercent),
                lineTotal: lineTotal,
              ),
            );

        if (stock.track) {
          final inv = await (_db.select(_db.inventory)
                ..where((i) =>
                    i.productId.equals(item.productId) &
                    i.variantId.isNull() &
                    i.warehouseId.equals(stock.warehouseId)))
              .getSingleOrNull();

          if (inv != null) {
            final newQty = (inv.availableStock - item.quantity).clamp(0, 99999999).toDouble();
            await (_db.update(_db.inventory)..where((i) => i.id.equals(inv.id))).write(
              InventoryCompanion(currentStock: Value(newQty), availableStock: Value(newQty), updatedAt: Value(DateTime.now())),
            );

            await _db.into(_db.inventoryTransactions).insert(
                  InventoryTransactionsCompanion.insert(
                    productId: item.productId,
                    variantId: const Value(null),
                    warehouseId: Value(stock.warehouseId),
                    type: 'out',
                    quantity: item.quantity,
                    note: Value('Sale $invoiceNo'),
                  ),
                );
          }
        }
      }

      await _db.into(_db.payments).insert(
            PaymentsCompanion.insert(
              saleId: saleId,
              method: paymentMode,
              amount: paidAmount,
            ),
          );

      await (_db.update(_db.carts)..where((c) => c.id.equals(cartId))).write(
        const CartsCompanion(status: Value('completed')),
      );

      return saleId;
    });
  }

  Future<void> _assertStockAvailable({
    required int productId,
    required double requestedQty,
    required ({bool track, int warehouseId}) stock,
  }) async {
    if (requestedQty < 0) {
      throw Exception('Quantity cannot be negative');
    }
    // No-inventory mode: never block on stock.
    if (!stock.track) return;

    final inv = await (_db.select(_db.inventory)
          ..where((i) =>
              i.productId.equals(productId) &
              i.variantId.isNull() &
              i.warehouseId.equals(stock.warehouseId)))
        .getSingleOrNull();

    final available = inv?.availableStock ?? 0;
    if (requestedQty > available) {
      throw Exception('Insufficient stock. Available: ${available.toStringAsFixed(2)}, requested: ${requestedQty.toStringAsFixed(2)}');
    }
  }

  /// Resolves whether stock is tracked and which warehouse a cart draws from.
  Future<({bool track, int warehouseId})> _stockContext(int? cartWarehouseId) async {
    final modeRow = await (_db.select(_db.appSettings)
          ..where((s) => s.key.equals('inventory_mode')))
        .getSingleOrNull();
    final track = (modeRow?.value ?? 'single') != 'none';
    final warehouseId = cartWarehouseId ?? await _db.defaultWarehouseId();
    return (track: track, warehouseId: warehouseId);
  }
}
