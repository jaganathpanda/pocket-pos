import '../../../core/database/app_database.dart';

abstract class SalesRepository {
  Stream<List<Cart>> watchActiveCarts();
  Stream<List<CartItemWithProduct>> watchCartItems(int cartId);
  Future<int> createCart(String name);
  Future<int> createCartWithCustomer(String name, int customerId);
  Future<void> setCartStatus(int cartId, String status);
  Future<void> renameCart(int cartId, String name);
  Future<void> deleteCart(int cartId);
  Future<void> updateCartCustomer(int cartId, int customerId);
  Future<void> updateCartDiscount(int cartId, double totalDiscount);
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
