import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/auth_repository_impl.dart';
import '../../features/auth/domain/auth_models.dart';
import '../../features/auth/domain/auth_repository.dart';
import '../../features/auth/presentation/auth_controller.dart';
import '../../features/customers/data/customer_repository_impl.dart';
import '../../features/customers/domain/customer_repository.dart';
import '../../features/categories/data/category_repository_impl.dart';
import '../../features/categories/domain/category_repository.dart';
import '../../features/inventory/data/inventory_repository_impl.dart';
import '../../features/inventory/domain/inventory_repository.dart';
import '../../features/products/data/product_repository_impl.dart';
import '../../features/products/domain/product_repository.dart';
import '../../features/sales/data/sales_repository_impl.dart';
import '../../features/sales/domain/sales_models.dart';
import '../../features/sales/domain/sales_repository.dart';
import '../../features/suppliers/data/supplier_repository_impl.dart';
import '../../features/suppliers/domain/supplier_repository.dart';
import '../../features/purchases/data/purchase_repository_impl.dart';
import '../../features/purchases/domain/purchase_repository.dart';
import '../database/app_database.dart';
import '../database/database_provider.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(ref.watch(appDatabaseProvider));
});

final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<AppUser?>>((ref) {
  return AuthController(ref.watch(authRepositoryProvider));
});

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return CategoryRepositoryImpl(ref.watch(appDatabaseProvider));
});

final categoriesProvider = StreamProvider<List<Category>>((ref) {
  return ref.watch(categoryRepositoryProvider).watchAll();
});

final customerRepositoryProvider = Provider<CustomerRepository>((ref) {
  return CustomerRepositoryImpl(ref.watch(appDatabaseProvider));
});

final customersProvider = StreamProvider<List<Customer>>((ref) {
  return ref.watch(customerRepositoryProvider).watchAll();
});

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return ProductRepositoryImpl(ref.watch(appDatabaseProvider));
});

final productSearchQueryProvider = StateProvider<String>((ref) => '');

final productsProvider = StreamProvider<List<Product>>((ref) {
  return ref.watch(productRepositoryProvider).watchAll();
});

final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  return InventoryRepositoryImpl(ref.watch(appDatabaseProvider));
});

final inventoryProvider = StreamProvider((ref) {
  return ref.watch(inventoryRepositoryProvider).watchInventory();
});

// ── Suppliers ─────────────────────────────────────────────────────────────────

final supplierRepositoryProvider = Provider<SupplierRepository>((ref) {
  return SupplierRepositoryImpl(ref.watch(appDatabaseProvider));
});

final suppliersProvider = StreamProvider<List<Supplier>>((ref) {
  return ref.watch(supplierRepositoryProvider).watchAll();
});

// ── Purchases ─────────────────────────────────────────────────────────────────

final purchaseRepositoryProvider = Provider<PurchaseRepository>((ref) {
  return PurchaseRepositoryImpl(ref.watch(appDatabaseProvider));
});

final purchasesProvider = StreamProvider<List<PurchaseWithSupplier>>((ref) {
  return ref.watch(purchaseRepositoryProvider).watchAll();
});

final purchaseItemsProvider =
    StreamProvider.family<List<PurchaseItemWithProduct>, int>((ref, id) {
  return ref.watch(purchaseRepositoryProvider).watchItems(id);
});

// ── Sales ─────────────────────────────────────────────────────────────────────

final salesRepositoryProvider = Provider<SalesRepository>((ref) {
  return SalesRepositoryImpl(ref.watch(appDatabaseProvider));
});

final selectedCartIdProvider = StateProvider<int?>((ref) => null);

final activeCartsProvider = StreamProvider<List<Cart>>((ref) {
  return ref.watch(salesRepositoryProvider).watchActiveCarts();
});

final cartItemsProvider =
    StreamProvider.family<List<CartItemWithProduct>, int>((ref, cartId) {
  return ref.watch(salesRepositoryProvider).watchCartItems(cartId);
});

