import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/domain/auth_models.dart';
import '../../features/auth/presentation/auth_controller.dart';
import '../../features/categories/data/firestore_category_repository.dart';
import '../../features/categories/domain/category_repository.dart';
import '../../features/customers/data/firestore_customer_repository.dart';
import '../../features/customers/domain/customer_repository.dart';
import '../../features/inventory/data/firestore_inventory_repository.dart';
import '../../features/inventory/domain/inventory_repository.dart';
import '../../features/mill_run/data/firestore_mill_run_repository.dart';
import '../../features/mill_run/data/firestore_milling_charge_repository.dart';
import '../../features/mill_run/domain/mill_run_models.dart';
import '../../features/mill_run/domain/mill_run_repository.dart';
import '../../features/mill_run/domain/milling_charge_models.dart';
import '../../features/mill_run/domain/milling_charge_repository.dart';
import '../../features/mill_run/domain/milling_config.dart';
import '../../features/pos_counters/data/firestore_pos_counter_repository.dart';
import '../../features/pos_counters/domain/pos_counter_repository.dart';
import '../../features/products/data/firestore_product_repository.dart';
import '../../features/products/domain/product_repository.dart';
import '../../features/purchases/data/firestore_purchase_repository.dart';
import '../../features/purchases/domain/purchase_repository.dart';
import '../../features/reports/data/firestore_reports_repository.dart';
import '../../features/sales/data/firestore_sales_repository.dart';
import '../../features/sales/domain/sales_models.dart';
import '../../features/sales/domain/sales_repository.dart';
import '../../features/staff/data/firestore_staff_repository.dart';
import '../../features/staff/domain/staff_repository.dart';
import '../../features/store/presentation/store_auth_controller.dart';
import '../../features/suppliers/data/firestore_supplier_repository.dart';
import '../../features/suppliers/domain/supplier_repository.dart';
import '../../features/warehouse/data/firestore_warehouse_repository.dart';
import '../../features/warehouse/domain/inventory_mode.dart';
import '../../features/warehouse/domain/warehouse_repository.dart';
import '../database/app_database.dart';
import '../database/seed/demo_business_type.dart';
import '../database/seed/demo_data_loader.dart';
import '../firestore/store_scope.dart';

final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<AppUser?>>((ref) {
  return AuthController();
});

/// The currently signed-in user (null when logged out).
final currentUserProvider = Provider<AppUser?>((ref) {
  return ref.watch(authControllerProvider).valueOrNull;
});

/// The counter the current user is locked to. Null = owner/manager who can see
/// every counter's data.
final activeCounterIdProvider = Provider<int?>((ref) {
  return ref.watch(currentUserProvider)?.posCounterId;
});

// ── POS counters & POS users ────────────────────────────────────────────────

final posCounterRepositoryProvider = Provider<PosCounterRepository>((ref) {
  return FirestorePosCounterRepository(
      ref.watch(firestoreProvider), ref.watch(activeStoreIdProvider) ?? '');
});

final countersProvider = StreamProvider<List<PosCounter>>((ref) {
  if (ref.watch(activeStoreIdProvider) == null) return Stream.value(const []);
  return ref.watch(posCounterRepositoryProvider).watchCounters();
});

final posUsersProvider = StreamProvider<List<PosUserRow>>((ref) {
  if (ref.watch(activeStoreIdProvider) == null) return Stream.value(const []);
  return ref.watch(posCounterRepositoryProvider).watchPosUsers();
});

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return FirestoreCategoryRepository(
      ref.watch(firestoreProvider), ref.watch(activeStoreIdProvider) ?? '');
});

final categoriesProvider = StreamProvider<List<Category>>((ref) {
  if (ref.watch(activeStoreIdProvider) == null) return Stream.value(const []);
  return ref.watch(categoryRepositoryProvider).watchAll();
});

final customerRepositoryProvider = Provider<CustomerRepository>((ref) {
  return FirestoreCustomerRepository(
      ref.watch(firestoreProvider), ref.watch(activeStoreIdProvider) ?? '');
});

final customersProvider = StreamProvider<List<Customer>>((ref) {
  if (ref.watch(activeStoreIdProvider) == null) return Stream.value(const []);
  return ref.watch(customerRepositoryProvider).watchAll();
});

final staffRepositoryProvider = Provider<StaffRepository>((ref) {
  return FirestoreStaffRepository(
      ref.watch(firestoreProvider), ref.watch(activeStoreIdProvider) ?? '');
});

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return FirestoreProductRepository(
      ref.watch(firestoreProvider), ref.watch(activeStoreIdProvider) ?? '');
});

