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
import '../../features/weighbridge/data/firestore_weighbridge_repository.dart';
import '../../features/weighbridge/domain/vehicle_entry.dart';
import '../database/app_database.dart';
import '../database/seed/demo_business_type.dart';
import '../database/seed/demo_data_loader.dart';
import '../firestore/store_scope.dart';
import '../models/discount_policy.dart';
import '../models/invoice_branding.dart';
import '../models/printer_config.dart';
import '../models/quick_checkout_config.dart';
import '../models/storefront_shopping_config.dart';
import '../services/printer_service.dart';

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
  return ref
      .watch(inventoryRepositoryProvider)
      .watchInventory(warehouseId: warehouseId);
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
  return ref.watch(businessTypeProvider).valueOrNull ==
      DemoBusinessType.riceMill;
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
    // Round to 2 decimals at each step to prevent floating-point errors
    final lineSub = double.parse(
        (row.item.quantity * row.item.unitPrice).toStringAsFixed(2));
    final itemDiscount =
        double.parse(row.item.discountAmount.toStringAsFixed(2));
    final taxable = double.parse((lineSub - itemDiscount).toStringAsFixed(2));
    final itemTax = double.parse(
        (taxable * (row.item.taxPercent / 100)).toStringAsFixed(2));

    subTotal = double.parse((subTotal + lineSub).toStringAsFixed(2));
    discountTotal =
        double.parse((discountTotal + itemDiscount).toStringAsFixed(2));
    taxTotal = double.parse((taxTotal + itemTax).toStringAsFixed(2));
  }

  final grandTotal =
      double.parse((subTotal - discountTotal + taxTotal).toStringAsFixed(2));

  return CartSummary(
    subTotal: subTotal,
    discountTotal: discountTotal,
    taxTotal: taxTotal,
    grandTotal: grandTotal,
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

final upcomingExpiringProductsProvider =
    StreamProvider<List<({String name, DateTime expiryDate, int daysLeft})>>(
        (ref) {
  if (ref.watch(activeStoreIdProvider) == null) {
    return Stream.value(const []);
  }
  return _reportsRepo(ref).watchUpcomingExpiringProducts();
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

int _currentFinancialYearStartYear(int startMonth, {DateTime? now}) {
  final now = DateTime.now();
  final normalizedStartMonth = startMonth.clamp(1, 12);
  return now.month < normalizedStartMonth ? now.year - 1 : now.year;
}

DateTimeRange financialYearDateRange(
  InvoiceBranding branding, {
  DateTime? now,
}) {
  final effectiveNow = now ?? DateTime.now();
  final startMonth = branding.financialYearStartMonth.clamp(1, 12);
  final selectedStartYear = branding.selectedFinancialYearStartYear > 0
      ? branding.selectedFinancialYearStartYear
      : _currentFinancialYearStartYear(startMonth, now: effectiveNow);
  final start = DateTime(selectedStartYear, startMonth, 1);
  final end = DateTime(selectedStartYear + 1, startMonth, 1)
      .subtract(const Duration(milliseconds: 1));
  return DateTimeRange(
    start: start,
    end: end,
  );
}

final salesReportManualRangeProvider =
    StateProvider<DateTimeRange?>((ref) => null);

final salesReportRangeProvider = Provider<DateTimeRange>((ref) {
  final manualRange = ref.watch(salesReportManualRangeProvider);
  if (manualRange != null) return manualRange;
  final branding = ref.watch(invoiceBrandingProvider).valueOrNull ??
      const InvoiceBranding.defaults();
  return financialYearDateRange(branding);
});

final salesReportVisibleRowsProvider = StateProvider<int>((ref) => 50);

final salesReportProvider = FutureProvider<SalesReportData>((ref) async {
  final range = ref.watch(salesReportRangeProvider);
  if (ref.watch(activeStoreIdProvider) == null) {
    final start =
        DateTime(range.start.year, range.start.month, range.start.day);
    final end = DateTime(
        range.end.year, range.end.month, range.end.day, 23, 59, 59, 999);
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

// ── Invoice Branding ──────────────────────────────────────────────────────────

/// Streams the store's invoice branding settings from
/// `stores/{storeId}/settings/invoice_branding`.
/// Used by the Settings page (edit) and PDF print flow (read).
final invoiceBrandingProvider = StreamProvider<InvoiceBranding>((ref) {
  final storeId = ref.watch(activeStoreIdProvider);
  if (storeId == null) return Stream.value(const InvoiceBranding.defaults());
  return storeCollection(ref.watch(firestoreProvider), storeId, 'settings')
      .doc('invoice_branding')
      .snapshots()
      .map((snap) => InvoiceBranding.fromFirestoreMap(snap.data()));
});

// ── Printer Integration ──────────────────────────────────────────────────────

/// Streams printer integration settings from `stores/{storeId}/settings/printer_config`.
final printerConfigProvider = StreamProvider<PrinterConfig>((ref) {
  final storeId = ref.watch(activeStoreIdProvider);
  if (storeId == null) return Stream.value(const PrinterConfig.defaults());
  return storeCollection(ref.watch(firestoreProvider), storeId, 'settings')
      .doc('printer_config')
      .snapshots()
      .map((snap) => PrinterConfig.fromFirestoreMap(snap.data()));
});

final printerServiceProvider = Provider<ThermalPrinterService>((ref) {
  return ThermalPrinterService();
});

/// Streams discount policy from `stores/{storeId}/settings/discount_policy`.
/// Bill-level percentage discounts above the configured max are blocked.
final discountPolicyProvider = StreamProvider<DiscountPolicy>((ref) {
  final storeId = ref.watch(activeStoreIdProvider);
  if (storeId == null) return Stream.value(const DiscountPolicy.defaults());
  return storeCollection(ref.watch(firestoreProvider), storeId, 'settings')
      .doc('discount_policy')
      .snapshots()
      .map((snap) => DiscountPolicy.fromFirestoreMap(snap.data()));
});

/// Platform-wide public storefront gate at `platform_config/public_features`.
/// When false, the customer storefront entry point should be hidden.
final platformStorefrontShoppingConfigProvider =
    StreamProvider<StorefrontShoppingConfig>((ref) {
  return ref
      .watch(firestoreProvider)
      .collection('platform_config')
      .doc('public_features')
      .snapshots()
      .map((snap) {
    // Handle null data
    if (!snap.exists || snap.data() == null || snap.data()!.isEmpty) {
      // Return default config if document doesn't exist
      return const StorefrontShoppingConfig.defaults();
    }
    try {
      return StorefrontShoppingConfig.fromFirestoreMap(snap.data()!);
    } catch (e) {
      // If parsing fails, return default
      return const StorefrontShoppingConfig.defaults();
    }
  });
});

/// Non-blocking platform config provider for login page
/// Returns immediately with cached/default value, loads in background
final platformStorefrontShoppingConfigNonBlockingProvider =
    FutureProvider<StorefrontShoppingConfig>((ref) async {
  try {
    // Timeout after 2 seconds to avoid blocking UI
    final future = ref
        .watch(firestoreProvider)
        .collection('platform_config')
        .doc('public_features')
        .get()
        .then((snap) {
      if (!snap.exists || snap.data() == null || snap.data()!.isEmpty) {
        return const StorefrontShoppingConfig.defaults();
      }
      try {
        return StorefrontShoppingConfig.fromFirestoreMap(snap.data()!);
      } catch (e) {
        return const StorefrontShoppingConfig.defaults();
      }
    });

    return await future.timeout(
      const Duration(seconds: 2),
      onTimeout: () => const StorefrontShoppingConfig.defaults(),
    );
  } catch (e) {
    // On any error, return default
    return const StorefrontShoppingConfig.defaults();
  }
});

final platformAnonymousShoppingEnabledProvider = Provider<bool>((ref) {
  // Use non-blocking provider - show button by default if config hasn't loaded
  final cfgAsync =
      ref.watch(platformStorefrontShoppingConfigNonBlockingProvider);
  return cfgAsync.valueOrNull?.allowAnonymousShopping ?? true;
});

/// Store-level opt-in for the public storefront.
/// Stored in `stores/{storeId}/settings/storefront`.
final storeStorefrontShoppingConfigProvider =
    StreamProvider<StorefrontShoppingConfig>((ref) {
  final storeId = ref.watch(activeStoreIdProvider);
  if (storeId == null) {
    return Stream.value(const StorefrontShoppingConfig.defaults());
  }
  return storeCollection(ref.watch(firestoreProvider), storeId, 'settings')
      .doc('storefront')
      .snapshots()
      .map((snap) => StorefrontShoppingConfig.fromFirestoreMap(snap.data()));
});

/// Store-level Quick Checkout setting in `stores/{storeId}/settings/shop_settings`.
final quickCheckoutConfigProvider = StreamProvider<QuickCheckoutConfig>((ref) {
  final storeId = ref.watch(activeStoreIdProvider);
  if (storeId == null) {
    return Stream.value(const QuickCheckoutConfig.defaults());
  }
  return storeCollection(ref.watch(firestoreProvider), storeId, 'settings')
      .doc('shop_settings')
      .snapshots()
      .map((snap) => QuickCheckoutConfig.fromFirestoreMap(snap.data()));
});

final quickCheckoutEnabledProvider = Provider<bool>((ref) {
  return ref.watch(quickCheckoutConfigProvider).valueOrNull?.enabled ?? false;
});

final quickInvoiceEnabledProvider = Provider<bool>((ref) {
  return ref
          .watch(quickCheckoutConfigProvider)
          .valueOrNull
          ?.quickInvoiceEnabled ??
      false;
});

// ── Weighbridge Operators (Platform-level) ────────────────────────────────────

/// The current user's UID (from Firebase Auth). Used by operator pages.
final currentUidProvider = Provider<String?>((ref) {
  final authState = ref.watch(storeAuthControllerProvider);
  // Try session first (store members), then operator
  return authState.session?.uid ?? authState.operator?.uid;
});

final weighbridgeRepositoryProvider =
    Provider<FirestoreWeighbridgeRepository>((ref) {
  final storeId = ref.watch(activeStoreIdProvider) ?? '';
  return FirestoreWeighbridgeRepository(ref.watch(firestoreProvider), storeId);
});

final pendingApprovalsProvider = StreamProvider<List<VehicleEntry>>((ref) {
  // Pending vehicle entries awaiting approval by store members
  final storeId = ref.watch(activeStoreIdProvider);
  if (storeId == null) return Stream.value(const []);
  return ref.watch(weighbridgeRepositoryProvider).watchPending();
});

final vehicleEntryStreamProvider =
    StreamProvider.family<VehicleEntry?, int>((ref, entryId) {
  final storeId = ref.watch(activeStoreIdProvider);
  if (storeId == null) return Stream.value(null);
  return ref.watch(weighbridgeRepositoryProvider).watchEntry(entryId);
});

final vehicleEntryProvider =
    FutureProvider.family<VehicleEntry?, int>((ref, entryId) async {
  final storeId = ref.watch(activeStoreIdProvider);
  if (storeId == null) return null;
  return ref.watch(weighbridgeRepositoryProvider).getEntry(entryId);
});

final millersProvider = StreamProvider<List<Staff>>((ref) {
  if (ref.watch(activeStoreIdProvider) == null) return Stream.value(const []);
  return ref.watch(staffRepositoryProvider).watchActiveStaff();
});

/// Filter for weighbridge vehicle entries.
class WeighbridgeFilter {
  const WeighbridgeFilter({
    this.fromDate,
    this.toDate,
    this.vehicleNo,
    this.partyName,
  });

  final DateTime? fromDate;
  final DateTime? toDate;
  final String? vehicleNo;
  final String? partyName;
}

/// Filter state for weighbridge vehicle entries list.
final weighbridgeFilterProvider = StateProvider<WeighbridgeFilter>((ref) {
  return const WeighbridgeFilter();
});

/// All vehicle entries with optional filtering.
final vehicleEntriesStreamProvider = StreamProvider<List<VehicleEntry>>((ref) {
  final storeId = ref.watch(activeStoreIdProvider);
  if (storeId == null) return Stream.value(const []);
  final filter = ref.watch(weighbridgeFilterProvider);
  return ref.watch(weighbridgeRepositoryProvider).watchAll(
        fromDate: filter.fromDate,
        toDate: filter.toDate,
        vehicleNo: filter.vehicleNo,
        partyName: filter.partyName,
      );
});

/// Vehicle entries created by the current operator (for operator dashboard).
final myWeighbridgeEntriesProvider = StreamProvider<List<VehicleEntry>>((ref) {
  final storeId = ref.watch(activeStoreIdProvider);
  if (storeId == null) return Stream.value(const []);
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(weighbridgeRepositoryProvider).watchByCreator(uid);
});