final cartSummaryProvider =
    Provider.family<CartSummary, List<CartItemWithProduct>>((ref, items) {
  double subTotal = 0;
  double discountTotal = 0;
  double taxTotal = 0;

  for (final row in items) {
    final lineSub = row.item.quantity * row.item.unitPrice;
    final taxable = lineSub - row.item.discountAmount;
    subTotal += lineSub;
    discountTotal += row.item.discountAmount;
    taxTotal += taxable * (row.item.taxPercent / 100);
  }

  return CartSummary(
    subTotal: subTotal,
    discountTotal: discountTotal,
    taxTotal: taxTotal,
    grandTotal: subTotal - discountTotal + taxTotal,
  );
});

final cartGrandTotalProvider =
    FutureProvider.family<double, int>((ref, cartId) async {
  final rows =
      await ref.watch(salesRepositoryProvider).watchCartItems(cartId).first;
  final summary = ref.read(cartSummaryProvider(rows));
  return summary.grandTotal;
});

class DashboardMetrics {
  const DashboardMetrics({
    required this.todayRevenue,
    required this.todayTransactions,
    required this.totalRevenue,
    required this.totalTransactions,
    required this.totalTax,
    required this.totalDiscount,
    required this.activeCarts,
    required this.lowStockItems,
    required this.outOfStockItems,
    required this.pendingCredit,
    required this.totalProducts,
    required this.totalCustomers,
  });

  final double todayRevenue;
  final int todayTransactions;
  final double totalRevenue;
  final int totalTransactions;
  final double totalTax;
  final double totalDiscount;
  final int activeCarts;
  final int lowStockItems;
  final int outOfStockItems;
  final double pendingCredit;
  final int totalProducts;
  final int totalCustomers;
}

final dashboardMetricsProvider = FutureProvider<DashboardMetrics>((ref) async {
  final db = ref.watch(appDatabaseProvider);
  final now = DateTime.now();
  final dayStart = DateTime(now.year, now.month, now.day);

  final allSales = await db.select(db.sales).get();
  final todaySales =
      allSales.where((s) => !s.soldAt.isBefore(dayStart)).toList();
  final todayRevenue =
      todaySales.fold<double>(0, (sum, s) => sum + s.grandTotal);
  final totalRevenue = allSales.fold<double>(0, (sum, s) => sum + s.grandTotal);
  final totalTax = allSales.fold<double>(0, (sum, s) => sum + s.taxTotal);
  final totalDiscount =
      allSales.fold<double>(0, (sum, s) => sum + s.discountTotal);

  final activeCarts = await (db.select(db.carts)
        ..where((c) => Expression.or(
            [c.status.equals('active'), c.status.equals('hold')])))
      .get();
  final allInventory = await db.select(db.inventory).get();
  final allProducts = await db.select(db.products).get();
  final allCustomers = await db.select(db.customers).get();
  final low =
      allInventory.where((i) => i.availableStock <= i.lowStockThreshold).length;
  final out = allInventory.where((i) => i.availableStock <= 0).length;

  final creditSales = await (db.select(db.sales)
        ..where((s) => Expression.or([
              s.paymentStatus.equals('partial'),
              s.paymentStatus.equals('credit')
            ])))
      .get();
  final pending = creditSales.fold<double>(0, (sum, s) => sum + s.grandTotal);

  return DashboardMetrics(
    todayRevenue: todayRevenue,
    todayTransactions: todaySales.length,
    totalRevenue: totalRevenue,
    totalTransactions: allSales.length,
    totalTax: totalTax,
    totalDiscount: totalDiscount,
    activeCarts: activeCarts.length,
    lowStockItems: low,
    outOfStockItems: out,
    pendingCredit: pending,
    totalProducts: allProducts.length,
    totalCustomers: allCustomers.length,
  );
});

class SalesReportRow {
  const SalesReportRow({
    required this.saleId,
    required this.invoiceNo,
    required this.soldAt,
    required this.paymentStatus,
    required this.grandTotal,
    required this.itemsCount,
    required this.totalQty,
    required this.paymentCount,
    required this.paidAmount,
    required this.dueAmount,
    required this.productGstSummary,
    this.paymentMethod,
  });

  final int saleId;
  final String invoiceNo;
  final DateTime soldAt;
  final String paymentStatus;
  final double grandTotal;
  final int itemsCount;
  final double totalQty;
  final int paymentCount;
  final double paidAmount;
  final double dueAmount;
  final String productGstSummary;
  final String? paymentMethod;
}

class TopSellingProduct {
  const TopSellingProduct({
    required this.productId,
    required this.name,
    required this.quantity,
    required this.amount,
  });

