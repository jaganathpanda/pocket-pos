import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../domain/inventory_repository.dart';

class InventoryRepositoryImpl implements InventoryRepository {
  InventoryRepositoryImpl(this._db);

  final AppDatabase _db;

  @override
  Stream<List<InventoryWithProduct>> watchInventory({int? warehouseId}) {
    final query = _db.select(_db.products).join([
      innerJoin(_db.inventory, _db.inventory.productId.equalsExp(_db.products.id)),
      leftOuterJoin(
        _db.warehouses,
        _db.warehouses.id.equalsExp(_db.inventory.warehouseId),
      ),
    ]);
    if (warehouseId != null) {
      query.where(_db.inventory.warehouseId.equals(warehouseId));
    }

    return query.watch().map(
          (rows) => rows
              .map(
                (r) => InventoryWithProduct(
                  inventory: r.readTable(_db.inventory),
                  product: r.readTable(_db.products),
                  warehouseName: r.readTableOrNull(_db.warehouses)?.name,
                ),
              )
              .toList(),
        );
  }

  @override
  Future<void> stockIn({
    required int productId,
    required int warehouseId,
    required double quantity,
    double unitCost = 0,
    String? note,
  }) async {
    await _applyStock(productId: productId, warehouseId: warehouseId, delta: quantity);
    await _logTxn(
      productId: productId,
      warehouseId: warehouseId,
      type: 'in',
      quantity: quantity,
      unitCost: unitCost,
      note: note,
    );
  }

  @override
  Future<void> stockOut({
    required int productId,
    required int warehouseId,
    required double quantity,
    String? note,
  }) async {
    await _applyStock(productId: productId, warehouseId: warehouseId, delta: -quantity);
    await _logTxn(
      productId: productId,
      warehouseId: warehouseId,
      type: 'out',
      quantity: quantity,
      note: note,
    );
  }

  @override
  Future<void> setStock({
    required int productId,
    required int warehouseId,
    required double quantity,
  }) async {
    final qty = quantity.clamp(0, 999999999).toDouble();
    final row = await _row(productId, warehouseId);

    if (row == null) {
      await _db.into(_db.inventory).insert(
            InventoryCompanion.insert(
              productId: productId,
              variantId: const Value(null),
              warehouseId: Value(warehouseId),
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

    await _logTxn(
      productId: productId,
      warehouseId: warehouseId,
      type: 'adjust',
      quantity: quantity,
      note: 'Manual stock set',
    );
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

    await _db.transaction(() async {
      final source = await _row(productId, fromWarehouseId);
      final available = source?.availableStock ?? 0;
      if (quantity > available) {
        throw Exception(
            'Insufficient stock in source. Available: ${available.toStringAsFixed(2)}');
      }
      await _applyStock(productId: productId, warehouseId: fromWarehouseId, delta: -quantity);
      await _applyStock(productId: productId, warehouseId: toWarehouseId, delta: quantity);

      final label = note ?? 'Transfer';
      await _logTxn(
        productId: productId,
        warehouseId: fromWarehouseId,
        type: 'transfer',
        quantity: -quantity,
        note: label,
      );
      await _logTxn(
        productId: productId,
        warehouseId: toWarehouseId,
        type: 'transfer',
        quantity: quantity,
        note: label,
      );
    });
  }

  @override
  Future<double> availableStock({
    required int productId,
    required int warehouseId,
  }) async {
    final row = await _row(productId, warehouseId);
    return row?.availableStock ?? 0;
  }

  Future<InventoryData?> _row(int productId, int warehouseId) {
    return (_db.select(_db.inventory)
          ..where((i) =>
              i.productId.equals(productId) &
              i.variantId.isNull() &
              i.warehouseId.equals(warehouseId)))
        .getSingleOrNull();
  }

  Future<void> _applyStock({
    required int productId,
    required int warehouseId,
    required double delta,
  }) async {
    final row = await _row(productId, warehouseId);

    if (row == null) {
      final start = delta > 0 ? delta : 0.0;
      await _db.into(_db.inventory).insert(
            InventoryCompanion.insert(
              productId: productId,
              variantId: const Value(null),
              warehouseId: Value(warehouseId),
              currentStock: Value(start),
              availableStock: Value(start),
            ),
          );
      return;
    }

    final next = (row.currentStock + delta).clamp(0, 999999999).toDouble();
    await (_db.update(_db.inventory)..where((i) => i.id.equals(row.id))).write(
      InventoryCompanion(
        currentStock: Value(next),
        availableStock: Value(next),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> _logTxn({
    required int productId,
    required int warehouseId,
    required String type,
    required double quantity,
    double unitCost = 0,
    String? note,
  }) async {
    await _db.into(_db.inventoryTransactions).insert(
          InventoryTransactionsCompanion.insert(
            productId: productId,
            variantId: const Value(null),
            warehouseId: Value(warehouseId),
            type: type,
            quantity: quantity,
            unitCost: Value(unitCost),
            note: Value(note),
          ),
        );
  }
}
