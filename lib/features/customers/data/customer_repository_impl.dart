import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../domain/customer_repository.dart';

class CustomerRepositoryImpl implements CustomerRepository {
  CustomerRepositoryImpl(this._db);

  final AppDatabase _db;

  @override
  Future<Customer?> findByMobile(String mobile) {
    return (_db.select(_db.customers)..where((c) => c.mobile.equals(mobile))).getSingleOrNull();
  }

  @override
  Future<int> createOrUpdate({
    required String mobile,
    required String name,
    String? address,
  }) async {
    final existing = await findByMobile(mobile);
    
    if (existing != null) {
      await (_db.update(_db.customers)..where((c) => c.id.equals(existing.id))).write(
        CustomersCompanion(
          name: Value(name),
          address: Value(address),
        ),
      );
      return existing.id;
    }
    
    return _db.into(_db.customers).insert(
      CustomersCompanion.insert(
        name: name,
        mobile: Value(mobile),
        address: Value(address),
      ),
    );
  }

  @override
  Stream<List<Customer>> watchAll() {
    return (_db.select(_db.customers)..orderBy([(c) => OrderingTerm.desc(c.id)])).watch();
  }

  @override
  Future<List<Customer>> searchByNameOrMobile(String query) async {
    if (query.trim().isEmpty) {
      return ((_db.select(_db.customers))..orderBy([(c) => OrderingTerm.desc(c.id)])).get();
    }
    
    final q = '%${query.trim()}%';
    return ((_db.select(_db.customers))
          ..where((c) => c.name.like(q) | c.mobile.like(q))
          ..orderBy([(c) => OrderingTerm.desc(c.id)]))
        .get();
  }

  @override
  Future<List<({Sale sale, int itemCount})>> getCustomerOrders(int customerId) async {
    final sales = await (_db.select(_db.sales)
          ..where((s) => s.customerId.equals(customerId))
          ..orderBy([(s) => OrderingTerm.desc(s.soldAt)]))
        .get();

    final result = <({Sale sale, int itemCount})>[];
    for (final sale in sales) {
      final itemCount = await (_db.select(_db.saleItems)
            ..where((i) => i.saleId.equals(sale.id)))
          .get()
          .then((items) => items.length);
      result.add((sale: sale, itemCount: itemCount));
    }
    return result;
  }

  @override
  Future<({Sale sale, List<SaleItem> items})> getOrderDetails(int saleId) async {
    final sale = await (_db.select(_db.sales)..where((s) => s.id.equals(saleId))).getSingleOrNull();
    if (sale == null) throw Exception('Sale not found');

    final items = await (_db.select(_db.saleItems)
          ..where((i) => i.saleId.equals(saleId))
          ..orderBy([(i) => OrderingTerm.asc(i.id)]))
        .get();

    return (sale: sale, items: items);
  }
}