  final int productId;
  final String name;
  final double quantity;
  final double amount;
}

class SalesReportData {
  const SalesReportData({
    required this.start,
    required this.end,
    required this.totalSales,
    required this.totalAmount,
    required this.totalTax,
    required this.totalDiscount,
    required this.totalItems,
    required this.totalQuantity,
    required this.paymentMethodTotals,
    required this.topProducts,
    required this.rows,
  });

  final DateTime start;
  final DateTime end;
  final int totalSales;
  final double totalAmount;
  final double totalTax;
  final double totalDiscount;
  final int totalItems;
  final double totalQuantity;
  final Map<String, double> paymentMethodTotals;
  final List<TopSellingProduct> topProducts;
  final List<SalesReportRow> rows;
}

final salesReportRangeProvider = StateProvider<DateTimeRange>((ref) {
  final now = DateTime.now();
  return DateTimeRange(
    start: DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 29)),
    end: DateTime(now.year, now.month, now.day),
  );
});

final salesReportProvider = FutureProvider<SalesReportData>((ref) async {
  final db = ref.watch(appDatabaseProvider);
  final range = ref.watch(salesReportRangeProvider);
  final start = DateTime(range.start.year, range.start.month, range.start.day);
  final end =
      DateTime(range.end.year, range.end.month, range.end.day, 23, 59, 59, 999);

  final salesInRange = await (db.select(db.sales)
        ..where((s) => s.soldAt.isBetweenValues(start, end))
        ..orderBy([(s) => OrderingTerm.desc(s.soldAt)]))
      .get();

  if (salesInRange.isEmpty) {
    return SalesReportData(
      start: start,
      end: end,
      totalSales: 0,
      totalAmount: 0,
      totalTax: 0,
      totalDiscount: 0,
      totalItems: 0,
      totalQuantity: 0,
      paymentMethodTotals: const {},
      topProducts: const [],
      rows: const [],
    );
  }

  final saleIds = salesInRange.map((s) => s.id).toList(growable: false);
  final saleItems = await (db.select(db.saleItems)
        ..where((i) => i.saleId.isIn(saleIds)))
      .get();
  final payments = await (db.select(db.payments)
        ..where((p) => p.saleId.isIn(saleIds)))
      .get();

  final totalAmount =
      salesInRange.fold<double>(0, (sum, s) => sum + s.grandTotal);
  final totalTax = salesInRange.fold<double>(0, (sum, s) => sum + s.taxTotal);
  final totalDiscount =
      salesInRange.fold<double>(0, (sum, s) => sum + s.discountTotal);
  final totalQuantity = saleItems.fold<double>(0, (sum, i) => sum + i.quantity);

  final paymentMethodTotals = <String, double>{};
  for (final payment in payments) {
    paymentMethodTotals[payment.method] =
        (paymentMethodTotals[payment.method] ?? 0) + payment.amount;
  }

  final itemsBySaleId = <int, List<SaleItem>>{};
  for (final item in saleItems) {
    itemsBySaleId.putIfAbsent(item.saleId, () => []).add(item);
  }

  final paymentsBySaleId = <int, List<Payment>>{};
  for (final payment in payments) {
    paymentsBySaleId.putIfAbsent(payment.saleId, () => []).add(payment);
  }

  final productTotals = <int, ({double qty, double amount})>{};
  for (final item in saleItems) {
    final current = productTotals[item.productId] ?? (qty: 0.0, amount: 0.0);
    productTotals[item.productId] = (
      qty: current.qty + item.quantity,
      amount: current.amount + item.lineTotal,
    );
  }

  final productIds = productTotals.keys.toList(growable: false);
  final products =
      await (db.select(db.products)..where((p) => p.id.isIn(productIds))).get();
  final productById = {for (final p in products) p.id: p};
  final productNameById = {for (final p in products) p.id: p.name};

  final topProducts = productTotals.entries
      .map(
        (entry) => TopSellingProduct(
          productId: entry.key,
          name: productNameById[entry.key] ?? 'Product #${entry.key}',
          quantity: entry.value.qty,
          amount: entry.value.amount,
        ),
      )
      .toList()
    ..sort((a, b) => b.amount.compareTo(a.amount));

  final rows = salesInRange.map(
    (sale) {
      final salePayments = paymentsBySaleId[sale.id] ?? const <Payment>[];
      final paidAmount =
          salePayments.fold<double>(0, (sum, p) => sum + p.amount);
      final dueAmount =
          (sale.grandTotal - paidAmount).clamp(0, 999999999).toDouble();

      return SalesReportRow(
        saleId: sale.id,
        invoiceNo: sale.invoiceNo,
        soldAt: sale.soldAt,
        paymentStatus: sale.paymentStatus,
        grandTotal: sale.grandTotal,
        itemsCount: itemsBySaleId[sale.id]?.length ?? 0,
        totalQty: itemsBySaleId[sale.id]
                ?.fold<double>(0, (sum, i) => sum + i.quantity) ??
            0,
        paymentCount: salePayments.length,
        paidAmount: paidAmount,
        dueAmount: dueAmount,
        productGstSummary: _buildProductGstSummary(
          itemsBySaleId[sale.id] ?? const <SaleItem>[],
          productById,
        ),
        paymentMethod: salePayments.isEmpty ? null : salePayments.last.method,
      );
    },
  ).toList(growable: false);

  return SalesReportData(
    start: start,
    end: end,
    totalSales: salesInRange.length,
    totalAmount: totalAmount,
    totalTax: totalTax,
    totalDiscount: totalDiscount,
    totalItems: saleItems.length,
    totalQuantity: totalQuantity,
    paymentMethodTotals: paymentMethodTotals,
    topProducts: topProducts.take(5).toList(growable: false),
    rows: rows,
  );
});

