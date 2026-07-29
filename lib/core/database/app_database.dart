import 'package:drift/drift.dart';

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

class Staffs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get age => integer()();
  TextColumn get designation => text()();
  RealColumn get monthlySalary => real()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class StaffAttendances extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get staffId => integer().references(Staffs, #id)();
  DateTimeColumn get attendanceDate => dateTime()();
  TextColumn get status =>
      text().withDefault(const Constant('present'))(); // present, absent, half_day, leave
  DateTimeColumn get checkInAt => dateTime().nullable()();
  DateTimeColumn get checkOutAt => dateTime().nullable()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
        {staffId, attendanceDate},
      ];
}

class StaffPayrolls extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get staffId => integer().references(Staffs, #id)();
  IntColumn get payrollMonth => integer()();
  IntColumn get payrollYear => integer()();
  RealColumn get presentDays => real().withDefault(const Constant(0))();
  RealColumn get absentDays => real().withDefault(const Constant(0))();
  RealColumn get payableAmount => real().withDefault(const Constant(0))();
  RealColumn get paidAmount => real().withDefault(const Constant(0))();
  DateTimeColumn get paidAt => dateTime().nullable()();
  TextColumn get status => text().withDefault(const Constant('unpaid'))(); // unpaid, partial, paid
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
        {staffId, payrollMonth, payrollYear},
      ];
}

class StaffSalaryPayments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get staffId => integer().references(Staffs, #id)();
  IntColumn get payrollId => integer().references(StaffPayrolls, #id)();
  RealColumn get amount => real()();
  DateTimeColumn get paidOn => dateTime().withDefault(currentDateAndTime)();
  TextColumn get note => text().nullable()();
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
    Staffs,
    StaffAttendances,
    StaffPayrolls,
    StaffSalaryPayments,
    Notifications,
    AuditLogs,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 6;

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
          if (from < 5) {
            await m.createTable(staffs);
            await m.createTable(staffAttendances);
            await m.createTable(staffPayrolls);
          }
          if (from < 6) {
            await m.createTable(staffSalaryPayments);
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

          // No local seeding: authentication and all data are now in
          // Firebase/Firestore, scoped per store. Demo catalogs are seeded into
          // a store at registration based on its business type.
        },
      );

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

}

LazyDatabase _openConnection() {
  return LazyDatabase(openDatabaseConnection);
}
