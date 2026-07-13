import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../domain/inventory_repository.dart';

class InventoryRepositoryImpl implements InventoryRepository {
  InventoryRepositoryImpl(this._db);

  final AppDatabase _db;

  @override
  Stream<List<InventoryWithProduct>> watchInventory() {
    final query = _db.select(_db.products).join([
      innerJoin(_db.inventory, _db.inventory.productId.equalsExp(_db.products.id)),
    ]);

    return query.watch().map(
          (rows) => rows
              .map(
                (r) => InventoryWithProduct(
                  inventory: r.readTable(_db.inventory),
                  product: r.readTable(_db.products),
                ),
              )
              .toList(),
        );
  }

  @override
  Future<void> stockIn({required int productId, required double quantity, double unitCost = 0, String? note}) async {
    await _applyStock(productId: productId, delta: quantity);
    await _db.into(_db.inventoryTransactions).insert(
          InventoryTransactionsCompanion.insert(
            productId: productId,
            variantId: const Value(null),
            type: 'in',
            quantity: quantity,
            unitCost: Value(unitCost),
            note: Value(note),
          ),
        );
  }

  @override
  Future<void> stockOut({required int productId, required double quantity, String? note}) async {
    await _applyStock(productId: productId, delta: -quantity);
    await _db.into(_db.inventoryTransactions).insert(
          InventoryTransactionsCompanion.insert(
            productId: productId,
            variantId: const Value(null),
            type: 'out',
            quantity: quantity,
            note: Value(note),
          ),
        );
  }

  @override
  Future<void> setStock({required int productId, required double quantity}) async {
    final row = await (_db.select(_db.inventory)
          ..where((i) => i.productId.equals(productId) & i.variantId.isNull()))
        .getSingleOrNull();

    final qty = quantity.clamp(0, 999999999).toDouble();

    if (row == null) {
      await _db.into(_db.inventory).insert(
            InventoryCompanion.insert(
              productId: productId,
              variantId: const Value(null),
              currentStock: Value(qty),
              availableStock: Value(qty),
            ),
          );
    } else {
      await (_db.update(_db.inventory)..where((i) => i.id.equals(row.id))).write(
        InventoryCompanion(
          currentStock: Value(qty),
          availableStock: Value(qty),
          updatedAt: Value(DateTime.now()),
        ),
      );
    }

    await _db.into(_db.inventoryTransactions).insert(
          InventoryTransactionsCompanion.insert(
            productId: productId,
            variantId: const Value(null),
            type: 'adjust',
            quantity: quantity,
            note: const Value('Manual stock set'),
          ),
        );
  }

  Future<void> _applyStock({required int productId, required double delta}) async {
    final row = await (_db.select(_db.inventory)
          ..where((i) => i.productId.equals(productId) & i.variantId.isNull()))
        .getSingleOrNull();

    if (row == null) {
      await _db.into(_db.inventory).insert(
            InventoryCompanion.insert(
              productId: productId,
              variantId: const Value(null),
              currentStock: Value(delta > 0 ? delta : 0),
              availableStock: Value(delta > 0 ? delta : 0),
            ),
          );
      return;
    }

    final current = (row.currentStock + delta).clamp(0, 999999999);
    await (_db.update(_db.inventory)..where((i) => i.id.equals(row.id))).write(
      InventoryCompanion(
        currentStock: Value(current.toDouble()),
        availableStock: Value(current.toDouble()),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
}