String _buildProductGstSummary(List<SaleItem> items, Map<int, Product> productById) {
  if (items.isEmpty) return '-';
  return items.map((item) {
    final product = productById[item.productId];
    final name = product?.name ?? 'Product #${item.productId}';
    final qtyLabel = item.quantity % 1 == 0
        ? item.quantity.toInt().toString()
        : item.quantity.toStringAsFixed(2);
    final gstLabel = item.taxPercent % 1 == 0
        ? item.taxPercent.toInt().toString()
        : item.taxPercent.toStringAsFixed(2);
    return '$name x$qtyLabel (GST $gstLabel%)';
  }).join(' | ');
}

class CreditLedgerRow {
  const CreditLedgerRow({
    required this.sale,
    required this.customer,
    required this.paidAmount,
    required this.dueAmount,
  });

  final Sale sale;
  final Customer? customer;
  final double paidAmount;
  final double dueAmount;
}

final creditLedgerProvider = FutureProvider<List<CreditLedgerRow>>((ref) async {
  final db = ref.watch(appDatabaseProvider);

  final sales = await (db.select(db.sales)
        ..orderBy([(s) => OrderingTerm.desc(s.soldAt)]))
      .get();
  if (sales.isEmpty) return const [];

  final saleIds = sales.map((s) => s.id).toList(growable: false);
  final payments = await (db.select(db.payments)
        ..where((p) => p.saleId.isIn(saleIds)))
      .get();

  final paidBySale = <int, double>{};
  for (final p in payments) {
    paidBySale[p.saleId] = (paidBySale[p.saleId] ?? 0) + p.amount;
  }

  final customerIds = sales
      .where((s) => s.customerId != null)
      .map((s) => s.customerId!)
      .toSet()
      .toList(growable: false);
  final customers = customerIds.isEmpty
      ? const <Customer>[]
      : await (db.select(db.customers)..where((c) => c.id.isIn(customerIds)))
          .get();
  final customerById = {for (final c in customers) c.id: c};

  return sales.map((sale) {
    final paid = paidBySale[sale.id] ?? 0;
    final due = (sale.grandTotal - paid).clamp(0, 999999999).toDouble();
    return CreditLedgerRow(
      sale: sale,
      customer: sale.customerId == null ? null : customerById[sale.customerId],
      paidAmount: paid,
      dueAmount: due,
    );
  }).where((r) {
    final status = r.sale.paymentStatus.toLowerCase();
    return r.dueAmount > 0 || status == 'partial' || status == 'credit';
  }).toList(growable: false);
});

final expensesProvider = StreamProvider<List<Expense>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return (db.select(db.expenses)
        ..orderBy([(e) => OrderingTerm.desc(e.spentAt)]))
      .watch();
});
