import '../../../core/database/app_database.dart';

abstract class PurchaseRepository {
  Stream<List<PurchaseWithSupplier>> watchAll();
  Stream<List<PurchaseItemWithProduct>> watchItems(int purchaseId);
  Future<int> createPurchase({
    int? supplierId,
    String? invoiceNo,
    String? note,
  });
  Future<void> addItem({
    required int purchaseId,
    required int productId,
    required double quantity,
    required double unitCost,
    double taxPercent = 0,
    int? variantId,
  });
  Future<void> removeItem(int purchaseItemId);
  Future<void> finalize(int purchaseId);
  Future<void> deletePurchase(int purchaseId);
}

class PurchaseWithSupplier {
  const PurchaseWithSupplier({required this.purchase, this.supplier});
  final Purchase purchase;
  final Supplier? supplier;
}

class PurchaseItemWithProduct {
  const PurchaseItemWithProduct({required this.item, required this.product});
  final PurchaseItem item;
  final Product product;
}
