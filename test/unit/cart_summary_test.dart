import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_pos/core/di/providers.dart';
import 'package:pocket_pos/core/database/app_database.dart';
import 'package:pocket_pos/features/sales/domain/sales_repository.dart';

void main() {
  test('cart summary calculation', () {
    final rows = <CartItemWithProduct>[
      CartItemWithProduct(
        item: const CartItem(
          id: 1,
          cartId: 1,
          productId: 1,
          variantId: null,
          quantity: 2,
          unitPrice: 100,
          discountAmount: 10,
          taxPercent: 5,
          note: null,
        ),
        product: Product(
          id: 1,
          name: 'Test',
          productCode: 'P1',
          sku: null,
          barcode: null,
          categoryId: null,
          brand: null,
          purchasePrice: 80,
          sellingPrice: 100,
          mrp: 110,
          taxPercent: 5,
          unit: 'piece',
          imagePath: null,
          description: null,
          isActive: true,
          createdAt: DateTime(2024),
        ),
      ),
    ];

    final container = ProviderContainer();
    addTearDown(container.dispose);

    final summary = container.read(cartSummaryProvider(rows));
    expect(summary.subTotal, 200);
    expect(summary.discountTotal, 10);
    expect(summary.taxTotal, closeTo(9.5, 0.0001));
    expect(summary.grandTotal, closeTo(199.5, 0.0001));
  });
}
