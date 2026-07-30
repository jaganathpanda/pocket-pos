import '../../../core/database/app_database.dart';

abstract class CustomerRepository {
  Future<Customer?> findByMobile(String mobile);
  Future<Customer?> getById(int id);
  Future<int> createOrUpdate({
    required String mobile,
    required String name,
    String? address,
  });
  Stream<List<Customer>> watchAll();
  Future<List<Customer>> searchByNameOrMobile(String query);
  Future<List<({Sale sale, int itemCount})>> getCustomerOrders(int customerId);
  Future<({Sale sale, List<SaleItem> items})> getOrderDetails(int saleId);
}
