import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import 'connection/connection.dart';

part 'app_database.g.dart';

class Roles extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().unique()();
}

class Users extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get username => text().withLength(min: 3, max: 50).unique()();
  TextColumn get passwordHash => text()();
  TextColumn get pinHash => text()();
  IntColumn get roleId => integer().references(Roles, #id)();
  // POS counter this user is locked to. Null = owner/manager (sees all counters).
  IntColumn get posCounterId => integer().nullable().references(PosCounters, #id)();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class PosCounters extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 50).unique()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class Warehouses extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 60).unique()();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Simple key/value store for app-wide settings (e.g. inventory mode).
class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

class Shops extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get gstNumber => text().nullable()();
  TextColumn get mobile => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get address => text().nullable()();
  TextColumn get invoicePrefix => text().withDefault(const Constant('INV'))();
  TextColumn get currency => text().withDefault(const Constant('INR'))();
  TextColumn get taxMode => text().withDefault(const Constant('exclusive'))();
}

class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().customConstraint('UNIQUE COLLATE NOCASE')();
  IntColumn get parentCategoryId => integer().nullable().references(Categories, #id)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class Products extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get productCode => text().unique()();
  TextColumn get sku => text().nullable()();
  TextColumn get barcode => text().nullable()();
  IntColumn get categoryId => integer().nullable().references(Categories, #id)();
  TextColumn get brand => text().nullable()();
  RealColumn get purchasePrice => real().withDefault(const Constant(0))();
  RealColumn get sellingPrice => real().withDefault(const Constant(0))();
  RealColumn get mrp => real().withDefault(const Constant(0))();
  RealColumn get taxPercent => real().withDefault(const Constant(0))();
  TextColumn get unit => text().withDefault(const Constant('piece'))();
  TextColumn get imagePath => text().nullable()();
  TextColumn get description => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class ProductVariants extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get productId => integer().references(Products, #id)();
  TextColumn get name => text()();
  TextColumn get barcode => text().nullable()();
  RealColumn get purchasePrice => real().withDefault(const Constant(0))();
  RealColumn get sellingPrice => real().withDefault(const Constant(0))();
  RealColumn get mrp => real().withDefault(const Constant(0))();
  RealColumn get taxPercent => real().withDefault(const Constant(0))();
  TextColumn get unit => text().withDefault(const Constant('piece'))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
}

class Inventory extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get productId => integer().references(Products, #id)();
  IntColumn get variantId => integer().nullable().references(ProductVariants, #id)();
  IntColumn get warehouseId => integer().nullable().references(Warehouses, #id)();
  RealColumn get currentStock => real().withDefault(const Constant(0))();
  RealColumn get availableStock => real().withDefault(const Constant(0))();
  RealColumn get lowStockThreshold => real().withDefault(const Constant(5))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
        {productId, variantId, warehouseId},
      ];
}

class InventoryTransactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get productId => integer().references(Products, #id)();
  IntColumn get variantId => integer().nullable().references(ProductVariants, #id)();
  IntColumn get warehouseId => integer().nullable().references(Warehouses, #id)();
  TextColumn get type => text()(); // in, out, adjust, damage, return, transfer
  RealColumn get quantity => real()();
  RealColumn get unitCost => real().withDefault(const Constant(0))();
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class Customers extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get mobile => text().nullable()();
  TextColumn get address => text().nullable()();
  IntColumn get loyaltyPoints => integer().withDefault(const Constant(0))();
}

class Carts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get status => text().withDefault(const Constant('active'))(); // active, hold, completed
  IntColumn get customerId => integer().nullable().references(Customers, #id)();
  IntColumn get posCounterId => integer().nullable().references(PosCounters, #id)();
  IntColumn get warehouseId => integer().nullable().references(Warehouses, #id)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

class CartItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get cartId => integer().references(Carts, #id)();
  IntColumn get productId => integer().references(Products, #id)();
  IntColumn get variantId => integer().nullable().references(ProductVariants, #id)();
  RealColumn get quantity => real().withDefault(const Constant(1))();
  RealColumn get unitPrice => real().withDefault(const Constant(0))();
  RealColumn get discountAmount => real().withDefault(const Constant(0))();
  RealColumn get taxPercent => real().withDefault(const Constant(0))();
  TextColumn get note => text().nullable()();
}

class Sales extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get cartId => integer().nullable().references(Carts, #id)();
  TextColumn get invoiceNo => text().unique()();
  IntColumn get customerId => integer().nullable().references(Customers, #id)();
  IntColumn get posCounterId => integer().nullable().references(PosCounters, #id)();
  IntColumn get warehouseId => integer().nullable().references(Warehouses, #id)();
  RealColumn get subTotal => real()();
  RealColumn get discountTotal => real()();
  RealColumn get taxTotal => real()();
  RealColumn get grandTotal => real()();
  TextColumn get paymentStatus => text().withDefault(const Constant('paid'))();
  DateTimeColumn get soldAt => dateTime().withDefault(currentDateAndTime)();
}

class SaleItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get saleId => integer().references(Sales, #id)();
  IntColumn get productId => integer().references(Products, #id)();
  IntColumn get variantId => integer().nullable().references(ProductVariants, #id)();
  RealColumn get quantity => real()();
  RealColumn get unitPrice => real()();
  RealColumn get discountAmount => real().withDefault(const Constant(0))();
  RealColumn get taxPercent => real().withDefault(const Constant(0))();
  RealColumn get lineTotal => real()();
}

class Payments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get saleId => integer().references(Sales, #id)();
  TextColumn get method => text()();
  RealColumn get amount => real()();
  TextColumn get referenceNo => text().nullable()();
  DateTimeColumn get paidAt => dateTime().withDefault(currentDateAndTime)();
}

class Expenses extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get category => text()();
  RealColumn get amount => real()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get spentAt => dateTime().withDefault(currentDateAndTime)();
}

class Suppliers extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get mobile => text().nullable()();
  TextColumn get gstNumber => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get address => text().nullable()();
  TextColumn get contactPerson => text().nullable()();
  RealColumn get outstandingBalance => real().withDefault(const Constant(0))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class Purchases extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get supplierId => integer().nullable().references(Suppliers, #id)();
  IntColumn get warehouseId => integer().nullable().references(Warehouses, #id)();
  TextColumn get invoiceNo => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('draft'))();
  RealColumn get subTotal => real().withDefault(const Constant(0))();
  RealColumn get taxTotal => real().withDefault(const Constant(0))();
  RealColumn get discountTotal => real().withDefault(const Constant(0))();
  RealColumn get grandTotal => real().withDefault(const Constant(0))();
  TextColumn get paymentStatus => text().withDefault(const Constant('unpaid'))();
  TextColumn get note => text().nullable()();
  DateTimeColumn get purchasedAt => dateTime().withDefault(currentDateAndTime)();
}

class PurchaseItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get purchaseId => integer().references(Purchases, #id)();
  IntColumn get productId => integer().references(Products, #id)();
  IntColumn get variantId => integer().nullable().references(ProductVariants, #id)();
  RealColumn get quantity => real()();
  RealColumn get unitCost => real()();
  RealColumn get taxPercent => real().withDefault(const Constant(0))();
  RealColumn get lineTotal => real()();
}

class Notifications extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get type => text()();
  TextColumn get title => text()();
  TextColumn get message => text()();
  BoolColumn get isRead => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class AuditLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get userId => integer().nullable().references(Users, #id)();
  TextColumn get action => text()();
  TextColumn get entity => text()();
  IntColumn get entityId => integer().nullable()();
  TextColumn get payload => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DriftDatabase(
  tables: [
    Roles,
    Users,
    PosCounters,
    Warehouses,
    AppSettings,
    Shops,
    Categories,
    Products,
    ProductVariants,
    Inventory,
    InventoryTransactions,
    Suppliers,
    Purchases,
    PurchaseItems,
    Customers,
    Carts,
    CartItems,
    Sales,
    SaleItems,
    Payments,
    Expenses,
    Notifications,
    AuditLogs,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(suppliers);
            await m.createTable(purchases);
            await m.createTable(purchaseItems);
          }
          if (from < 3) {
            await m.createTable(posCounters);
            await m.addColumn(users, users.posCounterId);
            await m.addColumn(carts, carts.posCounterId);
            await m.addColumn(sales, sales.posCounterId);
          }
          if (from < 4) {
            await m.createTable(warehouses);
            await m.createTable(appSettings);

            // A default warehouse so existing stock has a home, and default the
            // mode to single-warehouse to preserve current tracking behaviour.
            final defaultWarehouseId = await into(warehouses).insert(
              WarehousesCompanion.insert(
                name: 'Main Store',
                isDefault: const Value(true),
              ),
            );
            await into(appSettings).insert(
              AppSettingsCompanion.insert(
                  key: 'inventory_mode', value: 'single'),
            );

            await m.addColumn(
                inventoryTransactions, inventoryTransactions.warehouseId);
            await m.addColumn(purchases, purchases.warehouseId);
            await m.addColumn(carts, carts.warehouseId);
            await m.addColumn(sales, sales.warehouseId);

            // Rebuild inventory to add warehouseId to the unique key and stamp
            // existing rows with the default warehouse.
            await m.alterTable(
              TableMigration(
                inventory,
                columnTransformer: {
                  inventory.warehouseId: Constant(defaultWarehouseId),
                },
                newColumns: [inventory.warehouseId],
              ),
            );
          }
        },
        beforeOpen: (details) async {
          if (details.wasCreated) {
            await customStatement('CREATE INDEX idx_products_name ON products(name);');
            await customStatement('CREATE INDEX idx_products_barcode ON products(barcode);');
            await customStatement('CREATE INDEX idx_products_code ON products(product_code);');
            await customStatement('CREATE INDEX idx_inventory_product ON inventory(product_id);');
            await customStatement('CREATE INDEX idx_sales_date ON sales(sold_at);');
            await customStatement('CREATE INDEX idx_cart_items_cart ON cart_items(cart_id);');
          }

          // Seed default roles/users (owner + cashier) and demo data on every
          // platform. Without this, native builds open an empty database and
          // the owner/1234 login fails with "Invalid credentials".
          await _seedWebMockDataIfEmpty();

          // Guarantee a default warehouse and an inventory-mode setting exist
          // regardless of how the database got here.
          await _ensureInventoryDefaults();
        },
      );

  /// Idempotently ensures there is at least one (default) warehouse and an
  /// `inventory_mode` setting.
  Future<void> _ensureInventoryDefaults() async {
    final anyWarehouse = await (select(warehouses)..limit(1)).getSingleOrNull();
    if (anyWarehouse == null) {
      await into(warehouses).insert(
        WarehousesCompanion.insert(name: 'Main Store', isDefault: const Value(true)),
      );
    }
    final mode = await (select(appSettings)
          ..where((s) => s.key.equals('inventory_mode')))
        .getSingleOrNull();
    if (mode == null) {
      await into(appSettings).insert(
        AppSettingsCompanion.insert(key: 'inventory_mode', value: 'single'),
      );
    }
  }

  Future<int> defaultWarehouseId() async {
    final def = await (select(warehouses)
          ..where((w) => w.isDefault.equals(true))
          ..limit(1))
        .getSingleOrNull();
    if (def != null) return def.id;
    final any = await (select(warehouses)..limit(1)).getSingleOrNull();
    if (any != null) return any.id;
    return into(warehouses).insert(
      WarehousesCompanion.insert(name: 'Main Store', isDefault: const Value(true)),
    );
  }

  Future<void> resetWebDemoData() async {
    if (!kIsWeb) {
      throw UnsupportedError('Demo data reset is only available on web builds.');
    }

    await transaction(() async {
      await customStatement('PRAGMA foreign_keys = OFF');
      await customStatement('DELETE FROM cart_items');
      await customStatement('DELETE FROM carts');
      await customStatement('DELETE FROM payments');
      await customStatement('DELETE FROM sale_items');
      await customStatement('DELETE FROM sales');
      await customStatement('DELETE FROM inventory_transactions');
      await customStatement('DELETE FROM inventory');
      await customStatement('DELETE FROM product_variants');
      await customStatement('DELETE FROM products');
      await customStatement('DELETE FROM categories');
      await customStatement('DELETE FROM notifications');
      await customStatement('DELETE FROM audit_logs');
      await customStatement('DELETE FROM expenses');
      await customStatement('DELETE FROM customers');
      await customStatement('DELETE FROM shops');
      await customStatement('DELETE FROM users');
      await customStatement('DELETE FROM pos_counters');
      await customStatement('DELETE FROM warehouses');
      await customStatement('DELETE FROM app_settings');
      await customStatement('DELETE FROM roles');
      await customStatement('DELETE FROM sqlite_sequence');
      await customStatement('PRAGMA foreign_keys = ON');
    });

    await _seedWebMockDataIfEmpty();
  }

  Future<void> _seedWebMockDataIfEmpty() async {
    final existingUsers = await select(users).get();
    if (existingUsers.isNotEmpty) {
      await _ensureDefaultWebLogin();
      return;
    }

    await _insertDemoSeedData();
  }

  Future<void> _ensureDefaultWebLogin() async {
    final superAdminRole = await (select(roles)..where((r) => r.name.equals('super_admin'))).getSingleOrNull();
    final superAdminRoleId = superAdminRole?.id ?? await into(roles).insert(RolesCompanion.insert(name: 'super_admin'));

    final ownerUser = await (select(users)..where((u) => u.username.equals('owner'))).getSingleOrNull();

    if (ownerUser == null) {
      await into(users).insert(
        UsersCompanion.insert(
          username: 'owner',
          passwordHash: '1234',
          pinHash: '1234',
          roleId: superAdminRoleId,
        ),
      );
      return;
    }

    await (update(users)..where((u) => u.id.equals(ownerUser.id))).write(
      UsersCompanion(
        passwordHash: const Value('1234'),
        pinHash: const Value('1234'),
        roleId: Value(superAdminRoleId),
        isActive: const Value(true),
      ),
    );
  }

  Future<void> _insertDemoSeedData() async {
    final superAdminRoleId = await into(roles).insert(RolesCompanion.insert(name: 'super_admin'));
    final cashierRoleId = await into(roles).insert(RolesCompanion.insert(name: 'cashier'));

    await into(users).insert(
      UsersCompanion.insert(
        username: 'owner',
        passwordHash: '1234',
        pinHash: '1234',
        roleId: superAdminRoleId,
      ),
    );

    final pos1Id = await into(posCounters).insert(
      PosCountersCompanion.insert(name: 'POS1'),
    );
    await into(posCounters).insert(
      PosCountersCompanion.insert(name: 'POS2'),
    );

    await into(users).insert(
      UsersCompanion.insert(
        username: 'cashier',
        passwordHash: '1234',
        pinHash: '1234',
        roleId: cashierRoleId,
        posCounterId: Value(pos1Id),
      ),
    );

    final defaultWarehouseId = await into(warehouses).insert(
      WarehousesCompanion.insert(name: 'Main Store', isDefault: const Value(true)),
    );
    await into(appSettings).insert(
      AppSettingsCompanion.insert(key: 'inventory_mode', value: 'single'),
    );

    final groceriesCategoryId = await into(categories).insert(
      CategoriesCompanion.insert(name: 'Groceries'),
    );

    final beveragesCategoryId = await into(categories).insert(
      CategoriesCompanion.insert(name: 'Beverages'),
    );

    final dairyCategoryId = await into(categories).insert(
      CategoriesCompanion.insert(name: 'Dairy'),
    );

    final snacksCategoryId = await into(categories).insert(
      CategoriesCompanion.insert(name: 'Snacks'),
    );

    final personalCareCategoryId = await into(categories).insert(
      CategoriesCompanion.insert(name: 'Personal Care'),
    );

    final riceId = await into(products).insert(
      ProductsCompanion.insert(
        name: 'Premium Rice 5kg',
        productCode: 'PRD-RICE-001',
        barcode: const Value('8900000000011'),
        categoryId: Value(groceriesCategoryId),
        purchasePrice: const Value(410),
        sellingPrice: const Value(460),
        mrp: const Value(480),
        taxPercent: const Value(5),
        unit: const Value('bag'),
      ),
    );

    final oilId = await into(products).insert(
      ProductsCompanion.insert(
        name: 'Sunflower Oil 1L',
        productCode: 'PRD-OIL-001',
        barcode: const Value('8900000000028'),
        categoryId: Value(groceriesCategoryId),
        purchasePrice: const Value(128),
        sellingPrice: const Value(145),
        mrp: const Value(150),
        taxPercent: const Value(5),
        unit: const Value('bottle'),
      ),
    );

    final colaId = await into(products).insert(
      ProductsCompanion.insert(
        name: 'Cola 750ml',
        productCode: 'PRD-COLA-001',
        barcode: const Value('8900000000035'),
        categoryId: Value(beveragesCategoryId),
        purchasePrice: const Value(32),
        sellingPrice: const Value(40),
        mrp: const Value(42),
        taxPercent: const Value(12),
        unit: const Value('bottle'),
      ),
    );

    final milkId = await into(products).insert(
      ProductsCompanion.insert(
        name: 'Toned Milk 1L',
        productCode: 'PRD-MLK-001',
        barcode: const Value('8900000000042'),
        categoryId: Value(dairyCategoryId),
        purchasePrice: const Value(49),
        sellingPrice: const Value(54),
        mrp: const Value(56),
        taxPercent: const Value(5),
        unit: const Value('packet'),
      ),
    );

    final biscuitId = await into(products).insert(
      ProductsCompanion.insert(
        name: 'Butter Biscuit 200g',
        productCode: 'PRD-BISC-001',
        barcode: const Value('8900000000059'),
        categoryId: Value(snacksCategoryId),
        purchasePrice: const Value(18),
        sellingPrice: const Value(24),
        mrp: const Value(25),
        taxPercent: const Value(12),
        unit: const Value('pack'),
      ),
    );

    final attaId = await into(products).insert(
      ProductsCompanion.insert(
        name: 'Whole Wheat Atta 10kg',
        productCode: 'PRD-ATTA-001',
        barcode: const Value('8900000000066'),
        categoryId: Value(groceriesCategoryId),
        purchasePrice: const Value(360),
        sellingPrice: const Value(420),
        mrp: const Value(430),
        taxPercent: const Value(5),
        unit: const Value('bag'),
      ),
    );

    final soapId = await into(products).insert(
      ProductsCompanion.insert(
        name: 'Bath Soap 125g',
        productCode: 'PRD-SOAP-001',
        barcode: const Value('8900000000073'),
        categoryId: Value(personalCareCategoryId),
        purchasePrice: const Value(28),
        sellingPrice: const Value(35),
        mrp: const Value(36),
        taxPercent: const Value(18),
        unit: const Value('piece'),
      ),
    );

    await batch((b) {
      b.insert(
        inventory,
        InventoryCompanion.insert(
          productId: riceId,
          variantId: const Value(null),
          warehouseId: Value(defaultWarehouseId),
          currentStock: const Value(35),
          availableStock: const Value(35),
          lowStockThreshold: const Value(8),
        ),
      );
      b.insert(
        inventory,
        InventoryCompanion.insert(
          productId: oilId,
          variantId: const Value(null),
          warehouseId: Value(defaultWarehouseId),
          currentStock: const Value(22),
          availableStock: const Value(22),
          lowStockThreshold: const Value(6),
        ),
      );
      b.insert(
        inventory,
        InventoryCompanion.insert(
          productId: colaId,
          variantId: const Value(null),
          warehouseId: Value(defaultWarehouseId),
          currentStock: const Value(48),
          availableStock: const Value(48),
          lowStockThreshold: const Value(10),
        ),
      );
      b.insert(
        inventory,
        InventoryCompanion.insert(
          productId: milkId,
          variantId: const Value(null),
          warehouseId: Value(defaultWarehouseId),
          currentStock: const Value(60),
          availableStock: const Value(60),
          lowStockThreshold: const Value(12),
        ),
      );
      b.insert(
        inventory,
        InventoryCompanion.insert(
          productId: biscuitId,
          variantId: const Value(null),
          warehouseId: Value(defaultWarehouseId),
          currentStock: const Value(85),
          availableStock: const Value(85),
          lowStockThreshold: const Value(15),
        ),
      );
      b.insert(
        inventory,
        InventoryCompanion.insert(
          productId: attaId,
          variantId: const Value(null),
          warehouseId: Value(defaultWarehouseId),
          currentStock: const Value(26),
          availableStock: const Value(26),
          lowStockThreshold: const Value(6),
        ),
      );
      b.insert(
        inventory,
        InventoryCompanion.insert(
          productId: soapId,
          variantId: const Value(null),
          warehouseId: Value(defaultWarehouseId),
          currentStock: const Value(110),
          availableStock: const Value(110),
          lowStockThreshold: const Value(20),
        ),
      );
    });

    final walkInCustomerId = await into(customers).insert(
      CustomersCompanion.insert(name: 'Walk-in Customer', mobile: const Value('9999999999')),
    );

    final cartId = await into(carts).insert(
      CartsCompanion.insert(
        name: 'Counter Cart',
        status: const Value('active'),
        customerId: Value(walkInCustomerId),
      ),
    );

    await into(cartItems).insert(
      CartItemsCompanion.insert(
        cartId: cartId,
        productId: riceId,
        variantId: const Value(null),
        quantity: const Value(1),
        unitPrice: const Value(460),
        discountAmount: const Value(10),
        taxPercent: const Value(5),
      ),
    );
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(openDatabaseConnection);
}
