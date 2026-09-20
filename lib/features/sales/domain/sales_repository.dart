import '../../../core/database/app_database.dart';

class SalesReturnResult {
  const SalesReturnResult({
    required this.returnedAmount,
    required this.refundAmount,
    required this.stockRestocked,
    required this.fullyReturned,
  });

  final double returnedAmount;
  final double refundAmount;
  final bool stockRestocked;
  final bool fullyReturned;
}

class SaleReturnLineRequest {
  const SaleReturnLineRequest({
    required this.saleItemId,
    required this.quantity,
  });

  final int saleItemId;
  final double quantity;
}

abstract class SalesRepository {
  Stream<List<Cart>> watchActiveCarts(int? posCounterId);
  Stream<List<CartItemWithProduct>> watchCartItems(int cartId);
  Future<int> createCart(String name, {int? posCounterId, int? warehouseId});
  Future<int> createCartWithCustomer(String name, int customerId,
      {int? posCounterId, int? warehouseId});
  Future<void> setCartStatus(int cartId, String status);
  Future<void> setCartCounter(int cartId, int posCounterId);
  Future<void> renameCart(int cartId, String name);
  Future<void> deleteCart(int cartId);
  Future<void> updateCartCustomer(int cartId, int customerId);
  Future<void> updateCartDiscount(int cartId, double totalDiscount);
  Future<void> updateCartDiscountPercent(int cartId, double percent);
  Future<Cart?> getCart(int cartId);
  Future<void> addItem({required int cartId, required int productId});
  Future<void> updateItemQuantity(int cartItemId, double quantity);
  Future<void> removeItem(int cartItemId);
  Future<void> recordCreditPayment({
    required int saleId,
    required double amount,
    required String method,
    String? referenceNo,
  });
  Future<SalesReturnResult> processSaleReturn({
    required int saleId,
    required String reason,
    required String refundMethod,
  });
  Future<SalesReturnResult> processPartialSaleReturn({
    required int saleId,
    required List<SaleReturnLineRequest> lines,
    required String reason,
    required String refundMethod,
  });
  Future<int> checkout({
    required int cartId,
    required String paymentMode,
    required double paidAmount,
    String? customerName,
    String? customerMobile,
    String? customerAddress,
  });
}

class CartItemWithProduct {
  const CartItemWithProduct({required this.item, required this.product});

  final CartItem item;
  final Product product;
}
