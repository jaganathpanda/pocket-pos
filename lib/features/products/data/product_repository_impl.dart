import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../domain/product_repository.dart';

class ProductRepositoryImpl implements ProductRepository {
  ProductRepositoryImpl(this._db);

  final AppDatabase _db;

  @override
  Stream<List<Product>> watchAll() {
    return (_db.select(_db.products)..where((p) => p.isActive.equals(true))..orderBy([(t) => OrderingTerm.asc(t.name)])).watch();
  }

  @override
  Future<List<Product>> search(String query) {
    final q = '%$query%';
    return (_db.select(_db.products)
          ..where((p) => p.name.like(q) | p.productCode.like(q) | (p.barcode.isNotNull() & p.barcode.like(q)))
          ..limit(30))
        .get();
  }

  @override
  Future<List<Product>> getByIds(List<int> ids) {
    if (ids.isEmpty) return Future.value(const []);
    return (_db.select(_db.products)..where((p) => p.id.isIn(ids))).get();
  }

  @override
  Future<Product?> findByBarcode(String code) {
    final c = code.trim();
    if (c.isEmpty) return Future.value(null);
    return (_db.select(_db.products)
          ..where((p) =>
              p.isActive.equals(true) &
              (p.barcode.equals(c) | p.productCode.equals(c)))
          ..limit(1))
        .getSingleOrNull();
  }

  @override
  Future<void> add({
    required String name,
    required String productCode,
    String? barcode,
    int? categoryId,
    required double sellingPrice,
    required double purchasePrice,
    required double taxPercent,
    String unit = 'piece',
  }) async {
    final id = await _db.into(_db.products).insert(
          ProductsCompanion.insert(
            name: name,
            productCode: productCode,
            barcode: Value(barcode),
            categoryId: Value(categoryId),
            sellingPrice: Value(sellingPrice),
            purchasePrice: Value(purchasePrice),
            taxPercent: Value(taxPercent),
            unit: Value(unit),
          ),
        );

    await _db.into(_db.inventory).insert(
          InventoryCompanion.insert(
            productId: id,
            variantId: const Value(null),
            warehouseId: Value(await _db.defaultWarehouseId()),
            currentStock: const Value(0),
            availableStock: const Value(0),
          ),
        );
  }

  @override
  Future<void> update({
    required int id,
    required String name,
    required String productCode,
    String? barcode,
    int? categoryId,
    required double sellingPrice,
    required double purchasePrice,
    required double taxPercent,
    String unit = 'piece',
  }) {
    return (_db.update(_db.products)..where((p) => p.id.equals(id))).write(
      ProductsCompanion(
        name: Value(name),
        productCode: Value(productCode),
        barcode: Value(barcode),
        categoryId: Value(categoryId),
        sellingPrice: Value(sellingPrice),
        purchasePrice: Value(purchasePrice),
        taxPercent: Value(taxPercent),
        unit: Value(unit),
      ),
    );
  }

  @override
  Future<void> updatePrice(int id, double sellingPrice) {
    return (_db.update(_db.products)..where((p) => p.id.equals(id))).write(
      ProductsCompanion(sellingPrice: Value(sellingPrice)),
    );
  }

  @override
  Future<void> delete(int id) {
    return (_db.update(_db.products)..where((p) => p.id.equals(id))).write(
      const ProductsCompanion(isActive: Value(false)),
    );
  }
}
