class CartLine {
  const CartLine({
    required this.productId,
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.taxPercent,
    this.discount = 0,
  });

  final int productId;
  final String name;
  final double quantity;
  final double unitPrice;
  final double taxPercent;
  final double discount;

  double get subTotal => quantity * unitPrice;
  double get taxAmount => (subTotal - discount) * (taxPercent / 100);
  double get lineTotal => subTotal - discount + taxAmount;

  CartLine copyWith({double? quantity, double? unitPrice, double? discount}) {
    return CartLine(
      productId: productId,
      name: name,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      taxPercent: taxPercent,
      discount: discount ?? this.discount,
    );
  }
}

class CartSummary {
  const CartSummary({
    required this.subTotal,
    required this.discountTotal,
    required this.taxTotal,
    required this.grandTotal,
  });

  final double subTotal;
  final double discountTotal;
  final double taxTotal;
  final double grandTotal;
}