final productSearchQueryProvider = StateProvider<String>((ref) => '');

final productsProvider = StreamProvider<List<Product>>((ref) {
  if (ref.watch(activeStoreIdProvider) == null) return Stream.value(const []);
  final query = ref.watch(productSearchQueryProvider).trim();
  if (query.isEmpty) {
    return ref.watch(productRepositoryProvider).watchAll();
  }
  // Return a one-shot future as a stream; repository.search() is synchronous.
  return Stream.fromFuture(ref.watch(productRepositoryProvider).search(query));
});

final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  return FirestoreInventoryRepository(
      ref.watch(firestoreProvider), ref.watch(activeStoreIdProvider) ?? '');
});

/// The warehouse whose stock the Inventory screen shows (null = all).
final selectedInventoryWarehouseProvider = StateProvider<int?>((ref) => null);

final inventoryProvider = StreamProvider((ref) {
  if (ref.watch(activeStoreIdProvider) == null) return Stream.value(const []);
  final warehouseId = ref.watch(selectedInventoryWarehouseProvider);
  return ref.watch(inventoryRepositoryProvider).watchInventory(warehouseId: warehouseId);
});

// ── Warehouses & inventory mode ─────────────────────────────────────────────

final warehouseRepositoryProvider = Provider<WarehouseRepository>((ref) {
  return FirestoreWarehouseRepository(
      ref.watch(firestoreProvider), ref.watch(activeStoreIdProvider) ?? '');
});

final inventoryModeProvider = StreamProvider<InventoryMode>((ref) {
  if (ref.watch(activeStoreIdProvider) == null) {
    return Stream.value(InventoryMode.single);
  }
  return ref.watch(warehouseRepositoryProvider).watchMode();
});

final warehousesProvider = StreamProvider<List<Warehouse>>((ref) {
  if (ref.watch(activeStoreIdProvider) == null) return Stream.value(const []);
  return ref.watch(warehouseRepositoryProvider).watchWarehouses();
});

/// The demo catalog currently loaded (shown in Settings → Sample Data).
final demoBusinessTypeProvider = StreamProvider<DemoBusinessType>((ref) {
  final storeId = ref.watch(activeStoreIdProvider);
  if (storeId == null) {
    return Stream.value(DemoDataLoader.defaultBusinessType);
  }
  return storeCollection(ref.watch(firestoreProvider), storeId, 'settings')
      .doc('demo')
      .snapshots()
      .map((snap) {
    final v = snap.data()?['type'] as String?;
    return DemoBusinessType.values.firstWhere(
      (t) => t.name == v,
      orElse: () => DemoDataLoader.defaultBusinessType,
    );
  });
});

/// The permanent business type chosen at registration — written once to
/// `settings/store_profile` and never overwritten by catalog reloads.
final businessTypeProvider = StreamProvider<DemoBusinessType>((ref) {
  final storeId = ref.watch(activeStoreIdProvider);
  if (storeId == null) {
    return Stream.value(DemoDataLoader.defaultBusinessType);
  }
  return storeCollection(ref.watch(firestoreProvider), storeId, 'settings')
      .doc('store_profile')
      .snapshots()
      .map((snap) {
    final v = snap.data()?['businessType'] as String?;
    return DemoBusinessType.values.firstWhere(
      (t) => t.name == v,
      orElse: () => DemoDataLoader.defaultBusinessType,
    );
  });
});

/// Convenience flag — true only when this store was registered as a Rice Mill.
final isRiceMillProvider = Provider<bool>((ref) {
  return ref.watch(businessTypeProvider).valueOrNull == DemoBusinessType.riceMill;
});

/// Milling configuration settings stored in `settings/milling_config`.
/// Only meaningful when [isRiceMillProvider] is true.
final millingConfigProvider = StreamProvider<MillingConfig>((ref) {
  final storeId = ref.watch(activeStoreIdProvider);
  if (storeId == null) return Stream.value(MillingConfig.defaults());
  return storeCollection(ref.watch(firestoreProvider), storeId, 'settings')
      .doc('milling_config')
      .snapshots()
      .map((snap) => MillingConfig.fromMap(snap.data() ?? {}));
});

// ── Suppliers ─────────────────────────────────────────────────────────────────

final supplierRepositoryProvider = Provider<SupplierRepository>((ref) {
  return FirestoreSupplierRepository(
      ref.watch(firestoreProvider), ref.watch(activeStoreIdProvider) ?? '');
});

