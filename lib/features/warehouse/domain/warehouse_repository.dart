import '../../../core/database/app_database.dart';
import 'inventory_mode.dart';

abstract class WarehouseRepository {
  // Inventory mode.
  Stream<InventoryMode> watchMode();
  Future<InventoryMode> getMode();
  Future<void> setMode(InventoryMode mode);

  // Warehouses.
  Stream<List<Warehouse>> watchWarehouses();
  Future<List<Warehouse>> activeWarehouses();
  Future<int> defaultWarehouseId();
  Future<int> addWarehouse(String name, {bool isDefault = false});
  Future<void> renameWarehouse(int id, String name);
  Future<void> setWarehouseActive(int id, bool active);
  Future<void> setDefaultWarehouse(int id);
  Future<void> deleteWarehouse(int id);
}
