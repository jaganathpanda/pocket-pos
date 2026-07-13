import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../features/inventory/data/inventory_repository_impl.dart';
import '../domain/purchase_repository.dart';

class PurchaseRepositoryImpl implements PurchaseRepository {
  PurchaseRepositoryImpl(this._db);

  final AppDatabase _db;

  @override
  Stream<List<PurchaseWithSupplier>> watchAll() {
    final query = _db.select(_db.purchases).join([
      leftOuterJoin(
        _db.suppliers,
        _db.suppliers.id.equalsExp(_db.purchases.supplierId),
      ),
    ])
      ..orderBy([OrderingTerm.desc(_db.purchases.purchasedAt)]);

    return query.watch().map(
          (rows) => rows
              .map(
                (r) => PurchaseWithSupplier(
                  purchase: r.readTable(_db.purchases),
                  supplier: r.readTableOrNull(_db.suppliers),
                ),
              )
              .toList(),
        );
  }

  @override
  Stream<List<PurchaseItemWithProduct>> watchItems(int purchaseId) {
    final query = _db.select(_db.purchaseItems).join([
      innerJoin(_db.products, _db.products.id.equalsExp(_db.purchaseItems.productId)),
    ])
      ..where(_db.purchaseItems.purchaseId.equals(purchaseId));

    return query.watch().map(
          (rows) => rows
              .map(
                (r) => PurchaseItemWithProduct(
                  item: r.readTable(_db.purchaseItems),
                  product: r.readTable(_db.products),
                ),
              )
              .toList(),
        );
  }

  @override
  Future<int> createPurchase({
    int? supplierId,
    String? invoiceNo,
    String? note,
  }) {
    return _db.into(_db.purchases).insert(
          PurchasesCompanion.insert(
            supplierId: Value(supplierId),
            invoiceNo: Value(invoiceNo),
            note: Value(note),
            status: const Value('draft'),
          ),
        );
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

    await _db.into(_db.purchaseItems).insert(
          PurchaseItemsCompanion.insert(
            purchaseId: purchaseId,
            productId: productId,
            variantId: Value(variantId),
            quantity: quantity,
            unitCost: unitCost,
            taxPercent: Value(taxPercent),
            lineTotal: lineTotal,
          ),
        );

    await _recalcPurchaseTotals(purchaseId);
  }

  @override
  Future<void> removeItem(int purchaseItemId) async {
    final item = await (_db.select(_db.purchaseItems)..where((i) => i.id.equals(purchaseItemId))).getSingleOrNull();
    if (item == null) return;
    await (_db.delete(_db.purchaseItems)..where((i) => i.id.equals(purchaseItemId))).go();
    await _recalcPurchaseTotals(item.purchaseId);
  }

  @override
  Future<void> finalize(int purchaseId) async {
    final items = await (_db.select(_db.purchaseItems)..where((i) => i.purchaseId.equals(purchaseId))).get();

    await _db.transaction(() async {
      final repo = InventoryRepositoryImpl(_db);
      for (final item in items) {
        await repo.stockIn(
          productId: item.productId,
          quantity: item.quantity,
          unitCost: item.unitCost,
          note: 'Purchase #$purchaseId',
        );
      }

      await (_db.update(_db.purchases)..where((p) => p.id.equals(purchaseId))).write(
        const PurchasesCompanion(status: Value('received'), paymentStatus: Value('unpaid')),
      );
    });
  }

  @override
  Future<void> deletePurchase(int purchaseId) async {
    await (_db.delete(_db.purchaseItems)..where((i) => i.purchaseId.equals(purchaseId))).go();
    await (_db.delete(_db.purchases)..where((p) => p.id.equals(purchaseId))).go();
  }

  Future<void> _recalcPurchaseTotals(int purchaseId) async {
    final items = await (_db.select(_db.purchaseItems)..where((i) => i.purchaseId.equals(purchaseId))).get();
    final subTotal = items.fold<double>(0, (s, i) => s + i.quantity * i.unitCost);
    final taxTotal = items.fold<double>(0, (s, i) => s + i.quantity * i.unitCost * (i.taxPercent / 100));

    await (_db.update(_db.purchases)..where((p) => p.id.equals(purchaseId))).write(
      PurchasesCompanion(
        subTotal: Value(subTotal),
        taxTotal: Value(taxTotal),
        grandTotal: Value(subTotal + taxTotal),
      ),
    );
  }
}