final suppliersProvider = StreamProvider<List<Supplier>>((ref) {
  if (ref.watch(activeStoreIdProvider) == null) return Stream.value(const []);
  return ref.watch(supplierRepositoryProvider).watchAll();
});

// ── Purchases ─────────────────────────────────────────────────────────────────

final purchaseRepositoryProvider = Provider<PurchaseRepository>((ref) {
  return FirestorePurchaseRepository(
      ref.watch(firestoreProvider), ref.watch(activeStoreIdProvider) ?? '');
});

final purchasesProvider = StreamProvider<List<PurchaseWithSupplier>>((ref) {
  if (ref.watch(activeStoreIdProvider) == null) return Stream.value(const []);
  return ref.watch(purchaseRepositoryProvider).watchAll();
});

final purchaseItemsProvider =
    StreamProvider.family<List<PurchaseItemWithProduct>, int>((ref, id) {
  if (ref.watch(activeStoreIdProvider) == null) return Stream.value(const []);
  return ref.watch(purchaseRepositoryProvider).watchItems(id);
});

// ── Sales ─────────────────────────────────────────────────────────────────────

final salesRepositoryProvider = Provider<SalesRepository>((ref) {
  return FirestoreSalesRepository(
      ref.watch(firestoreProvider), ref.watch(activeStoreIdProvider) ?? '');
});

final selectedCartIdProvider = StateProvider<int?>((ref) => null);

final activeCartsProvider = StreamProvider<List<Cart>>((ref) {
  if (ref.watch(activeStoreIdProvider) == null) return Stream.value(const []);
  final counterId = ref.watch(activeCounterIdProvider);
  return ref.watch(salesRepositoryProvider).watchActiveCarts(counterId);
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

FirestoreReportsRepository _reportsRepo(Ref ref) {
  return FirestoreReportsRepository(
    ref.watch(firestoreProvider),
    ref.watch(activeStoreIdProvider) ?? '',
    ref.watch(activeCounterIdProvider),
  );
}

const _emptyDashboard = DashboardMetrics(
  todayRevenue: 0,
  todayTransactions: 0,
  totalRevenue: 0,
  totalTransactions: 0,
  totalTax: 0,
  totalDiscount: 0,
  activeCarts: 0,
  lowStockItems: 0,
  outOfStockItems: 0,
  pendingCredit: 0,
  totalProducts: 0,
  totalCustomers: 0,
);

final dashboardMetricsProvider = FutureProvider<DashboardMetrics>((ref) async {
  if (ref.watch(activeStoreIdProvider) == null) return _emptyDashboard;
  return _reportsRepo(ref).dashboard();
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
  final range = ref.watch(salesReportRangeProvider);
  if (ref.watch(activeStoreIdProvider) == null) {
    final start = DateTime(range.start.year, range.start.month, range.start.day);
    final end = DateTime(range.end.year, range.end.month, range.end.day, 23, 59, 59, 999);
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
  return _reportsRepo(ref).salesReport(range);
});

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
  if (ref.watch(activeStoreIdProvider) == null) return const [];
  return _reportsRepo(ref).creditLedger();
});

// NOTE: Expenses migrated to store-scoped Firestore in Phase 2 — see
// features/expense/data/expense_repository.dart (storeExpensesProvider).

// ── Mill Runs ─────────────────────────────────────────────────────────────────

final millRunRepositoryProvider = Provider<MillRunRepository>((ref) {
  return FirestoreMillRunRepository(
      ref.watch(firestoreProvider), ref.watch(activeStoreIdProvider) ?? '');
});

final millRunsProvider = StreamProvider<List<MillRunWithOutputs>>((ref) {
  if (ref.watch(activeStoreIdProvider) == null) return Stream.value(const []);
  return ref.watch(millRunRepositoryProvider).watchAll();
});

// ── Milling Charge Invoices ───────────────────────────────────────────────────

final millingChargeRepositoryProvider =
    Provider<MillingChargeRepository>((ref) {
  return FirestoreMillingChargeRepository(
      ref.watch(firestoreProvider), ref.watch(activeStoreIdProvider) ?? '');
});

final millingChargesProvider =
    StreamProvider<List<MillingChargeInvoice>>((ref) {
  if (ref.watch(activeStoreIdProvider) == null) return Stream.value(const []);
  return ref.watch(millingChargeRepositoryProvider).watchAll();
});
