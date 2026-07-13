import '../../../core/database/app_database.dart';

abstract class SupplierRepository {
  Stream<List<Supplier>> watchAll();
  Future<List<Supplier>> search(String query);
  Future<Supplier> getById(int id);
  Future<int> add({
    required String name,
    String? mobile,
    String? gstNumber,
    String? email,
    String? address,
    String? contactPerson,
  });
  Future<void> update({
    required int id,
    required String name,
    String? mobile,
    String? gstNumber,
    String? email,
    String? address,
    String? contactPerson,
  });
  Future<void> delete(int id);
}
