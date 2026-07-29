import 'package:cloud_firestore/cloud_firestore.dart';

import '../database/app_database.dart';

/// Shared Firestore document → Drift-model mappers for the sales cluster, so
/// customers/reports/ledger and the sales repository stay consistent.
double fsNum(dynamic v, [double or = 0]) => (v as num?)?.toDouble() ?? or;

Product productFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
  final d = doc.data() ?? const {};
  return Product(
    id: int.tryParse(doc.id) ?? 0,
    name: (d['name'] as String?) ?? '',
    productCode: (d['productCode'] as String?) ?? '',
    sku: d['sku'] as String?,
    barcode: d['barcode'] as String?,
    categoryId: (d['categoryId'] as num?)?.toInt(),
    brand: d['brand'] as String?,
    purchasePrice: fsNum(d['purchasePrice']),
    sellingPrice: fsNum(d['sellingPrice']),
    mrp: fsNum(d['mrp']),
    taxPercent: fsNum(d['taxPercent']),
    unit: (d['unit'] as String?) ?? 'piece',
    imagePath: d['imagePath'] as String?,
    description: d['description'] as String?,
    isActive: (d['isActive'] as bool?) ?? true,
    createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
  );
}

Cart cartFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
  final d = doc.data() ?? const {};
  return Cart(
    id: int.tryParse(doc.id) ?? 0,
    name: (d['name'] as String?) ?? '',
    status: (d['status'] as String?) ?? 'active',
    customerId: (d['customerId'] as num?)?.toInt(),
    posCounterId: (d['posCounterId'] as num?)?.toInt(),
    warehouseId: (d['warehouseId'] as num?)?.toInt(),
    createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    updatedAt: (d['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
  );
}

CartItem cartItemFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
  final d = doc.data() ?? const {};
  return CartItem(
    id: int.tryParse(doc.id) ?? 0,
    cartId: (d['cartId'] as num?)?.toInt() ?? 0,
    productId: (d['productId'] as num?)?.toInt() ?? 0,
    variantId: (d['variantId'] as num?)?.toInt(),
    quantity: fsNum(d['quantity'], 1),
    unitPrice: fsNum(d['unitPrice']),
    discountAmount: fsNum(d['discountAmount']),
    taxPercent: fsNum(d['taxPercent']),
    note: d['note'] as String?,
  );
}

Payment paymentFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
  final d = doc.data() ?? const {};
  return Payment(
    id: int.tryParse(doc.id) ?? 0,
    saleId: (d['saleId'] as num?)?.toInt() ?? 0,
    method: (d['method'] as String?) ?? 'cash',
    amount: fsNum(d['amount']),
    referenceNo: d['referenceNo'] as String?,
    paidAt: (d['paidAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
  );
}

Sale saleFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
  final d = doc.data() ?? const {};
  return Sale(
    id: int.tryParse(doc.id) ?? 0,
    cartId: (d['cartId'] as num?)?.toInt(),
    invoiceNo: (d['invoiceNo'] as String?) ?? '',
    customerId: (d['customerId'] as num?)?.toInt(),
    posCounterId: (d['posCounterId'] as num?)?.toInt(),
    warehouseId: (d['warehouseId'] as num?)?.toInt(),
    subTotal: fsNum(d['subTotal']),
    discountTotal: fsNum(d['discountTotal']),
    taxTotal: fsNum(d['taxTotal']),
    grandTotal: fsNum(d['grandTotal']),
    paymentStatus: (d['paymentStatus'] as String?) ?? 'paid',
    soldAt: (d['soldAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
  );
}

SaleItem saleItemFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
  final d = doc.data() ?? const {};
  return SaleItem(
    id: int.tryParse(doc.id) ?? 0,
    saleId: (d['saleId'] as num?)?.toInt() ?? 0,
    productId: (d['productId'] as num?)?.toInt() ?? 0,
    variantId: (d['variantId'] as num?)?.toInt(),
    quantity: fsNum(d['quantity']),
    unitPrice: fsNum(d['unitPrice']),
    discountAmount: fsNum(d['discountAmount']),
    taxPercent: fsNum(d['taxPercent']),
    lineTotal: fsNum(d['lineTotal']),
  );
}
