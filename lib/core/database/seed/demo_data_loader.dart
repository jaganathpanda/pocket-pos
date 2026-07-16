import 'package:drift/drift.dart';

import '../app_database.dart';
import 'bakery_demo_data.dart';
import 'demo_business_type.dart';
import 'demo_catalog.dart';
import 'electronics_demo_data.dart';
import 'garment_demo_data.dart';
import 'grocery_demo_data.dart';
import 'pharmacy_demo_data.dart';

/// Seeds first-run demo data (users, POS counters, default warehouse, settings)
/// plus a product catalog chosen by [DemoBusinessType].
class DemoDataLoader {
  DemoDataLoader(this.db);

  final AppDatabase db;

  /// Catalog used on a fresh install / demo reset.
  static const DemoBusinessType defaultBusinessType = DemoBusinessType.grocery;

  static DemoCatalog catalogFor(DemoBusinessType type) {
    switch (type) {
      case DemoBusinessType.grocery:
        return groceryCatalog;
      case DemoBusinessType.pharmacy:
        return pharmacyCatalog;
      case DemoBusinessType.garment:
        return garmentCatalog;
      case DemoBusinessType.electronics:
        return electronicsCatalog;
      case DemoBusinessType.bakery:
        return bakeryCatalog;
    }
  }

  /// Full first-run seed: roles/users, POS counters, a default warehouse,
  /// the inventory-mode setting, a walk-in customer, and the [type] catalog.
  Future<void> seedAll({DemoBusinessType type = defaultBusinessType}) async {
    await _seedBootstrap();
    await seedCatalog(type);
  }

  Future<void> _seedBootstrap() async {
    final superAdminRoleId =
        await db.into(db.roles).insert(RolesCompanion.insert(name: 'super_admin'));
    final cashierRoleId =
        await db.into(db.roles).insert(RolesCompanion.insert(name: 'cashier'));

    await db.into(db.users).insert(
          UsersCompanion.insert(
            username: 'owner',
            passwordHash: '1234',
            pinHash: '1234',
            roleId: superAdminRoleId,
          ),
        );

    final pos1Id =
        await db.into(db.posCounters).insert(PosCountersCompanion.insert(name: 'POS1'));
    await db.into(db.posCounters).insert(PosCountersCompanion.insert(name: 'POS2'));

    await db.into(db.users).insert(
          UsersCompanion.insert(
            username: 'cashier',
            passwordHash: '1234',
            pinHash: '1234',
            roleId: cashierRoleId,
            posCounterId: Value(pos1Id),
          ),
        );

    await db.into(db.warehouses).insert(
          WarehousesCompanion.insert(name: 'Main Store', isDefault: const Value(true)),
        );
    await db.into(db.appSettings).insert(
          AppSettingsCompanion.insert(key: 'inventory_mode', value: 'single'),
        );

    await db.into(db.customers).insert(
          CustomersCompanion.insert(
            name: 'Walk-in Customer',
            mobile: const Value('9999999999'),
          ),
        );
  }

  /// Inserts the categories, products and opening stock for [type] into the
  /// default warehouse. Safe to call on an already-bootstrapped database.
  Future<void> seedCatalog(DemoBusinessType type) async {
    final catalog = catalogFor(type);
    final warehouseId = await db.defaultWarehouseId();

    // Remember which catalog is currently loaded (shown in Settings).
    await db.into(db.appSettings).insertOnConflictUpdate(
          AppSettingsCompanion.insert(
              key: 'demo_business_type', value: type.name),
        );

    final categoryIdByName = <String, int>{};
    for (final name in catalog.categories) {
      categoryIdByName[name] =
          await db.into(db.categories).insert(CategoriesCompanion.insert(name: name));
    }

    for (final p in catalog.products) {
      final productId = await db.into(db.products).insert(
            ProductsCompanion.insert(
              name: p.name,
              productCode: p.code,
              barcode: Value(p.barcode),
              categoryId: Value(categoryIdByName[p.category]),
              purchasePrice: Value(p.purchasePrice),
              sellingPrice: Value(p.sellingPrice),
              mrp: Value(p.mrp),
              taxPercent: Value(p.taxPercent),
              unit: Value(p.unit),
            ),
          );

      await db.into(db.inventory).insert(
            InventoryCompanion.insert(
              productId: productId,
              variantId: const Value(null),
              warehouseId: Value(warehouseId),
              currentStock: Value(p.stock),
              availableStock: Value(p.stock),
              lowStockThreshold: Value(p.lowStock),
            ),
          );
    }
  }
}
