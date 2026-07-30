import '../../../core/database/app_database.dart';

abstract class ProductRepository {
  Stream<List<Product>> watchAll();
  Future<List<Product>> search(String query);

  /// Fetches products by their ids (e.g. to resolve the line items on a saved
  /// invoice). Missing ids are simply omitted.
  Future<List<Product>> getByIds(List<int> ids);

  /// Looks up a single active product by its barcode, falling back to an exact
  /// product-code match. Returns `null` when nothing matches.
  Future<Product?> findByBarcode(String code);
  Future<void> add({
    required String name,
    required String productCode,
    String? barcode,
    int? categoryId,
    required double sellingPrice,
    required double purchasePrice,
    required double taxPercent,
    String unit,
  });
  Future<void> update({
    required int id,
    required String name,
    required String productCode,
    String? barcode,
    int? categoryId,
    required double sellingPrice,
    required double purchasePrice,
    required double taxPercent,
    String unit,
  });
  Future<void> updatePrice(int id, double sellingPrice);
  Future<void> delete(int id);
}
