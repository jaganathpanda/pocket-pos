import '../../../core/database/app_database.dart';

abstract class InventoryRepository {
  Stream<List<InventoryWithProduct>> watchInventory();
  Future<void> stockIn({required int productId, required double quantity, double unitCost = 0, String? note});
  Future<void> stockOut({required int productId, required double quantity, String? note});
  Future<void> setStock({required int productId, required double quantity});
}

class InventoryWithProduct {
  const InventoryWithProduct({required this.inventory, required this.product});

  final InventoryData inventory;
  final Product product;
}
