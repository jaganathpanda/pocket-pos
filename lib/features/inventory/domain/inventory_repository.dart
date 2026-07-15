import '../../../core/database/app_database.dart';

abstract class InventoryRepository {
  /// Watches inventory rows, optionally limited to a single warehouse.
  Stream<List<InventoryWithProduct>> watchInventory({int? warehouseId});

  Future<void> stockIn({
    required int productId,
    required int warehouseId,
    required double quantity,
    double unitCost,
    String? note,
  });
  Future<void> stockOut({
    required int productId,
    required int warehouseId,
    required double quantity,
    String? note,
  });
  Future<void> setStock({
    required int productId,
    required int warehouseId,
    required double quantity,
  });

  /// Moves [quantity] of [productId] from one warehouse to another.
  Future<void> transferStock({
    required int productId,
    required int fromWarehouseId,
    required int toWarehouseId,
    required double quantity,
    String? note,
  });

  Future<double> availableStock({
    required int productId,
    required int warehouseId,
  });
}

class InventoryWithProduct {
  const InventoryWithProduct({
    required this.inventory,
    required this.product,
    this.warehouseName,
  });

  final InventoryData inventory;
  final Product product;
  final String? warehouseName;
}
